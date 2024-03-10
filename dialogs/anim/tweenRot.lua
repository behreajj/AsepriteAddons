dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local angleTypes <const> = {
    "CCW",
    "CW",
    "NEAR"
}
local axes <const> = { "X", "Y", "Z" }
local facTypes <const> = { "FRAME", "TIME" }
local modes <const> = { "ADD", "MIX" }

local screenScale <const> = app.preferences.general.screen_scale --[[@as integer]]
local curveColor <const> = app.theme.color.text --[[@as Color]]
local gridColor <const> = Color { r = 128, g = 128, b = 128 }

local defaults <const> = {
    mode = "MIX",
    facType = "TIME",
    axis = "Z",
    angleType = "NEAR",
    trimCel = true,
    alpSampleCount = 96,

    frameOrig = 1,
    rotOrig = 0,

    frameDest = 1,
    rotDest = 0,

    rotIncr = 0,
}

local dlg <const> = Dialog { title = "Anim Rotation" }

dlg:combobox {
    id = "mode",
    label = "Mode:",
    option = defaults.mode,
    options = modes,
    onchange = function()
        local args <const> = dlg.data
        local mode <const> = args.mode --[[@as string]]
        local isMix <const> = mode == "MIX"
        local isAdd <const> = mode == "ADD"

        dlg:modify { id = "facType", visible = isMix }
        dlg:modify { id = "angleType", visible = isMix }
        dlg:modify { id = "rotOrig", visible = isMix }
        dlg:modify { id = "rotDest", visible = isMix }

        dlg:modify { id = "easeCurve", visible = isMix }
        dlg:modify { id = "easeCurve_easeFuncs", visible = isMix }

        dlg:modify { id = "rotIncr", visible = isAdd }
        dlg:modify { id = "autoCalcIncr", visible = isAdd }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "facType",
    label = "Factor:",
    option = defaults.facType,
    options = facTypes,
    visible = defaults.mode == "MIX"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "angleType",
    label = "Easing:",
    option = defaults.angleType,
    options = angleTypes,
    visible = defaults.mode == "MIX"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "axis",
    label = "Axis:",
    option = defaults.axis,
    options = axes
}

dlg:newrow { always = false }

dlg:check {
    id = "trimCel",
    label = "Trim:",
    text = "Layer Ed&ges",
    selected = defaults.trimCel,
    visible = false
}

dlg:separator {
    id = "origSeparator",
    text = "Origin"
}

dlg:number {
    id = "frameOrig",
    label = "Frame:",
    text = string.format("%d", defaults.frameOrig),
    decimals = 0
}

dlg:newrow { always = false }

dlg:slider {
    id = "rotOrig",
    label = "Degrees:",
    min = 0,
    max = 360,
    value = defaults.rotOrig,
    visible = defaults.mode == "MIX"
}

dlg:separator {
    id = "destSeparator",
    text = "Destination"
}

dlg:number {
    id = "frameDest",
    label = "Frame:",
    text = string.format("%d", defaults.frameDest),
    decimals = 0,
    focus = true
}

dlg:newrow { always = false }

dlg:slider {
    id = "rotDest",
    label = "Degrees:",
    min = 0,
    max = 360,
    value = defaults.rotDest,
    visible = defaults.mode == "MIX"
}

dlg:separator { id = "easeSeparator" }

dlg:number {
    id = "rotIncr",
    label = "Degrees:",
    text = string.format("%.3f", defaults.rotIncr),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.mode == "ADD"
}

dlg:button {
    id = "autoCalcIncr",
    text = "&AUTO",
    visible = defaults.mode == "ADD",
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end

        local frObjs <const> = activeSprite.frames
        local lenFrames <const> = #frObjs
        if lenFrames <= 1 then return end

        local args <const> = dlg.data
        local frIdxOrig <const> = args.frameOrig
            or defaults.frameOrig --[[@as integer]]
        local frIdxDest <const> = args.frameDest
            or defaults.frameDest --[[@as integer]]

        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        local frIdxOrigVerif = math.min(math.max(
            frIdxOrig - frameUiOffset, 1), lenFrames)
        local frIdxDestVerif = math.min(math.max(
            frIdxDest - frameUiOffset, 1), lenFrames)

        if frIdxOrigVerif == frIdxDestVerif then
            frIdxOrigVerif = 1
            frIdxDestVerif = lenFrames
        end
        if frIdxDestVerif < frIdxOrigVerif then
            frIdxOrigVerif, frIdxDestVerif = frIdxDestVerif, frIdxOrigVerif
        end

        local countFrames <const> = 1 + frIdxDestVerif - frIdxOrigVerif
        local autoIncr <const> = 360.0 / countFrames
        dlg:modify { id = "rotIncr", text = string.format("%.3f", autoIncr) }
    end
}

dlg:newrow { always = false }

CanvasUtilities.graphBezier(
    dlg, "easeCurve", "Easing:",
    128 // screenScale,
    128 // screenScale,
    defaults.mode == "MIX",
    false, false, true, false,
    5, 0.25, 0.1, 0.25, 1.0,
    curveColor, gridColor)

dlg:button {
    id = "confirm",
    text = "&OK",
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local srcFrame <const> = site.frame
        if not srcFrame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
            }
            return
        end

        local frObjs <const> = activeSprite.frames
        local lenFrames <const> = #frObjs
        if lenFrames <= 1 then
            app.alert {
                title = "Error",
                text = "The sprite has too few frames."
            }
            return
        end

        local srcLayer <const> = site.layer
        if not srcLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
            }
            return
        end

        if srcLayer.isReference then
            app.alert {
                title = "Error",
                text = "Reference layers are not supported."
            }
            return
        end

        local args <const> = dlg.data
        local frIdxOrig <const> = args.frameOrig
            or defaults.frameOrig --[[@as integer]]
        local frIdxDest <const> = args.frameDest
            or defaults.frameDest --[[@as integer]]

        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        local frIdxOrigVerif = math.min(math.max(
            frIdxOrig - frameUiOffset, 1), lenFrames)
        local frIdxDestVerif = math.min(math.max(
            frIdxDest - frameUiOffset, 1), lenFrames)

        if frIdxOrigVerif == frIdxDestVerif then
            frIdxOrigVerif = 1
            frIdxDestVerif = lenFrames
        end
        if frIdxDestVerif < frIdxOrigVerif then
            frIdxOrigVerif, frIdxDestVerif = frIdxDestVerif, frIdxOrigVerif
        end

        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        local colorSpace <const> = spriteSpec.colorSpace
        local alphaIndex <const> = spriteSpec.transparentColor

        local srcImg = nil
        local tlxSrc = 0
        local tlySrc = 0
        if srcLayer.isGroup then
            local flatImg <const>,
            flatRect <const> = AseUtilities.flattenGroup(
                srcLayer, srcFrame, colorMode, colorSpace, alphaIndex,
                true, false, true, true)
            srcImg = flatImg
            tlxSrc = flatRect.x
            tlySrc = flatRect.y
        else
            local srcCel <const> = srcLayer:cel(srcFrame)
            if srcCel then
                local celPos <const> = srcCel.position
                tlxSrc = celPos.x
                tlySrc = celPos.y

                local celImg <const> = srcCel.image
                if srcLayer.isTilemap then
                    local tileSet <const> = srcLayer.tileset
                    srcImg = AseUtilities.tileMapToImage(
                        celImg, tileSet, colorMode)
                else
                    srcImg = celImg
                end
            end
        end

        if not srcImg then
            app.alert {
                title = "Error",
                text = "There is no source image."
            }
            return
        end

        if srcImg:isEmpty() then
            app.alert {
                title = "Error",
                text = "Source image is empty."
            }
            return
        end

        if srcLayer.isBackground then
            app.command.SwitchColors()
            local aseBkg <const> = app.fgColor
            local bkgHex <const> = AseUtilities.aseColorToHex(aseBkg, colorMode)
            app.command.SwitchColors()

            local cleared <const> = srcImg:clone()
            local clearedItr <const> = cleared:pixels()
            for pixel in clearedItr do
                if pixel() == bkgHex then pixel(alphaIndex) end
            end
            srcImg = cleared
        end

        local trimCel <const> = args.trimCel --[[@as boolean]]
        if trimCel then
            local trimmed <const>,
            tlxTrm <const>,
            tlyTrm <const> = AseUtilities.trimImageAlpha(srcImg, 0, alphaIndex)
            srcImg = trimmed
            tlxSrc = tlxSrc + tlxTrm
            tlySrc = tlySrc + tlyTrm
        end

        local axis <const> = args.axis
            or defaults.axis --[[@as string]]
        local rotateImage = AseUtilities.rotateImageZNearest
        if axis == "X" then
            rotateImage = AseUtilities.rotateImageXNearest
        elseif axis == "Y" then
            rotateImage = AseUtilities.rotateImageYNearest
        end

        local trgLayer = nil
        app.transaction("New Layer", function()
            trgLayer = activeSprite:newLayer()
            trgLayer.name = string.format("Rotate%s %s At %d From %d To %d",
                axis, srcLayer.name,
                srcFrame.frameNumber + frameUiOffset,
                frIdxOrigVerif + frameUiOffset,
                frIdxDestVerif + frameUiOffset)
            trgLayer.parent = srcLayer.parent
        end)

        local pxwSrc <const> = srcImg.width
        local pxhSrc <const> = srcImg.height
        local xCenter <const> = tlxSrc + pxwSrc * 0.5
        local yCenter <const> = tlySrc + pxhSrc * 0.5

        local mode <const> = args.mode
            or defaults.mode --[[@as string]]
        if mode == "ADD" then
            local rotIncrDeg <const> = args.rotIncr
                or defaults.rotIncr --[[@as integer]]
            local currDeg = 0
            local countFrames <const> = 1 + frIdxDestVerif - frIdxOrigVerif

            -- Cache methods used in loop.
            local floor <const> = math.floor

            app.transaction("Rotate Cels", function()
                local j = 0
                while j < countFrames do
                    local frObj <const> = frObjs[frIdxOrigVerif + j]
                    local trgImg <const> = rotateImage(srcImg, currDeg)

                    local trgPoint <const> = Point(
                        floor(xCenter - trgImg.width * 0.5),
                        floor(yCenter - trgImg.height * 0.5))

                    activeSprite:newCel(trgLayer, frObj, trgImg, trgPoint)

                    j = j + 1
                    currDeg = currDeg + rotIncrDeg
                end
            end)
        else
            ---@type number[]
            local factors <const> = {}
            local countFrames <const> = 1 + frIdxDestVerif - frIdxOrigVerif

            local facType <const> = args.facType
                or defaults.facType --[[@as string]]
            if facType == "TIME" then
                ---@type number[]
                local timeStamps <const> = {}
                local totalDuration = 0

                local h = 0
                while h < countFrames do
                    local frObj <const> = frObjs[frIdxOrigVerif + h]
                    timeStamps[1 + h] = totalDuration
                    totalDuration = totalDuration + frObj.duration
                    h = h + 1
                end

                local timeToFac = 0.0
                local finalDuration <const> = timeStamps[countFrames]
                if finalDuration and finalDuration ~= 0.0 then
                    timeToFac = 1.0 / finalDuration
                end

                local i = 0
                while i < countFrames do
                    i = i + 1
                    factors[i] = timeStamps[i] * timeToFac
                end
            else
                -- Default to using frames.
                local iToFac <const> = 1.0 / (countFrames - 1)
                local i = 0
                while i < countFrames do
                    local iFac <const> = i * iToFac
                    i = i + 1
                    factors[i] = iFac
                end
            end

            local ap0x <const> = args.easeCurve_ap0x --[[@as number]]
            local ap0y <const> = args.easeCurve_ap0y --[[@as number]]
            local cp0x <const> = args.easeCurve_cp0x --[[@as number]]
            local cp0y <const> = args.easeCurve_cp0y --[[@as number]]
            local cp1x <const> = args.easeCurve_cp1x --[[@as number]]
            local cp1y <const> = args.easeCurve_cp1y --[[@as number]]
            local ap1x <const> = args.easeCurve_ap1x --[[@as number]]
            local ap1y <const> = args.easeCurve_ap1y --[[@as number]]

            local kn0 <const> = Knot2.new(
                Vec2.new(ap0x, ap0y),
                Vec2.new(cp0x, cp0y),
                Vec2.new(0.0, ap0y))
            local kn1 <const> = Knot2.new(
                Vec2.new(ap1x, ap1y),
                Vec2.new(1.0, ap1y),
                Vec2.new(cp1x, cp1y))
            local curve = Curve2.new(false, { kn0, kn1 }, "rot easing")

            local alpSampleCount <const> = defaults.alpSampleCount
            local totalLength <const>, arcLengths <const> = Curve2.arcLength(
                curve, alpSampleCount)
            local samples <const> = Curve2.paramPoints(
                curve, totalLength, arcLengths, alpSampleCount)

            local rotOrigDeg <const> = args.rotOrig
                or defaults.rotOrig --[[@as integer]]
            local rotDestDeg <const> = args.rotDest
                or defaults.rotDest --[[@as integer]]
            local angleType <const> = args.angleType
                or defaults.angleType --[[@as string]]

            --Easing functions default to using degrees.
            local angleMixDeg = Utilities.lerpAngleNear
            if angleType == "CCW" then
                angleMixDeg = Utilities.lerpAngleCcw
            elseif angleType == "CW" then
                angleMixDeg = Utilities.lerpAngleCw
            elseif angleType == "FAR" then
                angleMixDeg = Utilities.lerpAngleFar
            end

            -- Cache methods used in loop.
            local floor <const> = math.floor
            local eval <const> = Curve2.eval

            app.transaction("Tween Cel Rotation", function()
                local j = 0
                while j < countFrames do
                    local frObj <const> = frObjs[frIdxOrigVerif + j]
                    local fac <const> = factors[1 + j]
                    local t = eval(curve, fac).x
                    if fac > 0.0 and fac < 1.0 then
                        local tScale <const> = t * (alpSampleCount - 1)
                        local tFloor <const> = floor(tScale)
                        local tFrac <const> = tScale - tFloor
                        local left <const> = samples[1 + tFloor].y
                        local right <const> = samples[2 + tFloor].y
                        t = (1.0 - tFrac) * left + tFrac * right
                    end

                    local degTrg <const> = angleMixDeg(
                        rotOrigDeg, rotDestDeg, t, 360.0)
                    local trgImg <const> = rotateImage(srcImg, degTrg)

                    local trgPoint <const> = Point(
                        floor(xCenter - trgImg.width * 0.5),
                        floor(yCenter - trgImg.height * 0.5))

                    activeSprite:newCel(trgLayer, frObj, trgImg, trgPoint)
                    j = j + 1
                end
            end)
        end

        app.layer = srcLayer
        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = true,
    wait = false
}
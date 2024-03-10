dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local facTypes <const> = { "FRAME", "TIME" }
local unitOptions <const> = { "PERCENT", "PIXEL" }

local screenScale <const> = app.preferences.general.screen_scale --[[@as integer]]
local curveColor <const> = app.theme.color.text --[[@as Color]]
local gridColor <const> = Color { r = 128, g = 128, b = 128 }

local defaults <const> = {
    facType = "TIME",
    trimCel = true,

    frameOrig = 1,
    pxwOrig = 64,
    pxhOrig = 64,
    prcwOrig = 100,
    prchOrig = 100,

    frameDest = 1,
    pxwDest = 64,
    pxhDest = 64,
    prcwDest = 100,
    prchDest = 100,

    units = "PIXEL",
    alpSampleCount = 96,
}

---@return integer frIdx
---@return integer pxWidth
---@return integer pxHeight
local function getCelBoundsAtFrame()
    local site <const> = app.site
    local activeSprite <const> = site.sprite
    local appPrefs <const> = app.preferences
    if not activeSprite then
        local newFilePrefs <const> = appPrefs.new_file
        return 1, newFilePrefs.width, newFilePrefs.height
    end

    local docPrefs <const> = appPrefs.document(activeSprite)
    local tlPrefs <const> = docPrefs.timeline
    local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

    local frIdx = frameUiOffset + 1
    local pxWidth = activeSprite.width
    local pxHeight = activeSprite.height

    local activeFrame <const> = site.frame
    if activeFrame then
        frIdx = activeFrame.frameNumber + frameUiOffset
    end

    -- It'd be nice support measuring flattened group cels,
    -- but the current method flattens in place.
    local activeLayer <const> = site.layer
    if activeLayer and activeFrame then
        if not activeLayer.isReference then
            local activeCel <const> = activeLayer:cel(activeFrame)
            if activeCel then
                local celImage <const> = activeCel.image
                local wTile = 1
                local hTile = 1

                if activeLayer.isTilemap then
                    local tileSet <const> = activeLayer.tileset
                    if tileSet then
                        local tileGrid <const> = tileSet.grid
                        local tileDim <const> = tileGrid.tileSize
                        wTile = math.max(1, math.abs(tileDim.width))
                        hTile = math.max(1, math.abs(tileDim.height))
                    end
                end

                pxWidth = celImage.width * wTile
                pxHeight = celImage.height * hTile
            end
        end
    end

    return frIdx, pxWidth, pxHeight
end

local dlg <const> = Dialog { title = "Tween Scale" }

dlg:combobox {
    id = "facType",
    label = "Factor:",
    option = defaults.facType,
    options = facTypes
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

dlg:number {
    id = "pxwOrig",
    label = "Pixels:",
    text = string.format("%d", app.preferences.new_file.width),
    decimals = 0,
    visible = defaults.units == "PIXEL"
}

dlg:number {
    id = "pxhOrig",
    text = string.format("%d", app.preferences.new_file.height),
    decimals = 0,
    visible = defaults.units == "PIXEL"
}

dlg:number {
    id = "prcwOrig",
    label = "Percent:",
    text = string.format("%.2f", defaults.prcwOrig),
    decimals = 6,
    visible = defaults.units == "PERCENT"
}

dlg:number {
    id = "prchOrig",
    text = string.format("%.2f", defaults.prchOrig),
    decimals = 6,
    visible = defaults.units == "PERCENT"
}

dlg:newrow { always = false }

dlg:button {
    id = "getOrig",
    label = "Get:",
    text = "&FROM",
    onclick = function()
        local frIdx <const>, pxw <const>, pxh <const> = getCelBoundsAtFrame()
        dlg:modify { id = "frameOrig", text = string.format("%d", frIdx) }
        dlg:modify { id = "pxwOrig", text = string.format("%d", pxw) }
        dlg:modify { id = "pxhOrig", text = string.format("%d", pxh) }
        dlg:modify { id = "prcwOrig", text = string.format("%.2f", 100) }
        dlg:modify { id = "prchOrig", text = string.format("%.2f", 100) }
    end
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

dlg:number {
    id = "pxwDest",
    label = "Pixels:",
    text = string.format("%d", app.preferences.new_file.width),
    decimals = 0,
    visible = defaults.units == "PIXEL"
}

dlg:number {
    id = "pxhDest",
    text = string.format("%d", app.preferences.new_file.height),
    decimals = 0,
    visible = defaults.units == "PIXEL"
}

dlg:number {
    id = "prcwDest",
    label = "Percent:",
    text = string.format("%.2f", defaults.prcwDest),
    decimals = 6,
    visible = defaults.units == "PERCENT"
}

dlg:number {
    id = "prchDest",
    text = string.format("%.2f", defaults.prchDest),
    decimals = 6,
    visible = defaults.units == "PERCENT"
}

dlg:newrow { always = false }

dlg:button {
    id = "getDest",
    label = "Get:",
    text = "&TO",
    onclick = function()
        local frIdx <const>, pxw <const>, pxh <const> = getCelBoundsAtFrame()
        dlg:modify { id = "frameDest", text = string.format("%d", frIdx) }
        dlg:modify { id = "pxwDest", text = string.format("%d", pxw) }
        dlg:modify { id = "pxhDest", text = string.format("%d", pxh) }
        dlg:modify { id = "prcwDest", text = string.format("%.2f", 100) }
        dlg:modify { id = "prchDest", text = string.format("%.2f", 100) }
    end
}

dlg:combobox {
    id = "units",
    label = "Units:",
    option = defaults.units,
    options = unitOptions,
    onchange = function()
        local args <const> = dlg.data
        local unitType <const> = args.units --[[@as string]]
        local ispx <const> = unitType == "PIXEL"
        local ispc <const> = unitType == "PERCENT"

        dlg:modify { id = "pxwOrig", visible = ispx }
        dlg:modify { id = "pxhOrig", visible = ispx }
        dlg:modify { id = "prcwOrig", visible = ispc }
        dlg:modify { id = "prchOrig", visible = ispc }

        dlg:modify { id = "pxwDest", visible = ispx }
        dlg:modify { id = "pxhDest", visible = ispx }
        dlg:modify { id = "prcwDest", visible = ispc }
        dlg:modify { id = "prchDest", visible = ispc }
    end
}

dlg:separator { id = "easeSeparator" }

CanvasUtilities.graphBezier(
    dlg, "easeCurve", "Easing:",
    128 // screenScale,
    128 // screenScale,
    true, false, false, true, false,
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

        local frObjs <const> = activeSprite.frames
        local lenFrames <const> = #frObjs
        if lenFrames <= 1 then
            app.alert {
                title = "Error",
                text = "The sprite has too few frames."
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

        local trgLayer = nil
        app.transaction("New Layer", function()
            trgLayer = activeSprite:newLayer()
            trgLayer.name = string.format("Scale %s At %d From %d To %d",
                srcLayer.name,
                srcFrame.frameNumber + frameUiOffset,
                frIdxOrigVerif + frameUiOffset,
                frIdxDestVerif + frameUiOffset)
            trgLayer.parent = srcLayer.parent
        end)

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
        local curve = Curve2.new(false, { kn0, kn1 }, "scale easing")

        local alpSampleCount <const> = defaults.alpSampleCount
        local totalLength <const>, arcLengths <const> = Curve2.arcLength(
            curve, alpSampleCount)
        local samples <const> = Curve2.paramPoints(
            curve, totalLength, arcLengths, alpSampleCount)

        -- Should these be swapped as well when dest frame is gt orig?
        local pxwOrig = args.pxwOrig
            or defaults.pxwOrig --[[@as number]]
        local pxhOrig = args.pxhOrig
            or defaults.pxhOrig --[[@as number]]
        local prcwOrig = args.prcwOrig
            or defaults.prcwOrig --[[@as number]]
        local prchOrig = args.prchOrig
            or defaults.prchOrig --[[@as number]]

        local pxwDest = args.pxwDest
            or defaults.pxwDest --[[@as number]]
        local pxhDest = args.pxhDest
            or defaults.pxhDest --[[@as number]]
        local prcwDest = args.prcwDest
            or defaults.prcwDest --[[@as number]]
        local prchDest = args.prchDest
            or defaults.prchDest --[[@as number]]

        pxwOrig = math.max(1.0, math.abs(pxwOrig))
        pxhOrig = math.max(1.0, math.abs(pxhOrig))
        pxwDest = math.max(1.0, math.abs(pxwDest))
        pxhDest = math.max(1.0, math.abs(pxhDest))

        local pxwSrc <const> = srcImg.width
        local pxhSrc <const> = srcImg.height
        local xCenter <const> = tlxSrc + pxwSrc * 0.5
        local yCenter <const> = tlySrc + pxhSrc * 0.5

        local unitType <const> = args.units
            or defaults.units --[[@as string]]
        if unitType == "PERCENT" then
            prcwOrig = 0.01 * math.abs(prcwOrig)
            prchOrig = 0.01 * math.abs(prchOrig)
            pxwOrig = math.max(1.0, pxwSrc * prcwOrig)
            pxhOrig = math.max(1.0, pxhSrc * prchOrig)

            prcwDest = 0.01 * math.abs(prcwDest)
            prchDest = 0.01 * math.abs(prchDest)
            pxwDest = math.max(1.0, pxwSrc * prcwDest)
            pxhDest = math.max(1.0, pxhSrc * prchDest)
        end

        -- Cache methods used in loop.
        local max <const> = math.max
        local floor <const> = math.floor
        local eval <const> = Curve2.eval
        local resizeImage <const> = AseUtilities.resizeImageNearest

        app.transaction("Tween Cel Scale", function()
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
                local u <const> = 1.0 - t

                local wTrg <const> = max(1, floor(0.5
                    + u * pxwOrig + t * pxwDest))
                local hTrg <const> = max(1, floor(0.5
                    + u * pxhOrig + t * pxhDest))
                local trgImg <const> = resizeImage(srcImg, wTrg, hTrg)

                local trgPoint <const> = Point(
                    floor(xCenter - wTrg * 0.5),
                    floor(yCenter - hTrg * 0.5))

                activeSprite:newCel(trgLayer, frObj, trgImg, trgPoint)
                j = j + 1
            end
        end)

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
dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local modes <const> = { "ADD", "MIX" }
local facTypes <const> = { "FRAME", "TIME" }
local angleTypes <const> = { "CCW", "CW", "NEAR" }
local axes <const> = { "X", "Y", "Z" }
local unitOptions <const> = { "PERCENT", "PIXEL" }

local screenScale = 1
if app.preferences then
    local generalPrefs <const> = app.preferences.general
    if generalPrefs then
        local ssCand <const> = generalPrefs.screen_scale --[[@as integer]]
        if ssCand and ssCand > 0 then
            screenScale = ssCand
        end
    end
end

local curveColor = Color { r = 13, g = 13, b = 13 }
local gridColor <const> = Color { r = 128, g = 128, b = 128 }
if app.theme then
    local theme <const> = app.theme
    if theme then
        local themeColor <const> = theme.color
        if themeColor then
            local textColor <const> = themeColor.text --[[@as Color]]
            if textColor and textColor.alpha > 0 then
                curveColor = AseUtilities.aseColorCopy(textColor, "")
            end
        end
    end
end

local defaults <const> = {
    -- With default theme, 200% screen scaling, 100% UI, dialog is too tall to
    -- fit on screen without a scrollbar. Selecting certain GUI elements causes
    -- the dialog to collapse in size.

    -- Last commit before tween position, rotation, scale were removed:
    -- 759a3838381c91393a77d7b3aedc5de134790e6f .

    -- Rotation is no longer set as a cel property because properties would be
    -- a pain to deep copy when a cel is swapped or a layer converted.
    mode = "MIX",
    facType = "TIME",
    axis = "Z",
    angleType = "NEAR",
    units = "PERCENT",
    alpSampleCount = 96,
    usePreIncr = false,

    -- Mix mode:
    frameOrig = 1,
    xPosOrig = 0.0,
    yPosOrig = 0.0,
    rotOrig = 0,
    prcwOrig = 100,
    prchOrig = 100,

    frameDest = 1,
    xPosDest = 0.0,
    yPosDest = 0.0,
    rotDest = 0,
    prcwDest = 100,
    prchDest = 100,

    -- Add mode:
    xIncr = 0,
    yIncr = 0,
    rotIncr = 0,
    wIncr = 0,
    hIncr = 0,
}

---@param axis string
---@return integer frIdx
---@return number xCenter
---@return number yCenter
---@return integer rotDeg
---@return integer pxWidth
---@return integer pxHeight
local function getCelDataAtFrame(axis)
    -- Axis was needed to retrieve custom cel properties. However, because
    -- properties cannot be copied between cels without creating a custom
    -- deep-copy-by-value method, that was removed.

    local site <const> = app.site
    local activeSprite <const> = site.sprite
    local appPrefs <const> = app.preferences
    if not activeSprite then
        if appPrefs then
            local newFilePrefs <const> = appPrefs.new_file
            if newFilePrefs then
                local wNfp <const> = newFilePrefs.width --[[@as integer]]
                local hNfp <const> = newFilePrefs.height --[[@as integer]]
                return 1, wNfp * 0.5, hNfp * 0.5, -1, wNfp, hNfp
            end
        end
        return 1, 0.0, 0.0, -1, 0, 0
    end

    local frameUiOffset = 0
    if appPrefs then
        local docPrefs <const> = appPrefs.document(activeSprite)
        if docPrefs then
            local tlPrefs <const> = docPrefs.timeline
            if tlPrefs then
                frameUiOffset = tlPrefs.first_frame - 1 --[[@as integer]]
            end
        end
    end

    local spriteSpec <const> = activeSprite.spec
    local wSprite <const> = spriteSpec.width
    local hSprite <const> = spriteSpec.height
    local alphaIndex <const> = spriteSpec.transparentColor

    local frIdx = frameUiOffset + 1
    local pxWidth = wSprite
    local pxHeight = hSprite
    local rotDeg = -1

    local xMouse <const>, yMouse <const> = AseUtilities.getMouse()
    local xCenter = xMouse + 0.0
    local yCenter = yMouse + 0.0

    local activeFrame <const> = site.frame or activeSprite.frames[1]
    frIdx = activeFrame.frameNumber + frameUiOffset

    local getFlat = false
    local activeLayer <const> = site.layer or activeSprite.layers[1]
    if not activeLayer.isReference then
        local activeCel <const> = activeLayer:cel(activeFrame)
        if activeCel then
            local celPos <const> = activeCel.position
            local xtl <const> = celPos.x
            local ytl <const> = celPos.y

            local celImage <const> = activeCel.image

            if activeLayer.isTilemap then
                local tileSet <const> = activeLayer.tileset
                if tileSet then
                    local tileDim <const> = tileSet.grid.tileSize
                    local wTile <const> = math.max(1, math.abs(tileDim.width))
                    local hTile <const> = math.max(1, math.abs(tileDim.height))

                    pxWidth = celImage.width * wTile
                    pxHeight = celImage.height * hTile
                    xCenter = xtl + pxWidth * 0.5
                    yCenter = ytl + pxHeight * 0.5
                end
            else
                local rect <const> = celImage:shrinkBounds(alphaIndex)
                if rect.width > 0 and rect.height > 0 then
                    pxWidth = rect.width
                    pxHeight = rect.height
                    xCenter = xtl + rect.x + pxWidth * 0.5
                    yCenter = ytl + rect.y + pxHeight * 0.5
                else
                    pxWidth = celImage.width
                    pxHeight = celImage.height
                    xCenter = xtl + pxWidth * 0.5
                    yCenter = ytl + pxHeight * 0.5
                end
            end
        else
            getFlat = true
        end
    else
        getFlat = true
    end

    if getFlat then
        local flat <const> = Image(spriteSpec)
        flat:drawSprite(activeSprite, activeFrame, Point(0, 0))
        local rect <const> = flat:shrinkBounds(alphaIndex)
        if rect.width > 0 and rect.height > 0 then
            pxWidth = rect.width
            pxHeight = rect.height
            xCenter = rect.x + pxWidth * 0.5
            yCenter = rect.y + pxHeight * 0.5
        end
    end

    return frIdx, xCenter, yCenter, rotDeg, pxWidth, pxHeight
end

local dlg <const> = Dialog { title = "Anim Transform" }

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

        local unitType <const> = args.units --[[@as string]]
        local ispx <const> = unitType == "PIXEL"
        local ispc <const> = unitType == "PERCENT"

        -- dlg:modify { id = "facType", visible = isMix }
        dlg:modify { id = "angleType", visible = isMix }
        dlg:modify { id = "units", visible = isMix }
        dlg:modify { id = "easeCurve", visible = isMix }
        dlg:modify { id = "easeCurve_easeFuncs", visible = isMix }

        dlg:modify { id = "xPosOrig", visible = isMix }
        dlg:modify { id = "yPosOrig", visible = isMix }
        dlg:modify { id = "rotOrig", visible = isMix }
        dlg:modify { id = "pxwOrig", visible = isMix and ispx }
        dlg:modify { id = "pxhOrig", visible = isMix and ispx }
        dlg:modify { id = "prcwOrig", visible = isMix and ispc }
        dlg:modify { id = "prchOrig", visible = isMix and ispc }

        dlg:modify { id = "xPosDest", visible = isMix }
        dlg:modify { id = "yPosDest", visible = isMix }
        dlg:modify { id = "rotDest", visible = isMix }
        dlg:modify { id = "pxwDest", visible = isMix and ispx }
        dlg:modify { id = "pxhDest", visible = isMix and ispx }
        dlg:modify { id = "prcwDest", visible = isMix and ispc }
        dlg:modify { id = "prchDest", visible = isMix and ispc }

        dlg:modify { id = "usePreIncr", visible = isAdd }
        dlg:modify { id = "xIncr", visible = isAdd }
        dlg:modify { id = "yIncr", visible = isAdd }
        dlg:modify { id = "rotIncr", visible = isAdd }
        dlg:modify { id = "autoCalcIncr", visible = isAdd }
        dlg:modify { id = "wIncr", visible = isAdd }
        dlg:modify { id = "hIncr", visible = isAdd }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "facType",
    label = "Factor:",
    option = defaults.facType,
    options = facTypes,
    -- visible = defaults.mode == "MIX"
    visible = false
}

dlg:newrow { always = false }

dlg:combobox {
    id = "axis",
    label = "Axis:",
    option = defaults.axis,
    options = axes
}

dlg:combobox {
    id = "angleType",
    -- label = "Angle:",
    option = defaults.angleType,
    options = angleTypes,
    visible = defaults.mode == "MIX"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "units",
    label = "Units:",
    option = defaults.units,
    options = unitOptions,
    visible = defaults.mode == "MIX",
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

dlg:newrow { always = false }

dlg:button {
    id = "getOrig",
    label = "Get:",
    text = "&FROM",
    focus = defaults.mode == "MIX",
    onclick = function()
        local args <const> = dlg.data
        local axis <const> = args.axis --[[@as string]]

        local frIdx <const>,
        xc <const>, yc <const>,
        rotDeg <const>,
        pxw <const>, pxh <const> = getCelDataAtFrame(axis)

        dlg:modify { id = "frameOrig", text = string.format("%d", frIdx) }

        dlg:modify { id = "xPosOrig", text = string.format("%.1f", xc) }
        dlg:modify { id = "yPosOrig", text = string.format("%.1f", yc) }

        if rotDeg ~= -1 then
            dlg:modify { id = "rotOrig", value = rotDeg }
        end

        dlg:modify { id = "pxwOrig", text = string.format("%d", pxw) }
        dlg:modify { id = "pxhOrig", text = string.format("%d", pxh) }
        dlg:modify { id = "prcwOrig", text = string.format("%.2f", 100) }
        dlg:modify { id = "prchOrig", text = string.format("%.2f", 100) }
    end
}

dlg:button {
    id = "getDest",
    text = "&TO",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local axis <const> = args.axis --[[@as string]]
        local frIdx <const>,
        xc <const>, yc <const>,
        rotDeg <const>,
        pxw <const>, pxh <const> = getCelDataAtFrame(axis)

        dlg:modify { id = "frameDest", text = string.format("%d", frIdx) }

        dlg:modify { id = "xPosDest", text = string.format("%.1f", xc) }
        dlg:modify { id = "yPosDest", text = string.format("%.1f", yc) }

        if rotDeg ~= -1 then
            dlg:modify { id = "rotDest", value = rotDeg }
        end

        dlg:modify { id = "pxwDest", text = string.format("%d", pxw) }
        dlg:modify { id = "pxhDest", text = string.format("%d", pxh) }
        dlg:modify { id = "prcwDest", text = string.format("%.2f", 100) }
        dlg:modify { id = "prchDest", text = string.format("%.2f", 100) }
    end
}

dlg:separator {
    id = "origSeparator",
    text = "From"
}

dlg:number {
    id = "frameOrig",
    label = "Frame:",
    text = string.format("%d", defaults.frameOrig),
    decimals = 0
}

dlg:newrow { always = false }

dlg:number {
    id = "xPosOrig",
    label = "Position:",
    text = string.format("%.1f", defaults.xPosOrig),
    decimals = 1,
    visible = defaults.mode == "MIX"
}

dlg:number {
    id = "yPosOrig",
    text = string.format("%.1f", defaults.yPosOrig),
    decimals = 1,
    visible = defaults.mode == "MIX"
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

dlg:newrow { always = false }

dlg:number {
    id = "pxwOrig",
    label = "Scale:",
    text = string.format("%d", app.preferences.new_file.width),
    decimals = 0,
    visible = defaults.mode == "MIX"
        and defaults.units == "PIXEL"
}

dlg:number {
    id = "pxhOrig",
    text = string.format("%d", app.preferences.new_file.height),
    decimals = 0,
    visible = defaults.mode == "MIX"
        and defaults.units == "PIXEL"
}

dlg:newrow { always = false }

dlg:number {
    id = "prcwOrig",
    label = "Scale:",
    text = string.format("%.3f", defaults.prcwOrig),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.mode == "MIX"
        and defaults.units == "PERCENT"
}

dlg:number {
    id = "prchOrig",
    text = string.format("%.3f", defaults.prchOrig),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.mode == "MIX"
        and defaults.units == "PERCENT"
}

dlg:separator {
    id = "destSeparator",
    text = "To"
}

dlg:number {
    id = "frameDest",
    label = "Frame:",
    text = string.format("%d", defaults.frameDest),
    decimals = 0,
    focus = false
}

dlg:newrow { always = false }

dlg:number {
    id = "xPosDest",
    label = "Position:",
    text = string.format("%.1f", defaults.xPosDest),
    decimals = 1,
    visible = defaults.mode == "MIX"
}

dlg:number {
    id = "yPosDest",
    text = string.format("%.1f", defaults.yPosDest),
    decimals = 1,
    visible = defaults.mode == "MIX"
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

dlg:newrow { always = false }

dlg:number {
    id = "pxwDest",
    label = "Scale:",
    text = string.format("%d", app.preferences.new_file.width),
    decimals = 0,
    visible = defaults.mode == "MIX"
        and defaults.units == "PIXEL"
}

dlg:number {
    id = "pxhDest",
    text = string.format("%d", app.preferences.new_file.height),
    decimals = 0,
    visible = defaults.mode == "MIX"
        and defaults.units == "PIXEL"
}

dlg:newrow { always = false }

dlg:number {
    id = "prcwDest",
    label = "Scale:",
    text = string.format("%.3f", defaults.prcwDest),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.mode == "MIX"
        and defaults.units == "PERCENT"
}

dlg:number {
    id = "prchDest",
    text = string.format("%.3f", defaults.prchDest),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.mode == "MIX"
        and defaults.units == "PERCENT"
}

dlg:separator { id = "easeSeparator" }

dlg:check {
    id = "usePreIncr",
    label = "Add:",
    text = "Before",
    selected = defaults.usePreIncr,
    visible = defaults.mode == "ADD"
}

dlg:newrow { always = false }

dlg:number {
    id = "xIncr",
    label = "Vector:",
    text = string.format("%d", defaults.xIncr),
    decimals = 0,
    visible = defaults.mode == "ADD"
}

dlg:number {
    id = "yIncr",
    text = string.format("%d", defaults.yIncr),
    decimals = 0,
    visible = defaults.mode == "ADD"
}

dlg:newrow { always = false }

dlg:number {
    id = "rotIncr",
    label = "Degrees:",
    text = string.format("%.3f", defaults.rotIncr),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.mode == "ADD"
}

dlg:newrow { always = false }

dlg:button {
    id = "autoCalcIncr",
    text = "&AUTO",
    visible = defaults.mode == "ADD",
    focus = defaults.mode == "ADD",
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

dlg:number {
    id = "wIncr",
    label = "Scale:",
    text = string.format("%d", defaults.wIncr),
    decimals = 0,
    visible = defaults.mode == "ADD"
}

dlg:number {
    id = "hIncr",
    text = string.format("%d", defaults.hIncr),
    decimals = 0,
    visible = defaults.mode == "ADD"
}

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

            local srcBytes <const> = srcImg.bytes
            local srcArea <const> = srcImg.width * srcImg.height
            local srcBpp <const> = srcImg.bytesPerPixel
            local imgFmt <const> = "<I" .. srcBpp
            local bkgHexPacked <const> = string.pack(imgFmt, bkgHex)
            local alphaIdxPacked <const> = string.pack(imgFmt, alphaIndex)
            local strsub <const> = string.sub

            ---@type string[]
            local trgByteArr <const> = {}

            local i = 0
            while i < srcArea do
                local ibpp <const> = i * srcBpp
                local srcHexPacked <const> = strsub(srcBytes, 1 + ibpp,
                    srcBpp + ibpp)
                local trgHexPacked = srcHexPacked
                if srcHexPacked == bkgHexPacked then
                    trgHexPacked = alphaIdxPacked
                end
                i = i + 1
                trgByteArr[i] = trgHexPacked
            end

            local cleared <const> = Image(srcImg.spec)
            cleared.bytes = table.concat(trgByteArr)
            srcImg = cleared
        end

        local trimCel <const> = true
        if trimCel then
            local trimmed <const>,
            tlxTrm <const>,
            tlyTrm <const> = AseUtilities.trimImageAlpha(srcImg, 0, alphaIndex)
            srcImg = trimmed
            tlxSrc = tlxSrc + tlxTrm
            tlySrc = tlySrc + tlyTrm
        end

        local args <const> = dlg.data
        local mode <const> = args.mode
            or defaults.mode --[[@as string]]

        local frIdxOrig <const> = args.frameOrig
            or defaults.frameOrig --[[@as integer]]
        local frIdxDest <const> = args.frameDest
            or defaults.frameDest --[[@as integer]]

        local xPosOrig = args.xPosOrig
            or defaults.xPosOrig --[[@as number]]
        local yPosOrig = args.yPosOrig
            or defaults.yPosOrig --[[@as number]]
        local rotOrigDeg = args.rotOrig
            or defaults.rotOrig --[[@as integer]]
        local pxwOrig = args.pxwOrig
            or defaults.pxwOrig --[[@as number]]
        local pxhOrig = args.pxhOrig
            or defaults.pxhOrig --[[@as number]]
        local prcwOrig = args.prcwOrig
            or defaults.prcwOrig --[[@as number]]
        local prchOrig = args.prchOrig
            or defaults.prchOrig --[[@as number]]

        local xPosDest = args.xPosDest
            or defaults.xPosDest --[[@as number]]
        local yPosDest = args.yPosDest
            or defaults.yPosOrig --[[@as number]]
        local rotDestDeg = args.rotDest
            or defaults.rotDest --[[@as integer]]
        local pxwDest = args.pxwDest
            or defaults.pxwDest --[[@as number]]
        local pxhDest = args.pxhDest
            or defaults.pxhDest --[[@as number]]
        local prcwDest = args.prcwDest
            or defaults.prcwDest --[[@as number]]
        local prchDest = args.prchDest
            or defaults.prchDest --[[@as number]]

        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        -- Confine origin and destination to frames in sprite.
        local frIdxOrigVerif = math.min(math.max(
            frIdxOrig - frameUiOffset, 1), lenFrames)
        local frIdxDestVerif = math.min(math.max(
            frIdxDest - frameUiOffset, 1), lenFrames)

        -- If origin and destination frames are equal,
        -- then default to all frames.
        if frIdxOrigVerif == frIdxDestVerif then
            frIdxOrigVerif = 1
            frIdxDestVerif = lenFrames
        end

        -- If destination is less than origin,
        -- then swap arguments.
        if frIdxDestVerif < frIdxOrigVerif then
            frIdxOrigVerif, frIdxDestVerif = frIdxDestVerif, frIdxOrigVerif

            xPosOrig, xPosDest = xPosDest, xPosOrig
            yPosOrig, yPosDest = yPosDest, yPosOrig

            rotOrigDeg, rotDestDeg = rotDestDeg, rotOrigDeg

            pxwOrig, pxwDest = pxwDest, pxwOrig
            pxhOrig, pxhDest = pxhDest, pxhOrig
            prcwOrig, prcwDest = prcwDest, prcwOrig
            prchOrig, prchDest = prchDest, prchOrig
        end

        local countFrames <const> = 1 + frIdxDestVerif - frIdxOrigVerif

        -- Create new layer.
        local trgLayer <const> = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            trgLayer.name = string.format("Tween %s At %d From %d To %d",
                srcLayer.name,
                srcFrame.frameNumber + frameUiOffset,
                frIdxOrigVerif + frameUiOffset,
                frIdxDestVerif + frameUiOffset)
            trgLayer.parent = srcLayer.parent
            trgLayer.opacity = srcLayer.opacity or 255
            trgLayer.blendMode = srcLayer.blendMode
                or BlendMode.NORMAL
        end)

        -- Cache methods used in loop.
        local resize <const> = AseUtilities.resizeImageNearest
        local floor <const> = math.floor
        local max <const> = math.max
        local eval <const> = Curve2.eval
        local transact <const> = app.transaction
        local round <const> = Utilities.round

        local rotateImage = AseUtilities.rotateImageZ
        local axis <const> = args.axis
            or defaults.axis --[[@as string]]
        if axis == "X" then
            rotateImage = AseUtilities.rotateImageX
        elseif axis == "Y" then
            rotateImage = AseUtilities.rotateImageY
        end

        if mode == "ADD" then
            local xIncr <const> = args.xIncr
                or defaults.xIncr --[[@as integer]]
            local yIncr <const> = args.yIncr
                or defaults.yIncr --[[@as integer]]
            local rotIncrDeg <const> = args.rotIncr
                or defaults.rotIncr --[[@as integer]]
            local wIncr <const> = args.wIncr
                or defaults.wIncr --[[@as integer]]
            local hIncr <const> = args.hIncr
                or defaults.hIncr --[[@as integer]]

            local currDeg = 0
            local wCurr = srcImg.width
            local hCurr = srcImg.height
            local xCurr = tlxSrc + wCurr * 0.5
            local yCurr = tlySrc + hCurr * 0.5

            local usePreIncr = args.usePreIncr --[[@as boolean]]
            if usePreIncr then
                xCurr = xCurr + xIncr
                yCurr = yCurr - yIncr
                currDeg = currDeg + rotIncrDeg
                wCurr = max(1, wCurr + wIncr)
                hCurr = max(1, hCurr + hIncr)
            end

            local j = 0
            while j < countFrames do
                local frIdx <const> = frIdxOrigVerif + j

                local trgImg = resize(srcImg, wCurr, hCurr)
                trgImg = rotateImage(trgImg, currDeg)
                local trgPoint <const> = Point(
                    floor(xCurr - trgImg.width * 0.5),
                    floor(yCurr - trgImg.height * 0.5))

                transact("Anim Cel", function()
                    activeSprite:newCel(
                        trgLayer, frIdx, trgImg, trgPoint)
                end)

                j = j + 1
                xCurr = xCurr + xIncr
                yCurr = yCurr - yIncr
                currDeg = currDeg + rotIncrDeg
                wCurr = max(1, wCurr + wIncr)
                hCurr = max(1, hCurr + hIncr)
            end -- End of frames loop.
        else
            ---@type number[]
            local factors <const> = {}
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

            -- Easing functions default to using degrees.
            local angleMixDeg = Utilities.lerpAngleNear
            local angleType <const> = args.angleType
                or defaults.angleType --[[@as string]]
            if angleType == "CCW" then
                angleMixDeg = Utilities.lerpAngleCcw
            elseif angleType == "CW" then
                angleMixDeg = Utilities.lerpAngleCw
            elseif angleType == "FAR" then
                angleMixDeg = Utilities.lerpAngleFar
            end

            pxwOrig = math.max(1.0, math.abs(pxwOrig))
            pxhOrig = math.max(1.0, math.abs(pxhOrig))
            pxwDest = math.max(1.0, math.abs(pxwDest))
            pxhDest = math.max(1.0, math.abs(pxhDest))

            local unitType <const> = args.units
                or defaults.units --[[@as string]]
            if unitType == "PERCENT" then
                local pxwSrc <const> = srcImg.width
                local pxhSrc <const> = srcImg.height

                prcwOrig = 0.01 * math.abs(prcwOrig)
                prchOrig = 0.01 * math.abs(prchOrig)
                pxwOrig = math.max(1.0, pxwSrc * prcwOrig)
                pxhOrig = math.max(1.0, pxhSrc * prchOrig)

                prcwDest = 0.01 * math.abs(prcwDest)
                prchDest = 0.01 * math.abs(prchDest)
                pxwDest = math.max(1.0, pxwSrc * prcwDest)
                pxhDest = math.max(1.0, pxhSrc * prchDest)
            end

            local j = 0
            while j < countFrames do
                local frIdx <const> = frIdxOrigVerif + j
                local fac <const> = factors[1 + j]
                local t = eval(curve, fac).x
                -- Can go out of bounds with 0.0 and 1.0 as boundaries
                -- with ease types like circ in and out.
                if fac > 0.000001 and fac < 0.999999 then
                    local tScale <const> = t * (alpSampleCount - 1)
                    local tFloor <const> = floor(tScale)
                    local tFrac <const> = tScale - tFloor
                    local left <const> = samples[1 + tFloor].y
                    local right <const> = samples[2 + tFloor].y
                    t = (1.0 - tFrac) * left + tFrac * right
                end
                local u <const> = 1.0 - t

                -- Scale.
                local wTrg <const> = max(1, floor(0.5
                    + u * pxwOrig + t * pxwDest))
                local hTrg <const> = max(1, floor(0.5
                    + u * pxhOrig + t * pxhDest))
                local trgImg = resize(srcImg, wTrg, hTrg)

                -- Rotate.
                local degTrg <const> = angleMixDeg(
                    rotOrigDeg, rotDestDeg, t, 360.0)
                trgImg = rotateImage(trgImg, degTrg)

                -- Translate.
                local xCenter <const> = u * xPosOrig + t * xPosDest
                local yCenter <const> = u * yPosOrig + t * yPosDest
                local xtl <const> = xCenter - trgImg.width * 0.5
                local ytl <const> = yCenter - trgImg.height * 0.5
                local xtlInt <const> = round(xtl)
                local ytlInt <const> = round(ytl)
                local trgPoint <const> = Point(xtlInt, ytlInt)

                transact("Anim Cel", function()
                    activeSprite:newCel(
                        trgLayer, frIdx, trgImg, trgPoint)
                end)

                j = j + 1
            end -- End of frames loop.
        end     -- End of add mix mode check.

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
    autoscrollbars = false,
    wait = false
}
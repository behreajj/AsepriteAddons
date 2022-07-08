dofile("../../support/aseutilities.lua")

local resizeMethods = { "BICUBIC", "NEAREST" }
local targets = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local unitOptions = { "PERCENT", "PIXEL" }

local defaults = {
    target = "ACTIVE",
    xTranslate = 0.0,
    yTranslate = 0.0,
    resizeMethod = "NEAREST",
    degrees = 0,
    rotBilin = true,
    pxWidth = 64,
    pxHeight = 64,
    prcWidth = 100,
    prcHeight = 100,
    units = "PERCENT"
}

local function rgbMix(
    rOrig, gOrig, bOrig, aOrig,
    rDest, gDest, bDest, aDest, t)
    local u = 1.0 - t
    local aMix = u * aOrig + t * aDest
    if aMix <= 0.0 then return 0.0, 0.0, 0.0, 0.0 end

    local rMix = u * rOrig + t * rDest
    local gMix = u * gOrig + t * gDest
    local bMix = u * bOrig + t * bDest

    -- Tries to avoid dark haloes, but will cause
    -- white haloes after multiple rotations.
    if aMix < 255.0 then
        local aInverse = 255.0 / aMix
        rMix = rMix * aInverse
        gMix = gMix * aInverse
        bMix = bMix * aInverse
    end

    return rMix, gMix, bMix, aMix
end

local function getTargetCels(
    activeSprite, targetPreset,
    bkgAllow, refAllow)

    local targetCels = {}
    local tinsert = table.insert
    local isUnlocked = AseUtilities.isEditableHierarchy

    -- TODO: Do not impact tile map layers!
    local vBkgAll = bkgAllow or false
    local vRefAll = refAllow or false
    if targetPreset == "ACTIVE" then
        local activeLayer = app.activeLayer
        if activeLayer then
            if isUnlocked(activeLayer, activeSprite)
                and (vBkgAll or not activeLayer.isBackground)
                and (vRefAll or not activeLayer.isReference) then
                local activeCel = app.activeCel
                if activeCel then
                    targetCels[1] = activeCel
                end
            end
        end
    elseif targetPreset == "RANGE" then
        local appRange = app.range
        local rangeCels = appRange.cels
        local rangeCelsLen = #rangeCels
        local i = 0
        while i < rangeCelsLen do i = i + 1
            local rangeCel = rangeCels[i]
            local celLayer = rangeCel.layer
            if isUnlocked(celLayer, activeSprite)
                and (vBkgAll or not celLayer.isBackground)
                and (not celLayer.isReference) then
                tinsert(targetCels, rangeCel)
            end
        end
    elseif targetPreset == "SELECTION" then
        local sel = activeSprite.selection
        if (not sel.isEmpty) then
            local selBounds = sel.bounds
            local xSel = selBounds.x
            local ySel = selBounds.y
            local activeSpec = activeSprite.spec
            local actFrame = app.activeFrame

            -- Create a subset of flattened sprite.
            local flatSpec = ImageSpec {
                width = math.max(1, selBounds.width),
                height = math.max(1, selBounds.height),
                colorMode = activeSpec.colorMode,
                transparentColor = activeSpec.transparentColor }
            flatSpec.colorSpace = activeSpec.colorSpace
            local flatImage = Image(flatSpec)
            flatImage:drawSprite(
                activeSprite,
                actFrame.frameNumber,
                Point(-xSel, -ySel))

            -- Remove pixels within selection bounds
            -- but not within selection itself.
            local xMin = xSel
            local yMin = ySel
            local flatPxItr = flatImage:pixels()
            for elm in flatPxItr do
                local x = elm.x + xMin
                local y = elm.y + yMin
                if not sel:contains(x, y) then
                    elm(0x0)
                end
            end

            -- Create new layer and new cel. This
            -- makes three transactions.
            local adjLayer = activeSprite:newLayer()
            adjLayer.name = "Transformed"
            local adjCel = activeSprite:newCel(
                adjLayer, actFrame,
                flatImage, Point(xSel, ySel))
            tinsert(targetCels, adjCel)
        end
    else
        local activeCels = activeSprite.cels
        local activeCelsLen = #activeCels
        local i = 0
        while i < activeCelsLen do i = i + 1
            local activeCel = activeCels[i]
            local celLayer = activeCel.layer
            if isUnlocked(celLayer, activeSprite)
                and (vBkgAll or not celLayer.isBackground)
                and (not celLayer.isReference) then
                tinsert(targetCels, activeCel)
            end
        end
    end

    return targetCels
end

local dlg = Dialog { title = "Transform" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:number {
    id = "xTranslate",
    label = "Vector:",
    text = string.format("%.0f", defaults.xTranslate),
    decimals = 0
}

dlg:number {
    id = "yTranslate",
    text = string.format("%.0f", defaults.yTranslate),
    decimals = 0
}

dlg:newrow { always = false }

dlg:button {
    id = "translateButton",
    text = "&MOVE",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local xtr = args.xTranslate or defaults.xTranslate
        local ytr = args.yTranslate or defaults.yTranslate
        if xtr == 0.0 and ytr == 0.0 then return end

        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false, false)
        local celsLen = #cels

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local oldPos = cel.position
                cel.position = Point(
                    oldPos.x + xtr,
                    oldPos.y - ytr)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "wrapButton",
    text = "&WRAP",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local xtr = args.xTranslate or defaults.xTranslate
        local ytr = args.yTranslate or defaults.yTranslate
        if xtr == 0.0 and ytr == 0.0 then return end

        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, true, false)
        local celsLen = #cels

        local wrap = AseUtilities.wrapImage
        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.image = wrap(cel.image, xtr, ytr)
            end
        end)

        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "tlAlignButton",
    label = "Align:",
    text = "TL",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false, false)
        local celsLen = #cels

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                cels[i].position = Point(0, 0)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "tlAlignButton",
    text = "&T",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false, false)
        local celsLen = #cels

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.position = Point(cel.position.x, 0)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "trAlignButton",
    text = "TR",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false, false)
        local celsLen = #cels
        local wSprite = activeSprite.width

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local w = cel.image.width
                cel.position = Point(wSprite - w, 0)
            end
        end)

        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "lAlignButton",
    text = "&L",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false, false)
        local celsLen = #cels

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.position = Point(0, cel.position.y)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "cAlignButton",
    text = "C&E",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false, false)
        local celsLen = #cels
        local xCtrSprite = activeSprite.width * 0.5
        local yCtrSprite = activeSprite.height * 0.5

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local celImg = cel.image
                local w = celImg.width
                local h = celImg.height
                cel.position = Point(
                    math.floor(0.5 + xCtrSprite - w * 0.5),
                    math.floor(0.5 + yCtrSprite - h * 0.5))
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "rAlignButton",
    text = "&R",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false, false)
        local celsLen = #cels
        local wSprite = activeSprite.width

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.position = Point(
                    wSprite - cel.image.width,
                    cel.position.y)
            end
        end)

        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "blAlignButton",
    text = "BL",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false, false)
        local celsLen = #cels
        local hSprite = activeSprite.height

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local h = cel.image.height
                cel.position = Point(0, hSprite - h)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "bAlignButton",
    text = "&B",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false, false)
        local celsLen = #cels
        local hSprite = activeSprite.height

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.position = Point(
                    cel.position.x,
                    hSprite - cel.image.height)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "brAlignButton",
    text = "BR",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false, false)
        local celsLen = #cels
        local wSprite = activeSprite.width
        local hSprite = activeSprite.height

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local celImg = cel.image
                cel.position = Point(
                    wSprite - celImg.width,
                    hSprite - celImg.height)
            end
        end)

        app.refresh()
    end
}

dlg:separator { id = "rotateSep" }

-- dlg:check {
--     id = "rotBilin",
--     label = "Smooth:",
--     selected = defaults.rotBilin,
--     visible = false
-- }

-- dlg:newrow { always = false }

dlg:slider {
    id = "degrees",
    label = "Degrees:",
    min = 0,
    max = 359,
    value = defaults.degrees,
    -- onrelease = function()
    -- local args = dlg.data
    -- local deg = args.degrees
    -- local nonOrtho = deg ~= 0
    --     and deg ~= 90
    --     and deg ~= 180
    --     and deg ~= 270
    -- dlg:modify { id = "rotBilin", visible = nonOrtho }
    -- end
}

dlg:newrow { always = false }

dlg:button {
    id = "decr30DegButton",
    text = "&-30",
    focus = false,
    onclick = function()
        local args = dlg.data
        local deg = args.degrees or defaults.degrees
        deg = deg - 30
        deg = deg % 360
        dlg:modify { id = "degrees", value = deg }
        -- local nonOrtho = deg ~= 0
        --     and deg ~= 90
        --     and deg ~= 180
        --     and deg ~= 270
        -- dlg:modify { id = "rotBilin", visible = nonOrtho }
    end
}

dlg:button {
    id = "incr30DegButton",
    text = "&+30",
    focus = false,
    onclick = function()
        local args = dlg.data
        local deg = args.degrees or defaults.degrees
        deg = deg + 30
        deg = deg % 360
        dlg:modify { id = "degrees", value = deg }
        -- local nonOrtho = deg ~= 0
        --     and deg ~= 90
        --     and deg ~= 180
        --     and deg ~= 270
        -- dlg:modify { id = "rotBilin", visible = nonOrtho }
    end
}

dlg:button {
    id = "rotateButton",
    text = "R&OTATE",
    focus = true,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local degrees = args.degrees or defaults.degrees
        if degrees == 0 or degrees == 360 then return end

        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false, false)
        local celsLen = #cels

        if degrees == 90 or degrees == 270 or degrees == -90 then
            local rotFunc = AseUtilities.rotateImage90
            if degrees == 270 or degrees == -90 then
                rotFunc = AseUtilities.rotateImage270
            end

            app.transaction(function()
                local i = 0
                while i < celsLen do i = i + 1
                    local cel = cels[i]
                    local srcImg = cel.image
                    local wSrc = srcImg.width
                    local hSrc = srcImg.height
                    local xSrcHalf = wSrc // 2
                    local ySrcHalf = hSrc // 2

                    local celPos = cel.position
                    local xtlSrc = celPos.x
                    local ytlSrc = celPos.y

                    local trgImg, _, _ = rotFunc(srcImg)
                    local wTrg = trgImg.width
                    local hTrg = trgImg.height
                    local xTrgHalf = wTrg // 2
                    local yTrgHalf = hTrg // 2

                    cel.position = Point(
                        xtlSrc + xSrcHalf - xTrgHalf,
                        ytlSrc + ySrcHalf - yTrgHalf)
                    cel.image = trgImg
                end
            end)
        elseif degrees == 180 or degrees == -180 then
            local rot180 = AseUtilities.rotateImage180
            app.transaction(function()
                local i = 0
                while i < celsLen do i = i + 1
                    local cel = cels[i]
                    cel.image = rot180(cel.image)
                end
            end)
        else
            -- Source:
            -- http://polymathprogrammer.com/2010/04/05/
            -- image-rotation-with-bilinear-interpolation-
            -- and-no-clipping/
            --
            -- Altered to not use trig functions within the pixel
            -- loop. Uses vector rotation formula instead. 90, 180,
            -- 270 degree angles are addressed prior to this
            -- condition with pixel array swap.

            local trimAlpha = AseUtilities.trimImageAlpha
            local round = Utilities.round
            local ceil = math.ceil
            local floor = math.floor

            -- Unlike scale, whether to use bilinear or nearest
            -- is not specified by user. So color mode is not
            -- changed to adapt, but rather is inferred from mode.
            local rotBilin = activeSprite.colorMode == ColorMode.RGB
                and defaults.rotBilin

            local rotFunc = function(xSrc, ySrc, wSrc, hSrc, srcImg)
                local xr = round(xSrc)
                local yr = round(ySrc)
                if yr > -1 and yr < hSrc
                    and xr > -1 and xr < wSrc then
                    return srcImg:getPixel(xr, yr)
                end
                return 0x0
            end

            if rotBilin then
                rotFunc = function(xSrc, ySrc, wSrc, hSrc, srcImg)
                    local yf = floor(ySrc)
                    local yc = ceil(ySrc)
                    local xf = floor(xSrc)
                    local xc = ceil(xSrc)

                    local yErr = ySrc - yf
                    local xErr = xSrc - xf

                    local yfInBounds = yf > -1 and yf < hSrc
                    local ycInBounds = yc > -1 and yc < hSrc
                    local xfInBounds = xf > -1 and xf < wSrc
                    local xcInBounds = xc > -1 and xc < wSrc

                    local c00 = 0x0
                    local c10 = 0x0
                    local c11 = 0x0
                    local c01 = 0x0

                    if xfInBounds and yfInBounds then
                        c00 = srcImg:getPixel(xf, yf)
                    end

                    if xcInBounds and yfInBounds then
                        c10 = srcImg:getPixel(xc, yf)
                    end

                    if xcInBounds and ycInBounds then
                        c11 = srcImg:getPixel(xc, yc)
                    end

                    if xfInBounds and ycInBounds then
                        c01 = srcImg:getPixel(xf, yc)
                    end

                    local a0 = 0
                    local b0 = 0
                    local g0 = 0
                    local r0 = 0

                    local a00 = c00 >> 0x18 & 0xff
                    local a10 = c10 >> 0x18 & 0xff
                    if a00 > 0 or a10 > 0 then
                        local b00 = c00 >> 0x10 & 0xff
                        local g00 = c00 >> 0x08 & 0xff
                        local r00 = c00 & 0xff

                        local b10 = c10 >> 0x10 & 0xff
                        local g10 = c10 >> 0x08 & 0xff
                        local r10 = c10 & 0xff

                        r0, g0, b0, a0 = rgbMix(
                            r00, g00, b00, a00,
                            r10, g10, b10, a10, xErr)
                    end

                    local a1 = 0
                    local b1 = 0
                    local g1 = 0
                    local r1 = 0

                    local a01 = c01 >> 0x18 & 0xff
                    local a11 = c11 >> 0x18 & 0xff
                    if a01 > 0 or a11 > 0 then
                        local b01 = c01 >> 0x10 & 0xff
                        local g01 = c01 >> 0x08 & 0xff
                        local r01 = c01 & 0xff

                        local b11 = c11 >> 0x10 & 0xff
                        local g11 = c11 >> 0x08 & 0xff
                        local r11 = c11 & 0xff

                        r1, g1, b1, a1 = rgbMix(
                            r01, g01, b01, a01,
                            r11, g11, b11, a11, xErr)
                    end

                    if a0 > 0 or a1 > 0 then
                        local rt, gt, bt, at = rgbMix(
                            r0, g0, b0, a0,
                            r1, g1, b1, a1, yErr)
                        at = floor(0.5 + at)
                        bt = floor(0.5 + bt)
                        gt = floor(0.5 + gt)
                        rt = floor(0.5 + rt)

                        if at < 0 then at = 0 elseif at > 255 then at = 255 end
                        if bt < 0 then bt = 0 elseif bt > 255 then bt = 255 end
                        if gt < 0 then gt = 0 elseif gt > 255 then gt = 255 end
                        if rt < 0 then rt = 0 elseif rt > 255 then rt = 255 end

                        return (at << 0x18) | (bt << 0x10) | (gt << 0x08) | rt
                    end

                    return 0x0
                end
            end

            app.transaction(function()
                local radians = (360 - degrees) * 0.017453292519943
                local cosa = math.cos(radians)
                local sina = -math.sin(radians)
                local absCosa = math.abs(cosa)
                local absSina = math.abs(sina)

                local i = 0
                while i < celsLen do i = i + 1
                    local cel = cels[i]
                    local srcImg = cel.image
                    local srcSpec = srcImg.spec
                    local wSrc = srcSpec.width
                    local hSrc = srcSpec.height
                    local alphaMask = srcSpec.transparentColor

                    -- Just in case, ceil this instead of floor.
                    local wTrg = ceil(hSrc * absSina + wSrc * absCosa)
                    local hTrg = ceil(hSrc * absCosa + wSrc * absSina)
                    local xSrcCenter = wSrc * 0.5
                    local ySrcCenter = hSrc * 0.5
                    local xTrgCenter = wTrg * 0.5
                    local yTrgCenter = hTrg * 0.5
                    local wDiffHalf = xTrgCenter - xSrcCenter
                    local hDiffHalf = yTrgCenter - ySrcCenter

                    local trgSpec = ImageSpec {
                        width = wTrg,
                        height = hTrg,
                        colorMode = srcSpec.colorMode,
                        transparentColor = alphaMask
                    }
                    trgSpec.colorSpace = srcSpec.colorSpace
                    local trgImg = Image(trgSpec)

                    -- It is very important to iterate through
                    -- target pixels and read from source pixels.
                    -- Iterating through source pixels leads to
                    -- a rotation with gaps in the pixels.
                    local trgPxItr = trgImg:pixels()
                    for elm in trgPxItr do
                        local xSgn = elm.x - xTrgCenter
                        local ySgn = elm.y - yTrgCenter
                        local xRot = cosa * xSgn - sina * ySgn
                        local yRot = cosa * ySgn + sina * xSgn
                        local xSrc = xSrcCenter + xRot
                        local ySrc = ySrcCenter + yRot
                        elm(rotFunc(xSrc, ySrc, wSrc, hSrc, srcImg))
                    end

                    local xTrim = 0
                    local yTrim = 0
                    trgImg, xTrim, yTrim = trimAlpha(trgImg, 0, alphaMask)

                    -- No combo of ceil and floor seem
                    -- ideal to minimize drift.
                    local srcPos = cel.position
                    cel.position = Point(
                        floor(xTrim + srcPos.x - wDiffHalf),
                        floor(yTrim + srcPos.y - hDiffHalf))
                    cel.image = trgImg
                end
            end)
        end

        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "fliphButton",
    text = "&HORIZONTAL",
    label = "Flip:",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, true, true)
        local celsLen = #cels

        local fliph = AseUtilities.flipImageHoriz
        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.image = fliph(cel.image)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "flipvButton",
    text = "&VERTICAL",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, true, true)
        local celsLen = #cels

        local flipv = AseUtilities.flipImageVert
        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                cel.image = flipv(cel.image)
            end
        end)

        app.refresh()
    end
}

dlg:separator { id = "scaleSep" }

dlg:combobox {
    id = "resizeMethod",
    label = "Type:",
    option = defaults.resizeMethod,
    options = resizeMethods
}

dlg:newrow { always = false }

dlg:number {
    id = "pxWidth",
    label = "Pixels:",
    text = string.format("%.0f", defaults.pxWidth),
    decimals = 0,
    visible = defaults.units == "PIXEL"
}

dlg:number {
    id = "pxHeight",
    text = string.format("%.0f", defaults.pxHeight),
    decimals = 0,
    visible = defaults.units == "PIXEL"
}

dlg:number {
    id = "prcWidth",
    label = "Percent:",
    text = string.format("%.2f", defaults.prcWidth),
    decimals = 6,
    visible = defaults.units == "PERCENT"
}

dlg:number {
    id = "prcHeight",
    text = string.format("%.2f", defaults.prcHeight),
    decimals = 6,
    visible = defaults.units == "PERCENT"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "units",
    label = "Units:",
    option = defaults.units,
    options = unitOptions,
    onchange = function()
        local unitType = dlg.data.units
        local ispx = unitType == "PIXEL"
        local ispc = unitType == "PERCENT"
        dlg:modify { id = "pxWidth", visible = ispx }
        dlg:modify { id = "pxHeight", visible = ispx }
        dlg:modify { id = "prcWidth", visible = ispc }
        dlg:modify { id = "prcHeight", visible = ispc }
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "scaleButton",
    text = "&SCALE",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local abs = math.abs
        local max = math.max
        local min = math.min
        local floor = math.floor

        local args = dlg.data
        local target = args.target or defaults.target
        local unitType = args.units or defaults.units
        local resizeMethod = args.resizeMethod or defaults.resizeMethod
        local wPrc = args.prcWidth or defaults.prcWidth
        local hPrc = args.prcHeight or defaults.prcHeight
        local wPxl = args.pxWidth or defaults.pxWidth
        local hPxl = args.pxHeight or defaults.pxHeight

        -- Validate target dimensions.
        wPrc = max(0.000001, abs(wPrc))
        hPrc = max(0.000001, abs(hPrc))
        wPxl = floor(0.5 + max(1, abs(wPxl)))
        hPxl = floor(0.5 + max(1, abs(hPxl)))
        wPrc = wPrc * 0.01
        hPrc = hPrc * 0.01

        -- Convert string checks to booleans for loop.
        local useBicubic = resizeMethod == "BICUBIC"
        local usePercent = unitType == "PERCENT"
        local cels = getTargetCels(activeSprite, target, false, false)
        local celsLen = #cels

        local oldMode = activeSprite.colorMode
        if useBicubic then
            app.command.ChangePixelFormat { format = "rgb" }
        end

        app.transaction(function()
            -- Declare bicubic constants outside the loop.
            local kernel = { 0, 0, 0, 0 }
            local chnlCount = 4
            local kernelSize = 4

            local o = 0
            while o < celsLen do o = o + 1
                local cel = cels[o]
                local srcImg = cel.image
                local srcSpec = srcImg.spec
                local sw = srcSpec.width
                local sh = srcSpec.height

                local dw = wPxl
                local dh = hPxl
                if usePercent then
                    dw = max(1, floor(0.5 + sw * wPrc))
                    dh = max(1, floor(0.5 + sh * hPrc))
                end

                if sw ~= dw or sh ~= dh then
                    local srcpx = {}
                    local srcpxitr = srcImg:pixels()
                    local srcidx = 1
                    for elm in srcpxitr do
                        srcpx[srcidx] = elm()
                        srcidx = srcidx + 1
                    end

                    local tx = sw / dw
                    local ty = sh / dh
                    local clrs = {}

                    local colorMode = srcSpec.colorMode
                    local alphaIdx = srcSpec.transparentColor
                    local colorSpace = srcSpec.colorSpace
                    local trgSpec = ImageSpec {
                        height = dh,
                        width = dw,
                        colorMode = colorMode,
                        transparentColor = alphaIdx }
                    trgSpec.colorSpace = colorSpace
                    local trgImg = Image(trgSpec)
                    local trgpxitr = trgImg:pixels()

                    if useBicubic then
                        kernel[1] = 0
                        kernel[2] = 0
                        kernel[3] = 0
                        kernel[4] = 0

                        local len2 = kernelSize * chnlCount
                        local len3 = dw * len2
                        local len4n1 = dh * len3 - 1

                        local swn1 = sw - 1
                        local shn1 = sh - 1

                        local k = -1
                        while k < len4n1 do k = k + 1
                            local g = k // len3 -- px row index
                            local m = k - g * len3 -- temp
                            local h = m // len2 -- px col index
                            local n = m - h * len2 -- temp
                            local i = n // kernelSize -- krn row index
                            local j = n % kernelSize -- krn col index

                            -- Row.
                            local y = floor(ty * g)
                            local dy = ty * g - y
                            local dysq = dy * dy

                            -- Column.
                            local x = floor(tx * h)
                            local dx = tx * h - x
                            local dxsq = dx * dx

                            -- Clamp kernel to image bounds.
                            local z = max(0, min(shn1, y - 1 + j))
                            local x0 = max(0, min(swn1, x))
                            local x1 = max(0, min(swn1, x - 1))
                            local x2 = max(0, min(swn1, x + 1))
                            local x3 = max(0, min(swn1, x + 2))

                            local zwp1 = 1 + z * sw
                            local i8 = i * 8

                            local a0 = srcpx[zwp1 + x0] >> i8 & 0xff
                            local d0 = srcpx[zwp1 + x1] >> i8 & 0xff
                            local d2 = srcpx[zwp1 + x2] >> i8 & 0xff
                            local d3 = srcpx[zwp1 + x3] >> i8 & 0xff

                            d0 = d0 - a0
                            d2 = d2 - a0
                            d3 = d3 - a0

                            local d36 = 0.66666666666667 * d3
                            local a1 = -0.33333333333333 * d0 + d2 - d36
                            local a2 = 0.5 * (d0 + d2)
                            local a3 = -0.66666666666667 * d0
                                - 0.5 * d2 + d36

                            kernel[1 + j] = max(0, min(255,
                                a0 + floor(a1 * dx
                                    + a2 * dxsq
                                    + a3 * (dx * dxsq))))

                            a0 = kernel[2]
                            d0 = kernel[1] - a0
                            d2 = kernel[3] - a0
                            d3 = kernel[4] - a0

                            d36 = 0.66666666666667 * d3
                            a1 = -0.33333333333333 * d0 + d2 - d36
                            a2 = 0.5 * (d0 + d2)
                            a3 = -0.66666666666667 * d0
                                - 0.5 * d2 + d36

                            clrs[1 + (k // kernelSize)] = max(0, min(255,
                                a0 + floor(a1 * dy
                                    + a2 * dysq
                                    + a3 * (dy * dysq))))
                        end

                        local idx = -3
                        for elm in trgpxitr do
                            idx = idx + 4
                            local hex = clrs[idx]
                                | clrs[idx + 1] << 0x08
                                | clrs[idx + 2] << 0x10
                                | clrs[idx + 3] << 0x18
                            elm(hex)
                        end
                    else
                        -- Default to nearest-neighbor.
                        local idx = -1
                        for elm in trgpxitr do
                            idx = idx + 1
                            local nx = floor((idx % dw) * tx)
                            local ny = floor((idx // dw) * ty)
                            elm(srcpx[1 + ny * sw + nx])
                        end
                    end

                    local celPos = cel.position
                    local xCenter = celPos.x + sw * 0.5
                    local yCenter = celPos.y + sh * 0.5

                    -- app.transaction(function()
                    cel.position = Point(
                        xCenter - dw * 0.5,
                        yCenter - dh * 0.5)
                    cel.image = trgImg
                    -- end)
                end
            end
        end)

        if useBicubic then
            AseUtilities.changePixelFormat(oldMode)
        end
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }

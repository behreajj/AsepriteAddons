dofile("../../support/aseutilities.lua")

local easeMethods = { "BILINEAR", "NEAREST" }
local targets = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local unitOptions = { "PERCENT", "PIXEL" }

local defaults = {
    target = "ACTIVE",
    xTranslate = 0.0,
    yTranslate = 0.0,
    easeMethod = "NEAREST",
    degrees = 0,
    pxWidth = 64,
    pxHeight = 64,
    prcWidth = 100,
    prcHeight = 100,
    units = "PERCENT"
}

local function rgbMix(
    rOrig, gOrig, bOrig, aOrig,
    rDest, gDest, bDest, aDest, t)

    if t <= 0.0 then return rOrig, gOrig, bOrig, aOrig end
    if t >= 1.0 then return rDest, gDest, bDest, aDest end

    local u = 1.0 - t
    local aMix = u * aOrig + t * aDest
    if aMix <= 0.0 then return 0.0, 0.0, 0.0, 0.0 end

    -- Origin and destination colors have been
    -- checked for zero alpha before this function
    -- is called.
    --
    -- Premul and unpremul have to be done
    -- for both horizontal and vertical mixes.
    local ro = rOrig
    local go = gOrig
    local bo = bOrig
    if aOrig < 255 then
        local ao01 = aOrig * 0.003921568627451
        ro = rOrig * ao01
        go = gOrig * ao01
        bo = bOrig * ao01
    end

    local rd = rDest
    local gd = gDest
    local bd = bDest
    if aDest < 255 then
        local ad01 = aDest * 0.003921568627451
        rd = rDest * ad01
        gd = gDest * ad01
        bd = bDest * ad01
    end

    local rMix = u * ro + t * rd
    local gMix = u * go + t * gd
    local bMix = u * bo + t * bd

    if aMix < 255.0 then
        local aInverse = 255.0 / aMix
        rMix = rMix * aInverse
        gMix = gMix * aInverse
        bMix = bMix * aInverse
    end

    return rMix, gMix, bMix, aMix
end

local function filterBilin(xSrc, ySrc, wSrc, hSrc, srcImg)
    local yf = math.floor(ySrc)
    local yc = math.ceil(ySrc)
    local xf = math.floor(xSrc)
    local xc = math.ceil(xSrc)

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

    -- The trim alpha results are better when
    -- alpha zero check is done here.
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

    if a0 > 0.0 or a1 > 0.0 then
        local rt, gt, bt, at = rgbMix(
            r0, g0, b0, a0,
            r1, g1, b1, a1, yErr)

        at = math.floor(0.5 + at)
        bt = math.floor(0.5 + bt)
        gt = math.floor(0.5 + gt)
        rt = math.floor(0.5 + rt)

        -- Is it necessary to check for negative values here?
        if at > 255 then at = 255 end
        if bt > 255 then bt = 255 end
        if gt > 255 then gt = 255 end
        if rt > 255 then rt = 255 end

        return (at << 0x18) | (bt << 0x10) | (gt << 0x08) | rt
    end
    return 0x0
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

                -- Treat background layers differently for active?
                -- if (not vBkgAll) and activeLayer.isBackground then
                --     app.command.LayerFromBackground()
                --     app.command.Refresh()
                -- end

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

dlg:combobox {
    id = "easeMethod",
    label = "Easing:",
    option = defaults.easeMethod,
    options = easeMethods
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

dlg:slider {
    id = "degrees",
    label = "Degrees:",
    min = 0,
    max = 359,
    value = defaults.degrees,
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
    end
}

dlg:button {
    id = "rotateButton",
    text = "R&OTATE",
    focus = true,
    onclick = function()
        -- Early returns.
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        -- Unpack arguments.
        local args = dlg.data
        local degrees = args.degrees or defaults.degrees
        if degrees == 0 then return end

        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false, false)
        local celsLen = #cels

        if degrees == 90 or degrees == 270 then
            local rotFunc = AseUtilities.rotateImage90
            if degrees == 270 then
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
        elseif degrees == 180 then
            local rot180 = AseUtilities.rotateImage180
            app.transaction(function()
                local i = 0
                while i < celsLen do i = i + 1
                    local cel = cels[i]
                    cel.image = rot180(cel.image)
                end
            end)
        else
            -- Cache methods.
            local trimAlpha = AseUtilities.trimImageAlpha
            local round = Utilities.round
            local ceil = math.ceil

            -- Determine bilinear vs. nearest.
            local easeMethod = args.easeMethod or defaults.easeMethod
            local useBilinear = easeMethod == "BILINEAR"
            local oldMode = activeSprite.colorMode
            local rotFunc = nil
            if useBilinear then
                app.command.ChangePixelFormat { format = "rgb" }
                rotFunc = filterBilin
            else
                rotFunc = function(xSrc, ySrc, wSrc, hSrc, srcImg)
                    local xr = Utilities.round(xSrc)
                    local yr = Utilities.round(ySrc)
                    if yr > -1 and yr < hSrc
                        and xr > -1 and xr < wSrc then
                        return srcImg:getPixel(xr, yr)
                    end
                    return 0x0
                end
            end

            -- Unpack angle.
            local radians = (360 - degrees) * 0.017453292519943
            local cosa = math.cos(radians)
            local sina = -math.sin(radians)
            local absCosa = math.abs(cosa)
            local absSina = math.abs(sina)

            -- Adapted from:
            -- http://polymathprogrammer.com/2010/04/05/
            -- image-rotation-with-bilinear-interpolation-
            -- and-no-clipping/

            app.transaction(function()
                local i = 0
                while i < celsLen do i = i + 1
                    local cel = cels[i]
                    local srcImg = cel.image
                    if not srcImg:isEmpty() then
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

                        -- The goal with this calculation is to try
                        -- to minimize drift in the cel's position.
                        local wDiffHalf = round((wTrg - wSrc) * 0.5)
                        local hDiffHalf = round((hTrg - hSrc) * 0.5)

                        local trgSpec = ImageSpec {
                            width = wTrg,
                            height = hTrg,
                            colorMode = srcSpec.colorMode,
                            transparentColor = alphaMask
                        }
                        trgSpec.colorSpace = srcSpec.colorSpace
                        local trgImg = Image(trgSpec)

                        -- It is important to loop through target
                        -- pixels and read from source pixels. Looping
                        -- through source pixels leads to a rotation
                        -- with gaps between pixels.
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

                        local srcPos = cel.position
                        cel.position = Point(
                            xTrim + srcPos.x - wDiffHalf,
                            yTrim + srcPos.y - hDiffHalf)
                        cel.image = trgImg
                    end
                end
            end)

            if useBilinear then
                AseUtilities.changePixelFormat(oldMode)
            end
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

dlg:number {
    id = "pxWidth",
    label = "Pixels:",
    text = string.format("%d", app.preferences.new_file.width),
    decimals = 0,
    visible = defaults.units == "PIXEL"
}

dlg:number {
    id = "pxHeight",
    text = string.format("%d", app.preferences.new_file.height),
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
    id = "scale1_2xButton",
    text = "&1/2X",
    focus = false,
    onclick = function()
        local args = dlg.data

        local wpx1x = args.pxWidth * 0.5
        local hpx1x = args.pxHeight * 0.5
        local wprc1x = args.prcWidth * 0.5
        local hprc1x = args.prcHeight * 0.5

        if math.abs(wpx1x) < 1 then wpx1x = 1 end
        if math.abs(hpx1x) < 1 then hpx1x = 1 end
        if math.abs(wprc1x) < 0.000001 then wprc1x = 100 end
        if math.abs(hprc1x) < 0.000001 then hprc1x = 100 end

        dlg:modify { id = "pxWidth", text = string.format("%d", wpx1x) }
        dlg:modify { id = "pxHeight", text = string.format("%d", hpx1x) }
        dlg:modify { id = "prcWidth", text = string.format("%.2f", wprc1x) }
        dlg:modify { id = "prcHeight", text = string.format("%.2f", hprc1x) }
    end
}

dlg:button {
    id = "scale2xButton",
    text = "&2X",
    focus = false,
    onclick = function()
        local args = dlg.data

        local wpx2x = args.pxWidth * 2
        local hpx2x = args.pxHeight * 2
        local wprc2x = args.prcWidth * 2
        local hprc2x = args.prcHeight * 2

        if math.abs(wpx2x) < 1 then wpx2x = 1 end
        if math.abs(hpx2x) < 1 then hpx2x = 1 end
        if math.abs(wprc2x) < 0.000001 then wprc2x = 100 end
        if math.abs(hprc2x) < 0.000001 then hprc2x = 100 end

        dlg:modify { id = "pxWidth", text = string.format("%d", wpx2x) }
        dlg:modify { id = "pxHeight", text = string.format("%d", hpx2x) }
        dlg:modify { id = "prcWidth", text = string.format("%.2f", wprc2x) }
        dlg:modify { id = "prcHeight", text = string.format("%.2f", hprc2x) }
    end
}

dlg:button {
    id = "scaleButton",
    text = "&SCALE",
    focus = false,
    onclick = function()
        -- Early returns.
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        -- Cache methods.
        local abs = math.abs
        local max = math.max
        local floor = math.floor

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target
        local unitType = args.units or defaults.units
        local easeMethod = args.easeMethod or defaults.easeMethod
        local wPrc = args.prcWidth or defaults.prcWidth
        local hPrc = args.prcHeight or defaults.prcHeight
        local wPxl = args.pxWidth or activeSprite.width
        local hPxl = args.pxHeight or activeSprite.height

        -- Validate target dimensions.
        wPxl = floor(0.5 + abs(wPxl))
        hPxl = floor(0.5 + abs(hPxl))
        wPrc = max(0.000001, abs(wPrc))
        hPrc = max(0.000001, abs(hPrc))
        wPrc = wPrc * 0.01
        hPrc = hPrc * 0.01

        -- Convert string checks to booleans for loop.
        local useBilinear = easeMethod == "BILINEAR"
        local usePercent = unitType == "PERCENT"
        if (not usePercent) and (wPxl < 1 or hPxl < 1) then return end
        local cels = getTargetCels(activeSprite, target, false, false)
        local celsLen = #cels

        local oldMode = activeSprite.colorMode
        if useBilinear then
            app.command.ChangePixelFormat { format = "rgb" }
        end

        app.transaction(function()
            local o = 0
            while o < celsLen do o = o + 1
                local cel = cels[o]
                local srcImg = cel.image
                if not srcImg:isEmpty() then
                    local srcSpec = srcImg.spec
                    local wSrc = srcSpec.width
                    local hSrc = srcSpec.height

                    local wTrg = wPxl
                    local hTrg = hPxl
                    if usePercent then
                        wTrg = max(1, floor(0.5 + wSrc * wPrc))
                        hTrg = max(1, floor(0.5 + hSrc * hPrc))
                    end

                    if wSrc ~= wTrg or hSrc ~= hTrg then
                        local srcpx = {}
                        local srcpxitr = srcImg:pixels()
                        local srcidx = 0
                        for elm in srcpxitr do
                            srcidx = srcidx + 1
                            srcpx[srcidx] = elm()
                        end

                        local tx = wSrc / wTrg
                        local ty = hSrc / hTrg

                        local colorMode = srcSpec.colorMode
                        local alphaIdx = srcSpec.transparentColor
                        local colorSpace = srcSpec.colorSpace
                        local trgSpec = ImageSpec {
                            height = hTrg,
                            width = wTrg,
                            colorMode = colorMode,
                            transparentColor = alphaIdx }
                        trgSpec.colorSpace = colorSpace
                        local trgImg = Image(trgSpec)
                        local trgpxitr = trgImg:pixels()

                        if useBilinear then
                            for elm in trgpxitr do
                                local xSrc = elm.x * tx
                                local ySrc = elm.y * ty
                                elm(filterBilin(xSrc, ySrc, wSrc, hSrc, srcImg))
                            end
                        else
                            -- Default to nearest-neighbor.
                            for elm in trgpxitr do
                                elm(srcpx[1 + floor(elm.y * ty) * wSrc
                                    + floor(elm.x * tx)])
                            end
                        end

                        local celPos = cel.position
                        local xCenter = celPos.x + wSrc * 0.5
                        local yCenter = celPos.y + hSrc * 0.5

                        cel.position = Point(
                            xCenter - wTrg * 0.5,
                            yCenter - hTrg * 0.5)
                        cel.image = trgImg
                    end
                end
            end
        end)

        if useBilinear then
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

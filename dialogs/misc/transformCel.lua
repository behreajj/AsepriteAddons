dofile("../../support/aseutilities.lua")

local easeMethods = { "BILINEAR", "NEAREST" }
local targets = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local unitOptions = { "PERCENT", "PIXEL" }

local defaults = {
    target = "ACTIVE",
    xTranslate = 0.0,
    yTranslate = 0.0,
    easeMethod = "NEAREST",
    degrees = 90,
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

local function filterNear(
 xSrc, ySrc, wSrc, hSrc,
 srcImg, alphaMask)

    local xr = Utilities.round(xSrc)
    local yr = Utilities.round(ySrc)
    if yr > -1 and yr < hSrc
        and xr > -1 and xr < wSrc then
        return srcImg:getPixel(xr, yr)
    end
    return alphaMask
end

local function filterBilin(
    xSrc, ySrc, wSrc, hSrc,
    srcImg, alphaMask)

    local yf = math.floor(ySrc)
    local yc = math.ceil(ySrc)
    local xf = math.floor(xSrc)
    local xc = math.ceil(xSrc)

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
    local xErr = xSrc - xf
    local a00 = c00 >> 0x18 & 0xff
    local a10 = c10 >> 0x18 & 0xff
    if a00 > 0 or a10 > 0 then
        r0, g0, b0, a0 = rgbMix(
            c00 & 0xff, c00 >> 0x08 & 0xff,
            c00 >> 0x10 & 0xff, a00,
            c10 & 0xff, c10 >> 0x08 & 0xff,
            c10 >> 0x10 & 0xff, a10, xErr)
    end

    local a1 = 0
    local b1 = 0
    local g1 = 0
    local r1 = 0

    local a01 = c01 >> 0x18 & 0xff
    local a11 = c11 >> 0x18 & 0xff
    if a01 > 0 or a11 > 0 then
        r1, g1, b1, a1 = rgbMix(
            c01 & 0xff, c01 >> 0x08 & 0xff,
            c01 >> 0x10 & 0xff, a01,
            c11 & 0xff, c11 >> 0x08 & 0xff,
            c11 >> 0x10 & 0xff, a11, xErr)
    end

    if a0 > 0.0 or a1 > 0.0 then
        local rt, gt, bt, at = rgbMix(
            r0, g0, b0, a0,
            r1, g1, b1, a1, ySrc - yf)

        at = math.floor(0.5 + at)
        bt = math.floor(0.5 + bt)
        gt = math.floor(0.5 + gt)
        rt = math.floor(0.5 + rt)

        -- Is it necessary to check for negative values here?
        if at > 255 then at = 255 end
        if bt > 255 then bt = 255 end
        if gt > 255 then gt = 255 end
        if rt > 255 then rt = 255 end

        return at << 0x18 | bt << 0x10 | gt << 0x08 | rt
    end
    return alphaMask
end

local function getTargetCels(activeSprite, targetPreset, bkgAllow)

    -- Unrelated issues with Aseprite can raise the need
    -- to roll back to an older version. For that reason,
    -- layer.isReference is no longer supported.

    local targetCels = {}
    local tinsert = table.insert
    local isUnlocked = AseUtilities.isEditableHierarchy

    -- TODO: Do not impact tile map layers!
    local vBkgAll = bkgAllow or false
    if targetPreset == "ACTIVE" then
        local activeLayer = app.activeLayer
        if activeLayer then
            if isUnlocked(activeLayer, activeSprite)
                and (vBkgAll or not activeLayer.isBackground) then

                -- TODO: What if active is group layer, get leaves?
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
                and (vBkgAll or not celLayer.isBackground) then
                tinsert(targetCels, rangeCel)
            end
        end
    elseif targetPreset == "SELECTION" then
        local sel = AseUtilities.getSelection(activeSprite)
        local selBounds = sel.bounds
        local xSel = selBounds.x
        local ySel = selBounds.y
        local activeSpec = activeSprite.spec
        local actFrame = app.activeFrame
        local alphaMask = activeSpec.transparentColor

        -- Create a subset of flattened sprite.
        local flatSpec = ImageSpec {
            width = math.max(1, selBounds.width),
            height = math.max(1, selBounds.height),
            colorMode = activeSpec.colorMode,
            transparentColor = alphaMask
        }
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
                elm(alphaMask)
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
    else
        local activeCels = activeSprite.cels
        local activeCelsLen = #activeCels
        local i = 0
        while i < activeCelsLen do i = i + 1
            local activeCel = activeCels[i]
            local celLayer = activeCel.layer
            if isUnlocked(celLayer, activeSprite)
                and (vBkgAll or not celLayer.isBackground) then
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
    label = "Pixels:",
    option = defaults.easeMethod,
    options = easeMethods
}

dlg:newrow { always = false }

dlg:number {
    id = "xTranslate",
    label = "Vector:",
    text = string.format("%d", defaults.xTranslate),
    decimals = 0
}

dlg:number {
    id = "yTranslate",
    text = string.format("%d", defaults.yTranslate),
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
        local cels = getTargetCels(activeSprite, target, false)
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
        local cels = getTargetCels(activeSprite, target, true)
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
        local cels = getTargetCels(activeSprite, target, false)
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
    id = "tAlignButton",
    text = "&T",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false)
        local celsLen = #cels
        local xCtrSprite = activeSprite.width * 0.5

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local posOld = cel.position
                local xNew = posOld.x
                local yNew = 0
                if posOld.y == yNew then
                    local w = cel.image.width
                    xNew = math.floor(0.5 + xCtrSprite - w * 0.5)
                end
                cel.position = Point(xNew, yNew)
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
        local cels = getTargetCels(activeSprite, target, false)
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
        local cels = getTargetCels(activeSprite, target, false)
        local celsLen = #cels
        local yCtrSprite = activeSprite.height * 0.5

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local posOld = cel.position
                local xNew = 0
                local yNew = posOld.y
                if posOld.x == xNew then
                    local h = cel.image.height
                    yNew = math.floor(0.5 + yCtrSprite - h * 0.5)
                end
                cel.position = Point(xNew, yNew)
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
        local cels = getTargetCels(activeSprite, target, false)
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
        local cels = getTargetCels(activeSprite, target, false)
        local celsLen = #cels
        local wSprite = activeSprite.width
        local yCtrSprite = activeSprite.height * 0.5

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local celImg = cel.image
                local posOld = cel.position
                local xNew = wSprite - celImg.width
                local yNew = posOld.y
                if posOld.x == xNew then
                    local h = cel.image.height
                    yNew = math.floor(0.5 + yCtrSprite - h * 0.5)
                end
                cel.position = Point(xNew, yNew)
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
        local cels = getTargetCels(activeSprite, target, false)
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
        local cels = getTargetCels(activeSprite, target, false)
        local celsLen = #cels
        local xCtrSprite = activeSprite.width * 0.5
        local hSprite = activeSprite.height

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local celImg = cel.image
                local posOld = cel.position
                local xNew = posOld.x
                local yNew = hSprite - celImg.height
                if posOld.y == yNew then
                    local w = celImg.width
                    xNew = math.floor(0.5 + xCtrSprite - w * 0.5)
                end
                cel.position = Point(xNew, yNew)
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
        local cels = getTargetCels(activeSprite, target, false)
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
    max = 360,
    value = defaults.degrees,
}

dlg:newrow { always = false }

dlg:button {
    id = "skewxButton",
    text = "SKEW &X",
    focus = false,
    onclick = function()
        -- Early returns.
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        -- Unpack arguments.
        local args = dlg.data
        local degrees = args.degrees or defaults.degrees
        if degrees == 0 or degrees == 180 or degrees == 360
            or degrees == 90 or degrees == 270 then return end

        -- Determine bilinear vs. nearest.
        local easeMethod = args.easeMethod or defaults.easeMethod
        local useBilinear = easeMethod == "BILINEAR"
        local oldMode = activeSprite.colorMode
        local filter = nil
        if useBilinear then
            app.command.ChangePixelFormat { format = "rgb" }
            filter = filterBilin
        else
            filter = filterNear
        end

        -- Cache methods.
        local trimAlpha = AseUtilities.trimImageAlpha
        local round = Utilities.round
        local ceil = math.ceil

        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false)
        local celsLen = #cels

        local query = AseUtilities.DIMETRIC_ANGLES[degrees]
        local radians = degrees * 0.017453292519943
        if query then radians = query end
        local tana = math.tan(radians)
        local absTan = math.abs(tana)

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

                    local wTrg = ceil(wSrc + absTan * hSrc)
                    local yCenter = hSrc * 0.5
                    local xDiff = (wSrc - wTrg) * 0.5
                    local wDiffHalf = round((wTrg - wSrc) * 0.5)

                    local trgSpec = ImageSpec {
                        width = wTrg, height = hSrc,
                        colorMode = srcSpec.colorMode,
                        transparentColor = alphaMask
                    }
                    trgSpec.colorSpace = srcSpec.colorSpace
                    local trgImg = Image(trgSpec)

                    local trgPxItr = trgImg:pixels()
                    for elm in trgPxItr do
                        elm(filter(
                            xDiff + elm.x + tana * (elm.y - yCenter),
                            elm.y, wSrc, hSrc, srcImg, alphaMask))
                    end

                    local xTrim = 0
                    local yTrim = 0
                    trgImg, xTrim, yTrim = trimAlpha(trgImg, 0, alphaMask)

                    local srcPos = cel.position
                    cel.position = Point(
                        xTrim + srcPos.x - wDiffHalf,
                        yTrim + srcPos.y)
                    cel.image = trgImg
                end
            end
        end)

        if useBilinear then
            AseUtilities.changePixelFormat(oldMode)
        end
        app.refresh()
    end
}

dlg:button {
    id = "skewyButton",
    text = "SKEW &Y",
    focus = false,
    onclick = function()
        -- Early returns.
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        -- Unpack arguments.
        local args = dlg.data
        local degrees = args.degrees or defaults.degrees
        if degrees == 0 or degrees == 180 or degrees == 360
            or degrees == 90 or degrees == 270 then return end

        -- Determine bilinear vs. nearest.
        local easeMethod = args.easeMethod or defaults.easeMethod
        local useBilinear = easeMethod == "BILINEAR"
        local oldMode = activeSprite.colorMode
        local filter = nil
        if useBilinear then
            app.command.ChangePixelFormat { format = "rgb" }
            filter = filterBilin
        else
            filter = filterNear
        end

        -- Cache methods.
        local trimAlpha = AseUtilities.trimImageAlpha
        local round = Utilities.round
        local ceil = math.ceil

        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false)
        local celsLen = #cels

        local query = AseUtilities.DIMETRIC_ANGLES[degrees]
        local radians = degrees * 0.017453292519943
        if query then radians = query end
        local tana = math.tan(radians)
        local absTan = math.abs(tana)

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

                    local hTrg = ceil(hSrc + absTan * wSrc)
                    local xTrgCenter = wSrc * 0.5
                    local yDiff = (hSrc - hTrg) * 0.5
                    local hDiffHalf = round((hTrg - hSrc) * 0.5)

                    local trgSpec = ImageSpec {
                        width = wSrc, height = hTrg,
                        colorMode = srcSpec.colorMode,
                        transparentColor = alphaMask
                    }
                    trgSpec.colorSpace = srcSpec.colorSpace
                    local trgImg = Image(trgSpec)

                    local trgPxItr = trgImg:pixels()
                    for elm in trgPxItr do
                        elm(filter(elm.x,
                            yDiff + elm.y + tana * (elm.x - xTrgCenter),
                            wSrc, hSrc, srcImg, alphaMask))
                    end

                    local xTrim = 0
                    local yTrim = 0
                    trgImg, xTrim, yTrim = trimAlpha(trgImg, 0, alphaMask)

                    local srcPos = cel.position
                    cel.position = Point(
                        xTrim + srcPos.x,
                        yTrim + srcPos.y - hDiffHalf)
                    cel.image = trgImg
                end
            end
        end)

        if useBilinear then
            AseUtilities.changePixelFormat(oldMode)
        end
        app.refresh()
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
        if degrees == 0 or degrees == 360 then return end

        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false)
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
            local filter = nil
            if useBilinear then
                app.command.ChangePixelFormat { format = "rgb" }
                filter = filterBilin
            else
                filter = filterNear
            end

            -- Unpack angle.
            degrees = 360 - degrees
            local query = AseUtilities.DIMETRIC_ANGLES[degrees]
            local radians = degrees * 0.017453292519943
            if query then radians = query end

            -- Avoid trigonmetric functions in while loop below.
            -- Cache sine and cosine here, then use formula for
            -- vector rotation.
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

                        -- Try to minimize drift in the cel's position.
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

                        -- Loop through target pixels and read from
                        -- source pixels. Looping through source pixels
                        -- results in gaps between pixels.
                        local trgPxItr = trgImg:pixels()
                        for elm in trgPxItr do
                            local xSgn = elm.x - xTrgCenter
                            local ySgn = elm.y - yTrgCenter
                            local xRot = cosa * xSgn - sina * ySgn
                            local yRot = cosa * ySgn + sina * xSgn
                            local xSrc = xSrcCenter + xRot
                            local ySrc = ySrcCenter + yRot
                            elm(filter(xSrc, ySrc, wSrc, hSrc,
                                srcImg, alphaMask))
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
    id = "fliphButton",
    text = "FLIP &H",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, true)
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
    text = "FLIP &V",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, true)
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
        local cels = getTargetCels(activeSprite, target, false)
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
                        -- Right-bottom edges were clipped
                        -- with wSrc / wTrg and hSrc / hTrg .
                        local tx = (wSrc - 1.0) / (wTrg - 1.0)
                        local ty = (hSrc - 1.0) / (hTrg - 1.0)

                        local colorMode = srcSpec.colorMode
                        local alphaMask = srcSpec.transparentColor
                        local colorSpace = srcSpec.colorSpace
                        local trgSpec = ImageSpec {
                            width = wTrg, height = hTrg,
                            colorMode = colorMode,
                            transparentColor = alphaMask
                        }
                        trgSpec.colorSpace = colorSpace
                        local trgImg = Image(trgSpec)
                        local trgpxitr = trgImg:pixels()

                        if useBilinear then
                            for elm in trgpxitr do
                                elm(filterBilin(
                                    elm.x * tx, elm.y * ty, wSrc, hSrc,
                                    srcImg, alphaMask))
                            end
                        else
                            for elm in trgpxitr do
                                elm(filterNear(
                                    elm.x * tx, elm.y * ty, wSrc, hSrc,
                                    srcImg, alphaMask))
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
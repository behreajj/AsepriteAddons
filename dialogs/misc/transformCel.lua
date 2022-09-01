dofile("../../support/aseutilities.lua")

local easeMethods = { "BILINEAR", "NEAREST" }
local targets = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local unitOptions = { "PERCENT", "PIXEL" }

local defaults = {
    target = "RANGE",
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

local function appendLeaves(layer, array, bkgAllow, checkTilemaps)
    if layer.isGroup then
        local childLayers = layer.layers
        local lenChildLayers = #childLayers
        local i = 0
        while i < lenChildLayers do
            i = i + 1
            local childLayer = childLayers[i]
            appendLeaves(childLayer, array)
        end
    elseif (bkgAllow or not layer.isBackground) then
        local isTilemap = false
        if checkTilemaps then
            isTilemap = layer.isTilemap
        end
        if not isTilemap then
            table.insert(array, layer)
        end
    end
end

local function getTargetCels(activeSprite, targetPreset, bkgAllow)

    -- Unrelated issues with Aseprite can raise the need
    -- to roll back to an older version. For that reason,
    -- layer.isReference is no longer supported.

    local version = app.version
    local checkTilemaps = version.major >= 1
        and version.minor >= 3

    local lenTrgCels = 0
    local trgCels = {}

    local vBkgAlw = bkgAllow or false
    if targetPreset == "ALL" then

        -- Linked cels occur multiple times in the sprite.cels
        -- Can be fixed by changing function call cels()
        -- to uniqueCels() at this line in the source:
        -- https://github.com/aseprite/aseprite/blob/main/
        -- src/app/script/cels_class.cpp#L90
        local leaves = {}
        local layers = activeSprite.layers
        local lenLayers = #layers
        local h = 0
        while h < lenLayers do h = h + 1
            local layer = layers[h]
            if layer.isEditable then
                appendLeaves(layer, leaves,
                    vBkgAlw, checkTilemaps)
            end
        end

        -- Ranges accept frame numbers, not frame objects
        -- to their frames setter.
        local frIdcs = {}
        local lenFrames = #activeSprite.frames
        local i = 0
        while i < lenFrames do i = i + 1
            frIdcs[i] = i
        end

        -- If you don't care about filtering layers,
        -- a shortcut: assign only to appRange.frames.
        local appRange = app.range
        appRange.layers = leaves
        appRange.frames = frIdcs

        -- Editability has already been determined
        -- by layers loop above.
        local imgsRange = appRange.images
        local lenImgsRange = #imgsRange
        local j = 0
        while j < lenImgsRange do j = j + 1
            lenTrgCels = lenTrgCels + 1
            trgCels[lenTrgCels] = imgsRange[j].cel
        end

        appRange:clear()

    elseif targetPreset == "RANGE" then

        -- editableImages acquire unique cels.
        local appRange = app.range
        local imgsRange = appRange.editableImages
        local lenImgsRange = #imgsRange
        local i = 0
        while i < lenImgsRange do i = i + 1
            local image = imgsRange[i]
            local cel = image.cel
            local layer = cel.layer
            local isTilemap = false
            if checkTilemaps then
                isTilemap = layer.isTilemap
            end
            if (vBkgAlw or not layer.isBackground)
                and not isTilemap then
                lenTrgCels = lenTrgCels + 1
                trgCels[lenTrgCels] = cel
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
        local flatPxItr = flatImage:pixels()
        for elm in flatPxItr do
            local x = elm.x + xSel
            local y = elm.y + ySel
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
        lenTrgCels = lenTrgCels + 1
        trgCels[lenTrgCels] = adjCel

    else
        -- If active is group, get children.
        local activeLayer = app.activeLayer
        local activeFrame = app.activeFrame
        if activeLayer and activeFrame then
            if AseUtilities.isEditableHierarchy(
                activeLayer, activeSprite) then
                local leaves = {}
                appendLeaves(activeLayer, leaves,
                    vBkgAlw, checkTilemaps)
                local lenLeaves = #leaves
                local i = 0
                while i < lenLeaves do i = i + 1
                    local leaf = leaves[i]
                    local cel = leaf:cel(activeFrame)
                    if cel then
                        lenTrgCels = lenTrgCels + 1
                        trgCels[lenTrgCels] = cel
                    end
                end
            end
        end
    end

    return trgCels
end

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

    local a0 = 0.0
    local b0 = 0.0
    local g0 = 0.0
    local r0 = 0.0

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

    local a1 = 0.0
    local b1 = 0.0
    local g1 = 0.0
    local r1 = 0.0

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
    label = "Sample:",
    option = defaults.easeMethod,
    options = easeMethods
}

dlg:separator { id = "translateSep" }

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
        local dx = args.xTranslate or defaults.xTranslate
        local dy = args.yTranslate or defaults.yTranslate
        if dx == 0.0 and dy == 0.0 then return end

        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false)
        local celsLen = #cels

        local docPrefs = app.preferences.document(activeSprite)
        local snap = docPrefs.grid.snap
        if snap then
            local grid = activeSprite.gridBounds
            local xGrOff = grid.x
            local yGrOff = grid.y
            local xGrScl = grid.width
            local yGrScl = grid.height
            local dxnz = dx ~= 0.0
            local dynz = dy ~= 0.0
            local round = Utilities.round
            app.transaction(function()
                local i = 0
                while i < celsLen do i = i + 1
                    local cel = cels[i]
                    local op = cel.position
                    local xn = op.x
                    local yn = op.y
                    if dxnz then
                        local xGrid = round((xn - xGrOff) / xGrScl)
                        xn = xGrOff + (xGrid + dx) * xGrScl
                    end
                    if dynz then
                        local yGrid = round((yn - yGrOff) / yGrScl)
                        yn = yGrOff + (yGrid - dy) * yGrScl
                    end
                    cel.position = Point(xn, yn)
                end
            end)
        else
            app.transaction(function()
                local i = 0
                while i < celsLen do i = i + 1
                    local cel = cels[i]
                    local op = cel.position
                    cel.position = Point(op.x + dx, op.y - dy)
                end
            end)
        end

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
        local dx = args.xTranslate or defaults.xTranslate
        local dy = args.yTranslate or defaults.yTranslate
        if dx == 0.0 and dy == 0.0 then return end

        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, true)
        local celsLen = #cels

        local trimAlpha = AseUtilities.trimImageAlpha
        local wrap = AseUtilities.wrapImage
        local spriteSpec = activeSprite.spec
        local alphaMask = spriteSpec.transparentColor

        local docPrefs = app.preferences.document(activeSprite)
        local tiledMode = docPrefs.tiled.mode
        if tiledMode == 3 then
            -- Tiling on both axes.
            app.transaction(function()
                local i = 0
                while i < celsLen do i = i + 1
                    local cel = cels[i]
                    local blit = Image(spriteSpec)
                    blit:drawImage(cel.image, cel.position)
                    local imgTrg = wrap(blit, dx, dy)
                    local xTrg = 0
                    local yTrg = 0
                    imgTrg, xTrg, yTrg = trimAlpha(imgTrg, 0, alphaMask)
                    cel.image = imgTrg
                    cel.position = Point(xTrg, yTrg)
                end
            end)
        elseif tiledMode == 2 then
            -- Vertical tiling.
            app.transaction(function()
                local i = 0
                while i < celsLen do i = i + 1
                    local cel = cels[i]
                    local blit = Image(spriteSpec)
                    blit:drawImage(cel.image, cel.position)
                    local imgTrg = wrap(blit, 0, dy)
                    local xTrg = 0
                    local yTrg = 0
                    imgTrg, xTrg, yTrg = trimAlpha(imgTrg, 0, alphaMask)
                    cel.image = imgTrg
                    cel.position = Point(xTrg + dx, yTrg)
                end
            end)
        elseif tiledMode == 1 then
            -- Horizontal tiling.
            app.transaction(function()
                local i = 0
                while i < celsLen do i = i + 1
                    local cel = cels[i]
                    local blit = Image(spriteSpec)
                    blit:drawImage(cel.image, cel.position)
                    local imgTrg = wrap(blit, dx, 0)
                    local xTrg = 0
                    local yTrg = 0
                    imgTrg, xTrg, yTrg = trimAlpha(imgTrg, 0, alphaMask)
                    cel.image = imgTrg
                    cel.position = Point(xTrg, yTrg - dy)
                end
            end)
        else
            --No tiling.
            app.transaction(function()
                local i = 0
                while i < celsLen do i = i + 1
                    local cel = cels[i]
                    cel.image = wrap(cel.image, dx, dy)
                end
            end)
        end

        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "tAlignButton",
    label = "Align:",
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
                local op = cel.position
                local xNew = op.x
                local yNew = 0
                if op.y == yNew then
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
                local op = cel.position
                local xNew = 0
                local yNew = op.y
                if op.x == xNew then
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
                local op = cel.position
                local xNew = op.x
                local yNew = hSprite - celImg.height
                if op.y == yNew then
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
                local op = cel.position
                local xNew = wSprite - celImg.width
                local yNew = op.y
                if op.x == xNew then
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
    id = "cAlignButton",
    text = "C&ENTER",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local args = dlg.data
        local target = args.target or defaults.target
        local cels = getTargetCels(activeSprite, target, false)
        local celsLen = #cels
        local xc = activeSprite.width * 0.5
        local yc = activeSprite.height * 0.5
        local floor = math.floor

        app.transaction(function()
            local i = 0
            while i < celsLen do i = i + 1
                local cel = cels[i]
                local celImg = cel.image
                cel.position = Point(
                    floor(0.5 + xc - celImg.width * 0.5),
                    floor(0.5 + yc - celImg.height * 0.5))
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
        local filter = filterNear
        if useBilinear then
            app.command.ChangePixelFormat { format = "rgb" }
            filter = filterBilin
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
        local filter = filterNear
        if useBilinear then
            app.command.ChangePixelFormat { format = "rgb" }
            filter = filterBilin
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
        wPrc = 0.01 * max(0.000001, abs(wPrc))
        hPrc = 0.01 * max(0.000001, abs(hPrc))

        -- Convert string checks to booleans for loop.
        local useBilinear = easeMethod == "BILINEAR"
        local usePercent = unitType == "PERCENT"
        if (not usePercent) and (wPxl < 1 or hPxl < 1) then return end
        local cels = getTargetCels(activeSprite, target, false)
        local celsLen = #cels

        local oldMode = activeSprite.colorMode
        local filter = filterNear
        if useBilinear then
            app.command.ChangePixelFormat { format = "rgb" }
            filter = filterBilin
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

                        for elm in trgpxitr do
                            elm(filter(
                                elm.x * tx, elm.y * ty, wSrc, hSrc,
                                srcImg, alphaMask))
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
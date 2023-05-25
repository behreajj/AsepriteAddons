dofile("../../support/aseutilities.lua")

local easeMethods = { "BILINEAR", "NEAREST" }
local targets = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local unitOptions = { "PERCENT", "PIXEL" }

local defaults = {
    target = "ACTIVE",
    xTranslate = 0,
    yTranslate = 0,
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

local function sampleNear(
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

local function sampleBilinear(
    xSrc, ySrc, wSrc, hSrc,
    srcImg, alphaMask)
    local xf = math.floor(xSrc)
    local yf = math.floor(ySrc)
    local xc = xf + 1
    local yc = yf + 1

    local yfInBounds = yf > -1 and yf < hSrc
    local ycInBounds = yc > -1 and yc < hSrc
    local xfInBounds = xf > -1 and xf < wSrc
    local xcInBounds = xc > -1 and xc < wSrc

    local c00 = 0x0
    local c10 = 0x0
    local c11 = 0x0
    local c01 = 0x0

    if yfInBounds and xfInBounds then
        c00 = srcImg:getPixel(xf, yf)
    end

    if yfInBounds and xcInBounds then
        c10 = srcImg:getPixel(xc, yf)
    end

    if ycInBounds and xcInBounds then
        c11 = srcImg:getPixel(xc, yc)
    end

    if ycInBounds and xfInBounds then
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
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then return end
        local activeLayer = site.layer
        local activeFrame = site.frame

        local args = dlg.data
        -- These are number fields, but their decimal places are zero.
        local dx = args.xTranslate or defaults.xTranslate --[[@as integer]]
        local dy = args.yTranslate or defaults.yTranslate --[[@as integer]]
        if dx == 0.0 and dy == 0.0 then return end

        local target = args.target or defaults.target --[[@as string]]
        local cels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels = #cels

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
            app.transaction("Move Cels Snap", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
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
            app.transaction("Move Cels", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
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
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then return end
        local activeLayer = site.layer
        local activeFrame = site.frame

        local args = dlg.data
        local dx = args.xTranslate
            or defaults.xTranslate --[[@as integer]]
        local dy = args.yTranslate
            or defaults.yTranslate --[[@as integer]]
        if dx == 0.0 and dy == 0.0 then return end

        local target = args.target or defaults.target --[[@as string]]
        local cels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, true)
        local lenCels = #cels

        local trimAlpha = AseUtilities.trimImageAlpha
        local wrap = AseUtilities.wrapImage
        local spriteSpec = activeSprite.spec
        local alphaMask = spriteSpec.transparentColor

        local docPrefs = app.preferences.document(activeSprite)
        local tiledMode = docPrefs.tiled.mode
        if tiledMode == 3 then
            -- Tiling on both axes.
            app.transaction("Wrap Cels", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
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
            app.transaction("Wrap V", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
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
            app.transaction("Wrap H", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
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
            app.transaction("Wrap Cels", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
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
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then return end
        local activeLayer = site.layer
        local activeFrame = site.frame

        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local cels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels = #cels
        local xCtrSprite = activeSprite.width * 0.5

        app.transaction("Align Top", function()
            local i = 0
            while i < lenCels do
                i = i + 1
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
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then return end
        local activeLayer = site.layer
        local activeFrame = site.frame

        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local cels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels = #cels
        local yCtrSprite = activeSprite.height * 0.5

        app.transaction("Align Left", function()
            local i = 0
            while i < lenCels do
                i = i + 1
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
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then return end
        local activeLayer = site.layer
        local activeFrame = site.frame

        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local cels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels = #cels
        local xCtrSprite = activeSprite.width * 0.5
        local hSprite = activeSprite.height

        app.transaction("Align Bottom", function()
            local i = 0
            while i < lenCels do
                i = i + 1
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
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then return end
        local activeLayer = site.layer
        local activeFrame = site.frame

        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local cels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels = #cels
        local wSprite = activeSprite.width
        local yCtrSprite = activeSprite.height * 0.5

        app.transaction("Align Right", function()
            local i = 0
            while i < lenCels do
                i = i + 1
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
    -- Alt+N is used to add new frames, so it shouldn't
    -- be assigned to a dialog button.
    id = "cAlignButton",
    text = "C&ENTER",
    focus = false,
    onclick = function()
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then return end
        local activeLayer = site.layer
        local activeFrame = site.frame

        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local cels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels = #cels
        local xc = activeSprite.width * 0.5
        local yc = activeSprite.height * 0.5
        local floor = math.floor

        app.transaction("Center", function()
            local i = 0
            while i < lenCels do
                i = i + 1
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
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then return end
        local activeLayer = site.layer
        local activeFrame = site.frame

        -- Unpack arguments.
        local args = dlg.data
        local degrees = args.degrees or defaults.degrees
        if degrees == 0 or degrees == 180 or degrees == 360
            or degrees == 90 or degrees == 270 then
            return
        end

        -- Determine bilinear vs. nearest.
        local easeMethod = args.easeMethod or defaults.easeMethod
        local useBilinear = easeMethod == "BILINEAR"
        local oldMode = activeSprite.colorMode
        local sample = sampleNear
        if useBilinear then
            app.command.ChangePixelFormat { format = "rgb" }
            sample = sampleBilinear
        end

        -- Cache methods.
        local trimAlpha = AseUtilities.trimImageAlpha
        local round = Utilities.round
        local ceil = math.ceil

        local target = args.target or defaults.target --[[@as string]]
        local cels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels = #cels

        local query = AseUtilities.DIMETRIC_ANGLES[degrees]
        local radians = degrees * 0.017453292519943
        if query then radians = query end
        local tana = math.tan(radians)
        local absTan = math.abs(tana)

        app.transaction("Skew X", function()
            local i = 0
            while i < lenCels do
                i = i + 1
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
                    for pixel in trgPxItr do
                        pixel(sample(
                            xDiff + pixel.x + tana * (pixel.y - yCenter),
                            pixel.y, wSrc, hSrc, srcImg, alphaMask))
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
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then return end
        local activeLayer = site.layer
        local activeFrame = site.frame

        -- Unpack arguments.
        local args = dlg.data
        local degrees = args.degrees or defaults.degrees
        if degrees == 0 or degrees == 180 or degrees == 360
            or degrees == 90 or degrees == 270 then
            return
        end

        -- Determine bilinear vs. nearest.
        local easeMethod = args.easeMethod or defaults.easeMethod
        local useBilinear = easeMethod == "BILINEAR"
        local oldMode = activeSprite.colorMode
        local sample = sampleNear
        if useBilinear then
            app.command.ChangePixelFormat { format = "rgb" }
            sample = sampleBilinear
        end

        -- Cache methods.
        local trimAlpha = AseUtilities.trimImageAlpha
        local round = Utilities.round
        local ceil = math.ceil

        local target = args.target or defaults.target --[[@as string]]
        local cels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels = #cels

        local query = AseUtilities.DIMETRIC_ANGLES[degrees]
        local radians = degrees * 0.017453292519943
        if query then radians = query end
        local tana = math.tan(radians)
        local absTan = math.abs(tana)

        app.transaction("Skew Y", function()
            local i = 0
            while i < lenCels do
                i = i + 1
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
                    for pixel in trgPxItr do
                        pixel(sample(pixel.x,
                            yDiff + pixel.y + tana * (pixel.x - xTrgCenter),
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
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then return end
        local activeLayer = site.layer
        local activeFrame = site.frame

        -- Unpack arguments.
        local args = dlg.data
        local degrees = args.degrees or defaults.degrees
        if degrees == 0 or degrees == 360 then return end

        local target = args.target or defaults.target --[[@as string]]
        local cels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels = #cels

        if degrees == 90 or degrees == 270 then
            local rotFunc = AseUtilities.rotateImage90
            if degrees == 270 then
                rotFunc = AseUtilities.rotateImage270
            end

            app.transaction("Rotate Cels", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
                    local cel = cels[i]

                    local srcImg = cel.image
                    local xSrcHalf = srcImg.width // 2
                    local ySrcHalf = srcImg.height // 2

                    local trgImg, _, _ = rotFunc(srcImg)
                    cel.image = trgImg

                    -- The target image width and height
                    -- are the source image height and width.
                    local celPos = cel.position
                    cel.position = Point(
                        celPos.x + xSrcHalf - ySrcHalf,
                        celPos.y + ySrcHalf - xSrcHalf)
                end
            end)
        elseif degrees == 180 then
            local rot180 = AseUtilities.rotateImage180
            app.transaction("Rotate Cels", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
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
            local sample = nil
            if useBilinear then
                app.command.ChangePixelFormat { format = "rgb" }
                sample = sampleBilinear
            else
                sample = sampleNear
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

            app.transaction("Rotate Cels", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
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
                        for pixel in trgPxItr do
                            local xSgn = pixel.x - xTrgCenter
                            local ySgn = pixel.y - yTrgCenter
                            local xRot = cosa * xSgn - sina * ySgn
                            local yRot = cosa * ySgn + sina * xSgn
                            local xSrc = xSrcCenter + xRot
                            local ySrc = ySrcCenter + yRot
                            pixel(sample(xSrc, ySrc, wSrc, hSrc,
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
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then return end
        local activeLayer = site.layer
        local activeFrame = site.frame

        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local cels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, true)
        local lenCels = #cels

        local fliph = FlipType.HORIZONTAL
        app.transaction("Flip H", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel = cels[i]
                local flipped = cel.image:clone()
                flipped:flip(fliph)
                cel.image = flipped
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
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then return end
        local activeLayer = site.layer
        local activeFrame = site.frame

        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local cels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, true)
        local lenCels = #cels

        local flipv = FlipType.VERTICAL
        app.transaction("Flip V", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel = cels[i]
                local flipped = cel.image:clone()
                flipped:flip(flipv)
                cel.image = flipped
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
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then return end
        local activeLayer = site.layer
        local activeFrame = site.frame

        -- Cache methods.
        local abs = math.abs
        local max = math.max
        local floor = math.floor

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local unitType = args.units or defaults.units
        local easeMethod = args.easeMethod or defaults.easeMethod

        local usePercent = unitType == "PERCENT"
        local wPrc = args.prcWidth
            or defaults.prcWidth --[[@as number]]
        local hPrc = args.prcHeight
            or defaults.prcHeight --[[@as number]]
        local wPxl = args.pxWidth
            or activeSprite.width --[[@as integer]]
        local hPxl = args.pxHeight
            or activeSprite.height --[[@as integer]]

        wPxl = floor(0.5 + abs(wPxl))
        hPxl = floor(0.5 + abs(hPxl))
        wPrc = 0.01 * abs(wPrc)
        hPrc = 0.01 * abs(hPrc)

        if usePercent then
            if (wPrc < 0.000001 or hPrc < 0.000001)
                or (wPrc == 1.0 and hPrc == 1.0) then
                return
            end
        elseif wPxl < 1 or hPxl < 1 then
            return
        end

        local cels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels = #cels

        local oldMode = activeSprite.colorMode
        local sample = sampleNear
        local useBilinear = easeMethod == "BILINEAR"
        if useBilinear then
            app.command.ChangePixelFormat { format = "rgb" }
            sample = sampleBilinear
        end

        app.transaction("Scale Cels", function()
            local o = 0
            while o < lenCels do
                o = o + 1
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
                        -- using wSrc / wTrg and hSrc / hTrg .
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
                        local trgPxItr = trgImg:pixels()

                        for pixel in trgPxItr do
                            pixel(sample(
                                pixel.x * tx, pixel.y * ty, wSrc, hSrc,
                                srcImg, alphaMask))
                        end

                        local celPos = cel.position
                        local xCenter = celPos.x + wSrc * 0.5
                        local yCenter = celPos.y + hSrc * 0.5

                        cel.position = Point(
                            floor(xCenter - wTrg * 0.5),
                            floor(yCenter - hTrg * 0.5))
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
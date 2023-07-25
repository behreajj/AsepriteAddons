dofile("../../support/aseutilities.lua")

local easeMethods <const> = { "BILINEAR", "NEAREST" }
local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local unitOptions <const> = { "PERCENT", "PIXEL" }

local defaults <const> = {
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

---@param rOrig number
---@param gOrig number
---@param bOrig number
---@param aOrig number
---@param rDest number
---@param gDest number
---@param bDest number
---@param aDest number
---@param t number
---@return number
---@return number
---@return number
---@return number
local function rgbMix(
    rOrig, gOrig, bOrig, aOrig,
    rDest, gDest, bDest, aDest, t)
    if t <= 0.0 then return rOrig, gOrig, bOrig, aOrig end
    if t >= 1.0 then return rDest, gDest, bDest, aDest end

    local u <const> = 1.0 - t
    local aMix <const> = u * aOrig + t * aDest
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
        local ao01 <const> = aOrig * 0.003921568627451
        ro = rOrig * ao01
        go = gOrig * ao01
        bo = bOrig * ao01
    end

    local rd = rDest
    local gd = gDest
    local bd = bDest
    if aDest < 255 then
        local ad01 <const> = aDest * 0.003921568627451
        rd = rDest * ad01
        gd = gDest * ad01
        bd = bDest * ad01
    end

    local rMix = u * ro + t * rd
    local gMix = u * go + t * gd
    local bMix = u * bo + t * bd

    if aMix < 255.0 then
        local aInverse <const> = 255.0 / aMix
        rMix = rMix * aInverse
        gMix = gMix * aInverse
        bMix = bMix * aInverse
    end

    return rMix, gMix, bMix, aMix
end

---@param xSrc number
---@param ySrc number
---@param wSrc integer
---@param hSrc integer
---@param srcImg Image
---@param alphaMask integer
---@return integer
local function sampleNear(
    xSrc, ySrc, wSrc, hSrc,
    srcImg, alphaMask)
    local xr <const> = Utilities.round(xSrc)
    local yr <const> = Utilities.round(ySrc)
    if yr > -1 and yr < hSrc
        and xr > -1 and xr < wSrc then
        return srcImg:getPixel(xr, yr)
    end
    return alphaMask
end

---@param xSrc number
---@param ySrc number
---@param wSrc integer
---@param hSrc integer
---@param srcImg Image
---@param alphaMask integer
---@return integer
local function sampleBilinear(
    xSrc, ySrc, wSrc, hSrc,
    srcImg, alphaMask)
    local xf <const> = math.floor(xSrc)
    local yf <const> = math.floor(ySrc)
    local xc <const> = xf + 1
    local yc <const> = yf + 1

    local yfInBounds <const> = yf > -1 and yf < hSrc
    local ycInBounds <const> = yc > -1 and yc < hSrc
    local xfInBounds <const> = xf > -1 and xf < wSrc
    local xcInBounds <const> = xc > -1 and xc < wSrc

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
    local xErr <const> = xSrc - xf
    local a00 <const> = c00 >> 0x18 & 0xff
    local a10 <const> = c10 >> 0x18 & 0xff
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

    local a01 <const> = c01 >> 0x18 & 0xff
    local a11 <const> = c11 >> 0x18 & 0xff
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

local dlg <const> = Dialog { title = "Transform" }

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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        local activeFrame <const> = site.frame

        local args <const> = dlg.data
        -- These are number fields, but their decimal places are zero.
        local dx <const> = args.xTranslate
            or defaults.xTranslate --[[@as integer]]
        local dy <const> = args.yTranslate
            or defaults.yTranslate --[[@as integer]]
        if dx == 0.0 and dy == 0.0 then return end

        local target <const> = args.target
            or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels = #cels

        local docPrefs <const> = app.preferences.document(activeSprite)
        local snap <const> = docPrefs.grid.snap
        if snap then
            local grid <const> = activeSprite.gridBounds
            local xGrOff <const> = grid.x
            local yGrOff <const> = grid.y
            local xGrScl <const> = grid.width
            local yGrScl <const> = grid.height
            local dxnz = dx ~= 0.0
            local dynz = dy ~= 0.0
            local round = Utilities.round
            app.transaction("Move Cels Snap", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
                    local cel <const> = cels[i]
                    local op <const> = cel.position
                    local xn = op.x
                    local yn = op.y
                    if dxnz then
                        local xGrid <const> = round((xn - xGrOff) / xGrScl)
                        xn = xGrOff + (xGrid + dx) * xGrScl
                    end
                    if dynz then
                        local yGrid <const> = round((yn - yGrOff) / yGrScl)
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
                    local cel <const> = cels[i]
                    local op <const> = cel.position
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        local activeFrame <const> = site.frame

        local args <const> = dlg.data
        local dx <const> = args.xTranslate
            or defaults.xTranslate --[[@as integer]]
        local dy <const> = args.yTranslate
            or defaults.yTranslate --[[@as integer]]
        if dx == 0.0 and dy == 0.0 then return end

        local target <const> = args.target
            or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, true)
        local lenCels <const> = #cels

        local trimAlpha <const> = AseUtilities.trimImageAlpha
        local wrap <const> = AseUtilities.wrapImage
        local spriteSpec <const> = activeSprite.spec
        local alphaMask <const> = spriteSpec.transparentColor

        local docPrefs <const> = app.preferences.document(activeSprite)
        local tiledMode <const> = docPrefs.tiled.mode
        if tiledMode == 3 then
            -- Tiling on both axes.
            app.transaction("Wrap Cels", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
                    local cel <const> = cels[i]
                    local blit <const> = Image(spriteSpec)
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
                    local cel <const> = cels[i]
                    local blit <const> = Image(spriteSpec)
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
                    local cel <const> = cels[i]
                    local blit <const> = Image(spriteSpec)
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
                    local cel <const> = cels[i]
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        local activeFrame <const> = site.frame

        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels <const> = #cels
        local xCtrSprite <const> = activeSprite.width * 0.5

        app.transaction("Align Top", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel <const> = cels[i]
                local op <const> = cel.position
                local xNew = op.x
                local yNew <const> = 0
                if op.y == yNew then
                    local w <const> = cel.image.width
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        local activeFrame <const> = site.frame

        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels <const> = #cels
        local yCtrSprite <const> = activeSprite.height * 0.5

        app.transaction("Align Left", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel <const> = cels[i]
                local op <const> = cel.position
                local xNew <const> = 0
                local yNew = op.y
                if op.x == xNew then
                    local h <const> = cel.image.height
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        local activeFrame <const> = site.frame

        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels <const> = #cels
        local xCtrSprite <const> = activeSprite.width * 0.5
        local hSprite <const> = activeSprite.height

        app.transaction("Align Bottom", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel <const> = cels[i]
                local celImg <const> = cel.image
                local op <const> = cel.position
                local xNew = op.x
                local yNew <const> = hSprite - celImg.height
                if op.y == yNew then
                    local w <const> = celImg.width
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        local activeFrame <const> = site.frame

        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels <const> = #cels
        local wSprite <const> = activeSprite.width
        local yCtrSprite <const> = activeSprite.height * 0.5

        app.transaction("Align Right", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel <const> = cels[i]
                local celImg <const> = cel.image
                local op <const> = cel.position
                local xNew <const> = wSprite - celImg.width
                local yNew = op.y
                if op.x == xNew then
                    local h <const> = cel.image.height
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        local activeFrame <const> = site.frame

        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels <const> = #cels
        local xc <const> = activeSprite.width * 0.5
        local yc <const> = activeSprite.height * 0.5
        local floor <const> = math.floor

        app.transaction("Center", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel <const> = cels[i]
                local celImg <const> = cel.image
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        local activeFrame <const> = site.frame

        -- Unpack arguments.
        local args <const> = dlg.data
        local degrees <const> = args.degrees
            or defaults.degrees --[[@as integer]]
        if degrees == 0 or degrees == 180 or degrees == 360
            or degrees == 90 or degrees == 270 then
            return
        end

        -- Determine bilinear vs. nearest.
        local easeMethod <const> = args.easeMethod
            or defaults.easeMethod --[[@as string]]
        local useBilinear <const> = easeMethod == "BILINEAR"
        local oldMode <const> = activeSprite.colorMode
        local sample = sampleNear
        if useBilinear then
            app.command.ChangePixelFormat { format = "rgb" }
            sample = sampleBilinear
        end

        -- Cache methods.
        local trimAlpha <const> = AseUtilities.trimImageAlpha
        local round <const> = Utilities.round
        local ceil <const> = math.ceil

        local target <const> = args.target
            or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels <const> = #cels

        local query <const> = AseUtilities.DIMETRIC_ANGLES[degrees]
        local radians = degrees * 0.017453292519943
        if query then radians = query end
        local tana <const> = math.tan(radians)
        local absTan <const> = math.abs(tana)

        app.transaction("Skew X", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel <const> = cels[i]
                local srcImg <const> = cel.image
                if not srcImg:isEmpty() then
                    local srcSpec <const> = srcImg.spec
                    local wSrc <const> = srcSpec.width
                    local hSrc <const> = srcSpec.height
                    local alphaMask <const> = srcSpec.transparentColor

                    local wTrg <const> = ceil(wSrc + absTan * hSrc)
                    local yCenter <const> = hSrc * 0.5
                    local xDiff <const> = (wSrc - wTrg) * 0.5
                    local wDiffHalf <const> = round((wTrg - wSrc) * 0.5)

                    local trgSpec <const> = ImageSpec {
                        width = wTrg, height = hSrc,
                        colorMode = srcSpec.colorMode,
                        transparentColor = alphaMask
                    }
                    trgSpec.colorSpace = srcSpec.colorSpace
                    local trgImg = Image(trgSpec)

                    local trgPxItr <const> = trgImg:pixels()
                    for pixel in trgPxItr do
                        pixel(sample(
                            xDiff + pixel.x + tana * (pixel.y - yCenter),
                            pixel.y, wSrc, hSrc, srcImg, alphaMask))
                    end

                    local xTrim = 0
                    local yTrim = 0
                    trgImg, xTrim, yTrim = trimAlpha(trgImg, 0, alphaMask)

                    local srcPos <const> = cel.position
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        local activeFrame <const> = site.frame

        -- Unpack arguments.
        local args <const> = dlg.data
        local degrees <const> = args.degrees
            or defaults.degrees --[[@as integer]]
        if degrees == 0 or degrees == 180 or degrees == 360
            or degrees == 90 or degrees == 270 then
            return
        end

        -- Determine bilinear vs. nearest.
        local easeMethod <const> = args.easeMethod
            or defaults.easeMethod --[[@as string]]
        local useBilinear <const> = easeMethod == "BILINEAR"
        local oldMode <const> = activeSprite.colorMode
        local sample = sampleNear
        if useBilinear then
            app.command.ChangePixelFormat { format = "rgb" }
            sample = sampleBilinear
        end

        -- Cache methods.
        local trimAlpha <const> = AseUtilities.trimImageAlpha
        local round <const> = Utilities.round
        local ceil <const> = math.ceil

        local target <const> = args.target
            or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels <const> = #cels

        local query <const> = AseUtilities.DIMETRIC_ANGLES[degrees]
        local radians = degrees * 0.017453292519943
        if query then radians = query end
        local tana <const> = math.tan(radians)
        local absTan <const> = math.abs(tana)

        app.transaction("Skew Y", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel <const> = cels[i]
                local srcImg <const> = cel.image
                if not srcImg:isEmpty() then
                    local srcSpec <const> = srcImg.spec
                    local wSrc <const> = srcSpec.width
                    local hSrc <const> = srcSpec.height
                    local alphaMask <const> = srcSpec.transparentColor

                    local hTrg <const> = ceil(hSrc + absTan * wSrc)
                    local xTrgCenter <const> = wSrc * 0.5
                    local yDiff <const> = (hSrc - hTrg) * 0.5
                    local hDiffHalf <const> = round((hTrg - hSrc) * 0.5)

                    local trgSpec <const> = ImageSpec {
                        width = wSrc, height = hTrg,
                        colorMode = srcSpec.colorMode,
                        transparentColor = alphaMask
                    }
                    trgSpec.colorSpace = srcSpec.colorSpace
                    local trgImg = Image(trgSpec)

                    local trgPxItr <const> = trgImg:pixels()
                    for pixel in trgPxItr do
                        pixel(sample(pixel.x,
                            yDiff + pixel.y + tana * (pixel.x - xTrgCenter),
                            wSrc, hSrc, srcImg, alphaMask))
                    end

                    local xTrim = 0
                    local yTrim = 0
                    trgImg, xTrim, yTrim = trimAlpha(trgImg, 0, alphaMask)

                    local srcPos <const> = cel.position
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        local activeFrame <const> = site.frame

        -- Unpack arguments.
        local args <const> = dlg.data
        local degrees = args.degrees
            or defaults.degrees --[[@as integer]]
        if degrees == 0 or degrees == 360 then return end

        local target <const> = args.target
            or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels <const> = #cels

        if degrees == 90 or degrees == 270 then
            local rotFunc = AseUtilities.rotateImage90
            if degrees == 270 then
                rotFunc = AseUtilities.rotateImage270
            end

            app.transaction("Rotate Cels", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
                    local cel <const> = cels[i]

                    local srcImg <const> = cel.image
                    local xSrcHalf <const> = srcImg.width // 2
                    local ySrcHalf <const> = srcImg.height // 2

                    local trgImg, _, _ = rotFunc(srcImg)
                    cel.image = trgImg

                    -- The target image width and height
                    -- are the source image height and width.
                    local celPos <const> = cel.position
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
                    local cel <const> = cels[i]
                    cel.image = rot180(cel.image)
                end
            end)
        else
            -- Cache methods.
            local trimAlpha <const> = AseUtilities.trimImageAlpha
            local round <const> = Utilities.round
            local ceil <const> = math.ceil

            -- Determine bilinear vs. nearest.
            local easeMethod <const> = args.easeMethod
                or defaults.easeMethod --[[@as string]]
            local useBilinear = easeMethod == "BILINEAR"
            local oldMode <const> = activeSprite.colorMode
            local sample = nil
            if useBilinear then
                app.command.ChangePixelFormat { format = "rgb" }
                sample = sampleBilinear
            else
                sample = sampleNear
            end

            -- Unpack angle.
            degrees = 360 - degrees
            local query <const> = AseUtilities.DIMETRIC_ANGLES[degrees]
            local radians = degrees * 0.017453292519943
            if query then radians = query end

            -- Avoid trigonmetric functions in while loop below.
            -- Cache sine and cosine here, then use formula for
            -- vector rotation.
            local cosa <const> = math.cos(radians)
            local sina <const> = -math.sin(radians)
            local absCosa <const> = math.abs(cosa)
            local absSina <const> = math.abs(sina)

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
                        local srcSpec <const> = srcImg.spec
                        local wSrc <const> = srcSpec.width
                        local hSrc <const> = srcSpec.height
                        local alphaMask <const> = srcSpec.transparentColor

                        -- Just in case, ceil this instead of floor.
                        local wTrg <const> = ceil(hSrc * absSina + wSrc * absCosa)
                        local hTrg <const> = ceil(hSrc * absCosa + wSrc * absSina)
                        local xSrcCenter <const> = wSrc * 0.5
                        local ySrcCenter <const> = hSrc * 0.5
                        local xTrgCenter <const> = wTrg * 0.5
                        local yTrgCenter <const> = hTrg * 0.5

                        -- Try to minimize drift in the cel's position.
                        local wDiffHalf <const> = round((wTrg - wSrc) * 0.5)
                        local hDiffHalf <const> = round((hTrg - hSrc) * 0.5)

                        local trgSpec <const> = ImageSpec {
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
                        local trgPxItr <const> = trgImg:pixels()
                        for pixel in trgPxItr do
                            local xSgn <const> = pixel.x - xTrgCenter
                            local ySgn <const> = pixel.y - yTrgCenter
                            local xRot <const> = cosa * xSgn - sina * ySgn
                            local yRot <const> = cosa * ySgn + sina * xSgn
                            local xSrc <const> = xSrcCenter + xRot
                            local ySrc <const> = ySrcCenter + yRot
                            pixel(sample(xSrc, ySrc, wSrc, hSrc,
                                srcImg, alphaMask))
                        end

                        local xTrim = 0
                        local yTrim = 0
                        trgImg, xTrim, yTrim = trimAlpha(trgImg, 0, alphaMask)

                        local srcPos <const> = cel.position
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
        local args <const> = dlg.data
        local unitType <const> = args.units --[[@as string]]
        local ispx <const> = unitType == "PIXEL"
        local ispc <const> = unitType == "PERCENT"
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        local activeFrame <const> = site.frame

        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, true)
        local lenCels <const> = #cels

        local fliph <const> = FlipType.HORIZONTAL
        app.transaction("Flip H", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel <const> = cels[i]
                local flipped <const> = cel.image:clone()
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        local activeFrame <const> = site.frame

        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, true)
        local lenCels <const> = #cels

        local flipv = FlipType.VERTICAL
        app.transaction("Flip V", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel <const> = cels[i]
                local flipped <const> = cel.image:clone()
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        local activeFrame <const> = site.frame

        -- Cache methods.
        local abs <const> = math.abs
        local max <const> = math.max
        local floor <const> = math.floor

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local unitType <const> = args.units
            or defaults.units --[[@as string]]
        local easeMethod <const> = args.easeMethod
            or defaults.easeMethod --[[@as string]]

        local usePercent <const> = unitType == "PERCENT"
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

        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels = #cels

        local oldMode <const> = activeSprite.colorMode
        local sample = sampleNear
        local useBilinear <const> = easeMethod == "BILINEAR"
        if useBilinear then
            app.command.ChangePixelFormat { format = "rgb" }
            sample = sampleBilinear
        end

        app.transaction("Scale Cels", function()
            local o = 0
            while o < lenCels do
                o = o + 1
                local cel <const> = cels[o]
                local srcImg <const> = cel.image
                if not srcImg:isEmpty() then
                    local srcSpec <const> = srcImg.spec
                    local wSrc <const> = srcSpec.width
                    local hSrc <const> = srcSpec.height

                    local wTrg = wPxl
                    local hTrg = hPxl
                    if usePercent then
                        wTrg = max(1, floor(0.5 + wSrc * wPrc))
                        hTrg = max(1, floor(0.5 + hSrc * hPrc))
                    end

                    if wSrc ~= wTrg or hSrc ~= hTrg then
                        -- Right-bottom edges were clipped
                        -- using wSrc / wTrg and hSrc / hTrg .
                        local tx <const> = (wSrc - 1.0) / (wTrg - 1.0)
                        local ty <const> = (hSrc - 1.0) / (hTrg - 1.0)

                        local colorMode <const> = srcSpec.colorMode
                        local alphaMask <const> = srcSpec.transparentColor
                        local colorSpace <const> = srcSpec.colorSpace
                        local trgSpec <const> = ImageSpec {
                            width = wTrg, height = hTrg,
                            colorMode = colorMode,
                            transparentColor = alphaMask
                        }
                        trgSpec.colorSpace = colorSpace
                        local trgImg <const> = Image(trgSpec)
                        local trgPxItr <const> = trgImg:pixels()

                        for pixel in trgPxItr do
                            pixel(sample(
                                pixel.x * tx, pixel.y * ty, wSrc, hSrc,
                                srcImg, alphaMask))
                        end

                        local celPos <const> = cel.position
                        local xCenter <const> = celPos.x + wSrc * 0.5
                        local yCenter <const> = celPos.y + hSrc * 0.5

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
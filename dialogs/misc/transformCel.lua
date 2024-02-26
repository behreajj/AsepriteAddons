dofile("../../support/aseutilities.lua")

local easeMethods <const> = { "BILINEAR", "NEAREST" }
local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local unitOptions <const> = { "PERCENT", "PIXEL" }

local defaults <const> = {
    -- TODO: Commit mask prior to transforms?
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

    -- Origin and destination colors have been checked for zero alpha before
    -- this function is called.
    --
    -- Premul and unpremul have to be done for horizontal and vertical mixes.
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
---@param sourceBytes string
---@param bpp integer
---@param defaultValue string
---@return string
local function sampleNear(
    xSrc, ySrc, wSrc, hSrc,
    sourceBytes, bpp,
    defaultValue)
    local xr <const> = Utilities.round(xSrc)
    local yr <const> = Utilities.round(ySrc)
    if yr >= 0 and yr < hSrc
        and xr >= 0 and xr < wSrc then
        local j <const> = yr * wSrc + xr
        local orig <const> = 1 + j * bpp
        local dest <const> = orig + bpp - 1
        return string.sub(sourceBytes, orig, dest)
    end
    return defaultValue
end

---@param xSrc number
---@param ySrc number
---@param wSrc integer
---@param hSrc integer
---@param sourceBytes string
---@param bpp integer
---@param defaultValue string
---@return string
local function sampleBilinear(
    xSrc, ySrc, wSrc, hSrc,
    sourceBytes, bpp,
    defaultValue)

    -- TODO: Make resize bilinear an AseUtilities method? Except in such a
    -- version, return RGBA tuple instead of string. Or maybe use lab instead?

    local xf <const> = math.floor(xSrc)
    local yf <const> = math.floor(ySrc)
    local xc <const> = xf + 1
    local yc <const> = yf + 1

    local yfInBounds <const> = yf > -1 and yf < hSrc
    local ycInBounds <const> = yc > -1 and yc < hSrc
    local xfInBounds <const> = xf > -1 and xf < wSrc
    local xcInBounds <const> = xc > -1 and xc < wSrc

    local a00 = 0
    local b00 = 0
    local g00 = 0
    local r00 = 0
    if yfInBounds and xfInBounds then
        local j <const> = yf * wSrc + xf
        local orig <const> = 1 + j * bpp
        local dest <const> = orig + bpp - 1
        r00, g00, b00, a00 = string.byte(sourceBytes, orig, dest)
    end

    local a10 = 0
    local b10 = 0
    local g10 = 0
    local r10 = 0
    if yfInBounds and xcInBounds then
        local j <const> = yf * wSrc + xc
        local orig <const> = 1 + j * bpp
        local dest <const> = orig + bpp - 1
        r10, g10, b10, a10 = string.byte(sourceBytes, orig, dest)
    end

    local a11 = 0
    local b11 = 0
    local g11 = 0
    local r11 = 0
    if ycInBounds and xcInBounds then
        local j <const> = yc * wSrc + xc
        local orig <const> = 1 + j * bpp
        local dest <const> = orig + bpp - 1
        r11, g11, b11, a11 = string.byte(sourceBytes, orig, dest)
    end

    local a01 = 0
    local b01 = 0
    local g01 = 0
    local r01 = 0
    if ycInBounds and xfInBounds then
        local j <const> = yc * wSrc + xf
        local orig <const> = 1 + j * bpp
        local dest <const> = orig + bpp - 1
        r01, g01, b01, a01 = string.byte(sourceBytes, orig, dest)
    end

    local a0 = 0.0
    local b0 = 0.0
    local g0 = 0.0
    local r0 = 0.0

    -- The trim alpha results are better when alpha zero check is done here.
    local xErr <const> = xSrc - xf
    if a00 > 0 or a10 > 0 then
        r0, g0, b0, a0 = rgbMix(
            r00, g00, b00, a00,
            r10, g10, b10, a10, xErr)
    end

    local a1 = 0.0
    local b1 = 0.0
    local g1 = 0.0
    local r1 = 0.0

    if a01 > 0 or a11 > 0 then
        r1, g1, b1, a1 = rgbMix(
            r01, g01, b01, a01,
            r11, g11, b11, a11, xErr)
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

        return string.pack("B B B B", rt, gt, bt, at)
    end
    return defaultValue
end

local dlg <const> = Dialog { title = "Transform Cel" }

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
        local lenCels <const> = #cels

        local docPrefs <const> = app.preferences.document(activeSprite)
        local snap <const> = docPrefs.grid.snap --[[@as boolean]]
        if snap then
            local grid <const> = activeSprite.gridBounds
            local xGrOff <const> = grid.x
            local yGrOff <const> = grid.y
            local xGrScl <const> = grid.width
            local yGrScl <const> = grid.height
            local dxnz <const> = dx ~= 0.0
            local dynz <const> = dy ~= 0.0
            local round <const> = Utilities.round
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
        local alphaIndex <const> = spriteSpec.transparentColor
        local blendModeSrc <const> = BlendMode.SRC

        local docPrefs <const> = app.preferences.document(activeSprite)
        local tiledMode <const> = docPrefs.tiled.mode --[[@as integer]]
        if tiledMode == 3 then
            -- Tiling on both axes.
            app.transaction("Wrap Cels", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
                    local cel <const> = cels[i]
                    local blit <const> = Image(spriteSpec)
                    blit:drawImage(cel.image, cel.position, 255, blendModeSrc)
                    local imgTrg = wrap(blit, dx, dy)
                    local xTrg = 0
                    local yTrg = 0
                    imgTrg, xTrg, yTrg = trimAlpha(imgTrg, 0, alphaIndex)
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
                    blit:drawImage(cel.image, cel.position, 255, blendModeSrc)
                    local imgTrg = wrap(blit, 0, dy)
                    local xTrg = 0
                    local yTrg = 0
                    imgTrg, xTrg, yTrg = trimAlpha(imgTrg, 0, alphaIndex)
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
                    blit:drawImage(cel.image, cel.position, 255, blendModeSrc)
                    local imgTrg = wrap(blit, dx, 0)
                    local xTrg = 0
                    local yTrg = 0
                    imgTrg, xTrg, yTrg = trimAlpha(imgTrg, 0, alphaIndex)
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
        local floor <const> = math.floor

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
                    xNew = floor(0.5 + xCtrSprite - w * 0.5)
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
        local floor <const> = math.floor

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
                    yNew = floor(0.5 + yCtrSprite - h * 0.5)
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
        local floor <const> = math.floor

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
                    xNew = floor(0.5 + xCtrSprite - w * 0.5)
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
        local floor <const> = math.floor

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
                    yNew = floor(0.5 + yCtrSprite - h * 0.5)
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
        local ceil <const> = math.ceil
        local createSpec <const> = AseUtilities.createSpec
        local trimAlpha <const> = AseUtilities.trimImageAlpha
        local round <const> = Utilities.round
        local strpack <const> = string.pack
        local tconcat <const> = table.concat

        local target <const> = args.target
            or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels <const> = #cels

        local query <const> = AseUtilities.DIMETRIC_ANGLES[degrees]
        local radians = degrees * 0.017453292519943
        if query and (not useBilinear) then radians = query end
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
                    local alphaIndex <const> = srcSpec.transparentColor

                    local srcBytes <const> = srcImg.bytes
                    local srcBpp <const> = srcImg.bytesPerPixel
                    local pxAlpha <const> = strpack(">I" .. srcBpp, alphaIndex)

                    local wTrgf <const> = wSrc + absTan * hSrc
                    local wTrgi <const> = ceil(wTrgf)
                    local yCenter <const> = hSrc * 0.5
                    local xDiff <const> = (wSrc - wTrgf) * 0.5
                    local wDiffHalf <const> = round((wTrgf - wSrc) * 0.5)

                    local trgSpec <const> = createSpec(
                        wTrgi, hSrc, srcSpec.colorMode,
                        srcSpec.colorSpace, alphaIndex)
                    local trgImg = Image(trgSpec)

                    ---@type string[]
                    local byteArr <const> = {}
                    local lenFlat <const> = wTrgi * hSrc
                    local j = 0
                    while j < lenFlat do
                        local ySrc <const> = j // wTrgi
                        local xSrc <const> = xDiff
                            + (j % wTrgi) + tana * (ySrc - yCenter)

                        j = j + 1
                        byteArr[j] = sample(xSrc, ySrc,
                            wSrc, hSrc, srcBytes, srcBpp, pxAlpha)
                    end
                    trgImg.bytes = tconcat(byteArr)

                    local xTrim = 0
                    local yTrim = 0
                    trgImg, xTrim, yTrim = trimAlpha(trgImg, 0, alphaIndex)

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
        local ceil <const> = math.ceil
        local createSpec <const> = AseUtilities.createSpec
        local trimAlpha <const> = AseUtilities.trimImageAlpha
        local round <const> = Utilities.round
        local strpack <const> = string.pack
        local tconcat <const> = table.concat

        local target <const> = args.target
            or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, false)
        local lenCels <const> = #cels

        local query <const> = AseUtilities.DIMETRIC_ANGLES[degrees]
        local radians = degrees * 0.017453292519943
        if query and (not useBilinear) then radians = query end
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
                    local alphaIndex <const> = srcSpec.transparentColor

                    local srcBytes <const> = srcImg.bytes
                    local srcBpp <const> = srcImg.bytesPerPixel
                    local pxAlpha <const> = strpack(">I" .. srcBpp, alphaIndex)

                    local hTrgf <const> = hSrc + absTan * wSrc
                    local hTrgi <const> = ceil(hTrgf)
                    local xTrgCenter <const> = wSrc * 0.5
                    local yDiff <const> = (hSrc - hTrgf) * 0.5
                    local hDiffHalf <const> = round((hTrgf - hSrc) * 0.5)

                    local trgSpec <const> = createSpec(
                        wSrc, hTrgi, srcSpec.colorMode,
                        srcSpec.colorSpace, alphaIndex)
                    local trgImg = Image(trgSpec)

                    ---@type string[]
                    local byteArr <const> = {}
                    local lenFlat <const> = wSrc * hTrgi
                    local j = 0
                    while j < lenFlat do
                        local xSrc <const> = j % wSrc
                        local ySrc <const> = yDiff + (j // wSrc)
                            + tana * (xSrc - xTrgCenter)

                        j = j + 1
                        byteArr[j] = sample(xSrc, ySrc,
                            wSrc, hSrc, srcBytes, srcBpp, pxAlpha)
                    end
                    trgImg.bytes = tconcat(byteArr)

                    local xTrim = 0
                    local yTrim = 0
                    trgImg, xTrim, yTrim = trimAlpha(trgImg, 0, alphaIndex)

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

                    cel.image = rotFunc(srcImg)

                    -- The target image width and height
                    -- are the source image height and width.
                    local celPos <const> = cel.position
                    cel.position = Point(
                        celPos.x + xSrcHalf - ySrcHalf,
                        celPos.y + ySrcHalf - xSrcHalf)
                end
            end)
        elseif degrees == 180 then
            local rot180 <const> = AseUtilities.rotateImage180
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
            local ceil <const> = math.ceil
            local createSpec <const> = AseUtilities.createSpec
            local trimAlpha <const> = AseUtilities.trimImageAlpha
            local strpack <const> = string.pack
            local tconcat <const> = table.concat
            local round <const> = Utilities.round

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
            if query and (not useBilinear) then radians = query end

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
                    local cel <const> = cels[i]
                    local srcImg <const> = cel.image
                    if not srcImg:isEmpty() then
                        local srcSpec <const> = srcImg.spec
                        local wSrc <const> = srcSpec.width
                        local hSrc <const> = srcSpec.height
                        local alphaIndex <const> = srcSpec.transparentColor

                        local srcBytes <const> = srcImg.bytes
                        local srcBpp <const> = srcImg.bytesPerPixel
                        local pxAlpha <const> = strpack(">I" .. srcBpp, alphaIndex)

                        local wTrgf <const> = hSrc * absSina + wSrc * absCosa
                        local hTrgf <const> = hSrc * absCosa + wSrc * absSina

                        -- Just in case, ceil this instead of floor.
                        local wTrgi <const> = ceil(wTrgf)
                        local hTrgi <const> = ceil(hTrgf)

                        local xSrcCenter <const> = wSrc * 0.5
                        local ySrcCenter <const> = hSrc * 0.5
                        local xTrgCenter <const> = wTrgf * 0.5
                        local yTrgCenter <const> = hTrgf * 0.5

                        -- Try to minimize drift in the cel's position.
                        local wDiffHalf <const> = round((wTrgf - wSrc) * 0.5)
                        local hDiffHalf <const> = round((hTrgf - hSrc) * 0.5)

                        local trgSpec <const> = createSpec(
                            wTrgi, hTrgi, srcSpec.colorMode,
                            srcSpec.colorSpace, alphaIndex)
                        local trgImg = Image(trgSpec)

                        ---@type string[]
                        local byteArr <const> = {}
                        local lenFlat <const> = wTrgi * hTrgi
                        local j = 0
                        while j < lenFlat do
                            local xSgn <const> = (j % wTrgi) - xTrgCenter
                            local ySgn <const> = (j // wTrgi) - yTrgCenter
                            local xRot <const> = cosa * xSgn - sina * ySgn
                            local yRot <const> = cosa * ySgn + sina * xSgn
                            local xSrc <const> = xSrcCenter + xRot
                            local ySrc <const> = ySrcCenter + yRot

                            j = j + 1
                            byteArr[j] = sample(xSrc, ySrc,
                                wSrc, hSrc, srcBytes, srcBpp, pxAlpha)
                        end
                        trgImg.bytes = tconcat(byteArr)

                        local xTrim = 0
                        local yTrim = 0
                        trgImg, xTrim, yTrim = trimAlpha(trgImg, 0, alphaIndex)

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
        local target <const> = args.target or defaults.target --[[@as string]]
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
        local target <const> = args.target or defaults.target --[[@as string]]
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            false, false, false, true)
        local lenCels <const> = #cels

        local flipv <const> = FlipType.VERTICAL
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
        local strpack <const> = string.pack
        local tconcat <const> = table.concat
        local createSpec <const> = AseUtilities.createSpec

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

        -- print(string.format(
        --     "wPxl: %.3f, hPxl: %.3f, wPrc: %.3f, hPrc: %.3f",
        --     wPxl, hPxl, wPrc, hPrc))

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
                    local alphaIndex <const> = srcSpec.transparentColor

                    local srcBytes <const> = srcImg.bytes
                    local srcBpp <const> = srcImg.bytesPerPixel
                    local pxAlpha <const> = strpack(">I" .. srcBpp, alphaIndex)

                    local wTrg = wPxl
                    local hTrg = hPxl
                    if usePercent then
                        wTrg = max(1, floor(0.5 + wSrc * wPrc))
                        hTrg = max(1, floor(0.5 + hSrc * hPrc))
                    end

                    if wSrc ~= wTrg or hSrc ~= hTrg then
                        -- Right-bottom edges were clipped
                        -- using wSrc / wTrg and hSrc / hTrg .
                        local tx <const> = wTrg > 1
                            and (wSrc - 1.0) / (wTrg - 1.0)
                            or 0.0
                        local ty <const> = hTrg > 1
                            and (hSrc - 1.0) / (hTrg - 1.0)
                            or 0.0
                        local ox <const> = wTrg > 1 and 0.0 or 0.5
                        local oy <const> = hTrg > 1 and 0.0 or 0.5

                        local trgSpec <const> = createSpec(
                            wTrg, hTrg, srcSpec.colorMode,
                            srcSpec.colorSpace, alphaIndex)
                        local trgImg <const> = Image(trgSpec)

                        ---@type string[]
                        local byteArr <const> = {}
                        local lenFlat <const> = wTrg * hTrg
                        local j = 0
                        while j < lenFlat do
                            local xTrg <const> = (j % wTrg) * tx + ox
                            local yTrg <const> = (j // wTrg) * ty + oy
                            j = j + 1
                            byteArr[j] = sample(xTrg, yTrg,
                                wSrc, hSrc, srcBytes, srcBpp, pxAlpha)
                        end
                        trgImg.bytes = tconcat(byteArr)

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

dlg:show {
    autoscrollbars = true,
    wait = false
}

local dlgBounds <const> = dlg.bounds
dlg.bounds = Rectangle(
    dlgBounds.x * 2 - 42, dlgBounds.y,
    dlgBounds.w, dlgBounds.h)
dofile("../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local unitOptions <const> = { "PERCENT", "PIXEL" }
local coordSystems <const> = { "CENTER", "TOP_LEFT" }

local defaults <const> = {
    -- Polar and Cartesian coordinates tried in commit
    -- 650a11ebc57a7e4539b5113297f5e2c404978e02 .
    -- Flip h and v tried in commit
    -- f8adad7ce334553e16701cae83cdf5a4657f8c4a .
    target = "ACTIVE",
    xTranslate = 0,
    yTranslate = 0,
    degrees = 90,
    pxWidth = 64,
    pxHeight = 64,
    prcWidth = 100,
    prcHeight = 100,
    units = "PERCENT",
    coordSystem = "TOP_LEFT",
}

---@param dialog Dialog
---@param x integer
---@param y integer
local function translateCels(dialog, x, y)
    if x == 0 and y == 0 then return end
    local site <const> = app.site
    local activeSprite <const> = site.sprite
    if not activeSprite then return end
    local activeLayer <const> = site.layer

    local args <const> = dialog.data
    local target <const> = args.target
        or defaults.target --[[@as string]]

    local filterFrames = activeSprite.frames
    if target == "ACTIVE" then
        local activeFrame <const> = site.frame
        if not activeFrame then return end
        filterFrames = { activeFrame }
    end

    local cels <const> = AseUtilities.filterCels(
        activeSprite, activeLayer, filterFrames, target,
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
        local dxnz <const> = x ~= 0
        local dynz <const> = y ~= 0
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
                    xn = xGrOff + (xGrid + x) * xGrScl
                end
                if dynz then
                    local yGrid <const> = round((yn - yGrOff) / yGrScl)
                    yn = yGrOff + (yGrid - y) * yGrScl
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
                cel.position = Point(op.x + x, op.y - y)
            end
        end)
    end

    app.refresh()
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
        local jbpp <const> = j * bpp
        return string.sub(sourceBytes, 1 + jbpp, bpp + jbpp)
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

dlg:separator { id = "translateSep" }

dlg:combobox {
    id = "coordSystem",
    label = "System:",
    option = defaults.coordSystem,
    options = coordSystems,
    visible = true
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
    id = "setPosButton",
    text = "SE&T",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer

        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]

        local filterFrames = activeSprite.frames
        if target == "ACTIVE" then
            local activeFrame <const> = site.frame
            if not activeFrame then return end
            filterFrames = { activeFrame }
        end

        local coordSystem <const> = args.coordSystem or
            defaults.coordSystem --[[@as string]]
        local x <const> = args.xTranslate
            or defaults.xTranslate --[[@as integer]]
        local y <const> = args.yTranslate
            or defaults.yTranslate --[[@as integer]]

        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, filterFrames, target,
            false, false, false, false)
        local lenCels <const> = #cels

        if coordSystem == "CENTER" then
            local docPrefs <const> = app.preferences.document(activeSprite)
            local symPrefs <const> = docPrefs.symmetry
            local symMode <const> = symPrefs.mode

            local xCenter <const> = (symMode == 1 or symMode == 3)
                and math.floor(symPrefs.x_axis)
                or activeSprite.width // 2
            local yCenter <const> = (symMode == 2 or symMode == 3)
                and math.floor(symPrefs.y_axis)
                or activeSprite.height // 2

            app.transaction("Relocate Cels", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
                    local cel <const> = cels[i]
                    local image <const> = cel.image
                    cel.position = Point(
                        xCenter + x - image.width // 2,
                        yCenter - y - image.height // 2)
                end
            end)
        else
            local pt <const> = Point(x, y)
            app.transaction("Relocate Cels", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
                    cels[i].position = pt
                end
            end)
        end

        app.refresh()
    end
}

dlg:button {
    id = "translateButton",
    text = "&MOVE",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local dx <const> = args.xTranslate
            or defaults.xTranslate --[[@as integer]]
        local dy <const> = args.yTranslate
            or defaults.yTranslate --[[@as integer]]
        translateCels(dlg, dx, dy)
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

        local args <const> = dlg.data
        local dx <const> = args.xTranslate
            or defaults.xTranslate --[[@as integer]]
        local dy <const> = args.yTranslate
            or defaults.yTranslate --[[@as integer]]
        if dx == 0.0 and dy == 0.0 then return end

        local target <const> = args.target
            or defaults.target --[[@as string]]

        local filterFrames = activeSprite.frames
        if target == "ACTIVE" then
            local activeFrame <const> = site.frame
            if not activeFrame then return end
            filterFrames = { activeFrame }
        end

        -- Only include background if wrapping on both edges.
        local docPrefs <const> = app.preferences.document(activeSprite)
        local tiledMode <const> = docPrefs.tiled.mode --[[@as integer]]
        local includeBkg <const> = (tiledMode == 2 and dx == 0)
            or (tiledMode == 1 and dy == 0)
            or tiledMode == 3
            or tiledMode == 0
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, filterFrames, target,
            false, false, false, includeBkg)
        local lenCels <const> = #cels

        local trimAlpha <const> = AseUtilities.trimImageAlpha
        local wrap <const> = AseUtilities.wrapImage
        local spriteSpec <const> = activeSprite.spec
        local alphaIndex <const> = spriteSpec.transparentColor
        local blendModeSrc <const> = BlendMode.SRC

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
            -- No tiling.
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
    id = "nudgeUp",
    text = "&I",
    label = "Nudge:",
    focus = false,
    onclick = function()
        translateCels(dlg, 0, 1)
    end
}

dlg:button {
    id = "nudgeLeft",
    text = "&J",
    focus = false,
    onclick = function()
        translateCels(dlg, -1, 0)
    end
}

dlg:button {
    id = "nudgeDown",
    text = "&K",
    focus = false,
    onclick = function()
        translateCels(dlg, 0, -1)
    end
}

dlg:button {
    id = "nudgeRight",
    text = "&L",
    focus = false,
    onclick = function()
        translateCels(dlg, 1, 0)
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

        -- Unpack arguments.
        local args <const> = dlg.data
        local degrees <const> = args.degrees
            or defaults.degrees --[[@as integer]]
        if degrees == 0 or degrees == 180 or degrees == 360
            or degrees == 90 or degrees == 270 then
            return
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

        local filterFrames = activeSprite.frames
        if target == "ACTIVE" then
            local activeFrame <const> = site.frame
            if not activeFrame then return end
            filterFrames = { activeFrame }
        end

        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, filterFrames, target,
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
                        byteArr[j] = sampleNear(xSrc, ySrc,
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

        -- Unpack arguments.
        local args <const> = dlg.data
        local degrees <const> = args.degrees
            or defaults.degrees --[[@as integer]]
        if degrees == 0 or degrees == 180 or degrees == 360
            or degrees == 90 or degrees == 270 then
            return
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

        local filterFrames = activeSprite.frames
        if target == "ACTIVE" then
            local activeFrame <const> = site.frame
            if not activeFrame then return end
            filterFrames = { activeFrame }
        end

        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, filterFrames, target,
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
                        byteArr[j] = sampleNear(xSrc, ySrc,
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

        app.refresh()
    end
}

dlg:button {
    id = "rotateButton",
    text = "&ROTATE",
    focus = true,
    onclick = function()
        -- Early returns.
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer

        -- Unpack arguments.
        local args <const> = dlg.data
        local degrees = args.degrees
            or defaults.degrees --[[@as integer]]
        if degrees == 0 or degrees == 360 then return end

        local target <const> = args.target
            or defaults.target --[[@as string]]

        local filterFrames = activeSprite.frames
        if target == "ACTIVE" then
            local activeFrame <const> = site.frame
            if not activeFrame then return end
            filterFrames = { activeFrame }
        end

        local is90 <const> = degrees == 90
        local is180 <const> = degrees == 180
        local is270 <const> = degrees == 270

        local includeBkg <const> = is180
            or (activeSprite.width == activeSprite.height
                and (is90 or is270))
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, filterFrames, target,
            false, false, false, includeBkg)
        local lenCels <const> = #cels

        if is90 or is270 then
            local rotFunc <const> = is270 and AseUtilities.rotateImage270
                or AseUtilities.rotateImage90

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
        elseif is180 then
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
            local floor <const> = math.floor
            local trimAlpha <const> = AseUtilities.trimImageAlpha
            local rotz <const> = AseUtilities.rotateImageZInternal

            -- Unpack angle.
            degrees = 360 - degrees
            local query <const> = AseUtilities.DIMETRIC_ANGLES[degrees]
            local radians = degrees * 0.017453292519943
            if query then radians = query end

            -- Avoid trigonometric functions in while loop below.
            -- Cache sine and cosine here, then use formula for
            -- vector rotation.
            local cosa <const> = math.cos(radians)
            local sina <const> = -math.sin(radians)
            local alphaIndex <const> = activeSprite.transparentColor

            app.transaction("Rotate Cels", function()
                local i = 0
                while i < lenCels do
                    i = i + 1
                    local cel <const> = cels[i]
                    local srcImg <const> = cel.image
                    if not srcImg:isEmpty() then
                        local celPos <const> = cel.position
                        local xSrcCtr <const> = celPos.x + srcImg.width * 0.5
                        local ySrcCtr <const> = celPos.y + srcImg.height * 0.5

                        local trgImg = rotz(srcImg, cosa, sina)
                        local xtlTrg = xSrcCtr - trgImg.width * 0.5
                        local ytlTrg = ySrcCtr - trgImg.height * 0.5

                        local xTrim = 0
                        local yTrim = 0
                        trgImg, xTrim, yTrim = trimAlpha(trgImg, 0, alphaIndex)
                        xtlTrg = xtlTrg + xTrim
                        ytlTrg = ytlTrg + yTrim

                        cel.position = Point(floor(xtlTrg), floor(ytlTrg))
                        cel.image = trgImg
                    end
                end
            end)
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

        local args <const> = dlg.data
        local target <const> = args.target or defaults.target --[[@as string]]

        local filterFrames = activeSprite.frames
        if target == "ACTIVE" then
            local activeFrame <const> = site.frame
            if not activeFrame then return end
            filterFrames = { activeFrame }
        end

        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, filterFrames, target,
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

        local args <const> = dlg.data
        local target <const> = args.target or defaults.target --[[@as string]]

        local filterFrames = activeSprite.frames
        if target == "ACTIVE" then
            local activeFrame <const> = site.frame
            if not activeFrame then return end
            filterFrames = { activeFrame }
        end

        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, filterFrames, target,
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

        local filterFrames = activeSprite.frames
        if target == "ACTIVE" then
            local activeFrame <const> = site.frame
            if not activeFrame then return end
            filterFrames = { activeFrame }
        end

        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, filterFrames, target,
            false, false, false, false)
        local lenCels = #cels

        local resize <const> = AseUtilities.resizeImageNearest

        app.transaction("Scale Cels", function()
            local o = 0
            while o < lenCels do
                o = o + 1
                local cel <const> = cels[o]
                local srcImg <const> = cel.image
                if not srcImg:isEmpty() then
                    local celPos <const> = cel.position
                    local xSrcCtr <const> = celPos.x + srcImg.width * 0.5
                    local ySrcCtr <const> = celPos.y + srcImg.height * 0.5

                    local wTrg = wPxl
                    local hTrg = hPxl
                    if usePercent then
                        wTrg = max(1, floor(0.5 + srcImg.width * wPrc))
                        hTrg = max(1, floor(0.5 + srcImg.height * hPrc))
                    end

                    local trgImg <const> = resize(srcImg, wTrg, hTrg)
                    local xtlTrg <const> = xSrcCtr - trgImg.width * 0.5
                    local ytlTrg <const> = ySrcCtr - trgImg.height * 0.5

                    cel.position = Point(floor(xtlTrg), floor(ytlTrg))
                    cel.image = trgImg
                end
            end
        end)

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
    dlgBounds.x * 2 - 52, dlgBounds.y,
    dlgBounds.w, dlgBounds.h)
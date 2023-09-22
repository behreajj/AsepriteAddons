local frameTargetOptions <const> = { "ACTIVE", "ALL", "MANUAL", "RANGE" }

local defaults <const> = {
    flattenImage = true,
    frameTarget = "ACTIVE",
    rangeStr = "",
    strExample = "4,6:9,13",
    useLoop = true,
    timeScalar = 1,
    includeLocked = true,
    includeHidden = false,
    includeTiles = true,
    includeBkg = true,
    border = 0,
    padding = 0,
    scale = 1,
    useChecker = false,
    usePixelAspect = true,
}

---@param bm BlendMode blend mode
---@return string
local function blendModeToStr(bm)
    -- The blend mode for group layers is nil.
    if bm then
        -- As of v1.3, blend mode NORMAL reports as SRC-OVER.
        -- CSS does not support addition, subtract or divide.
        if bm == BlendMode.NORMAL
            or bm == BlendMode.ADDITION
            or bm == BlendMode.SUBTRACT
            or bm == BlendMode.DIVIDE then
            return "normal"
        end

        if bm == BlendMode.HSL_HUE then return "hue" end
        if bm == BlendMode.HSL_SATURATION then return "saturation" end
        if bm == BlendMode.HSL_COLOR then return "color" end
        if bm == BlendMode.HSL_LUMINOSITY then return "luminosity" end

        local bmStr = "normal"
        for k, v in pairs(BlendMode) do
            if bm == v then
                bmStr = k
                break
            end
        end
        bmStr = string.gsub(string.lower(bmStr), "_", "-")
        return bmStr
    else
        return "normal"
    end
end

---@param img Image image
---@param border integer border size
---@param padding integer margin size
---@param wScale integer scale width
---@param hScale integer scale height
---@param xOff integer x offset
---@param yOff integer y offset
---@param palette Palette palette
---@return string
local function imgToSvgStr(
    img, border, padding,
    wScale, hScale,
    xOff, yOff,
    palette)
    -- https://github.com/aseprite/aseprite/issues/3561
    -- SVGs displayed in Firefox and Inkscape have thin gaps between squares at
    -- fractional zoom levels, e.g., 133%. Subtracting an epsilon from the left
    -- edge and adding to the right edge interferes with margin, can cause other
    -- zooming artifacts. Creating a path for each color then using subpaths for
    -- each square diminishes issue.
    local strfmt <const> = string.format
    local tconcat <const> = table.concat

    local imgSpec <const> = img.spec
    local imgWidth <const> = imgSpec.width
    local colorMode <const> = imgSpec.colorMode

    ---@type table<integer, integer[]>
    local pixelDict <const> = {}
    local pxItr <const> = img:pixels()

    if colorMode == ColorMode.INDEXED then
        local aseColorToHex <const> = AseUtilities.aseColorToHex
        local alphaIdx <const> = imgSpec.transparentColor
        local rgbColorMode <const> = ColorMode.RGB
        ---@type table<integer, integer>
        local clrIdxToHex <const> = {}
        for pixel in pxItr do
            local clrIdx <const> = pixel()
            if clrIdx ~= alphaIdx then
                local hex = clrIdxToHex[clrIdx]
                if not hex then
                    local aseColor <const> = palette:getColor(clrIdx)
                    hex = aseColorToHex(aseColor, rgbColorMode)
                    clrIdxToHex[clrIdx] = hex
                end

                local pxIdx <const> = pixel.x + pixel.y * imgWidth
                local idcs <const> = pixelDict[hex]
                if idcs then
                    idcs[#idcs + 1] = pxIdx
                else
                    pixelDict[hex] = { pxIdx }
                end
            end
        end
    elseif colorMode == ColorMode.GRAY then
        for pixel in pxItr do
            local gray <const> = pixel()
            if gray & 0xff00 ~= 0 then
                local idx <const> = pixel.x + pixel.y * imgWidth

                local a <const> = (gray >> 0x08) & 0xff
                local v <const> = gray & 0xff
                local hex <const> = a << 0x18 | v << 0x10 | v << 0x08 | v

                local idcs <const> = pixelDict[hex]
                if idcs then
                    idcs[#idcs + 1] = idx
                else
                    pixelDict[hex] = { idx }
                end
            end
        end
    elseif colorMode == ColorMode.RGB then
        for pixel in pxItr do
            local hex <const> = pixel()
            if hex & 0xff000000 ~= 0 then
                local idx <const> = pixel.x + pixel.y * imgWidth
                local idcs <const> = pixelDict[hex]
                if idcs then
                    idcs[#idcs + 1] = idx
                else
                    pixelDict[hex] = { idx }
                end
            end
        end
    end

    ---@type string[]
    local pathsArr <const> = {}
    for hex, idcs in pairs(pixelDict) do
        ---@type string[]
        local subPathsArr <const> = {}
        local lenIdcs <const> = #idcs
        local i = 0
        while i < lenIdcs do
            i = i + 1
            local idx <const> = idcs[i]
            local x0 <const> = xOff + (idx % imgWidth)
            local y0 <const> = yOff + (idx // imgWidth)

            local x1mrg <const> = border + (x0 + 1) * padding
            local y1mrg <const> = border + (y0 + 1) * padding

            local ax <const> = x1mrg + x0 * wScale
            local ay <const> = y1mrg + y0 * hScale
            local bx <const> = ax + wScale
            local by <const> = ay + hScale

            subPathsArr[i] = strfmt(
                "M %d %d L %d %d L %d %d L %d %d Z",
                ax, ay, bx, ay, bx, by, ax, by)

            -- More compressed version:
            -- subPathsArr[i] = strfmt(
            --     "M%d %dh%dv%dh%dv%dZ",
            --     ax, ay, wScale, hScale, -wScale, -hScale)
        end

        local lenSubPaths <const> = #subPathsArr
        if lenSubPaths > 0 then
            local webHex <const> = (hex & 0xff) << 0x10
                | (hex & 0xff00)
                | (hex >> 0x10 & 0xff)
            local alphaStr = ""
            local a <const> = hex >> 0x18 & 0xff
            if a < 0xff then
                alphaStr = strfmt(
                    " fill-opacity=\"%.6f\"",
                    a / 255.0)
            end
            local pathStr <const> = strfmt(
                "<path id=\"%08x\" fill=\"#%06X\"%s d=\"%s\" />",
                hex, webHex, alphaStr,
                tconcat(subPathsArr, " "))
            pathsArr[#pathsArr + 1] = pathStr
        end
    end

    return tconcat(pathsArr, "\n")
end

---@param layer Layer
---@param frame Frame|integer
---@param border integer
---@param padding integer
---@param wScale integer
---@param hScale integer
---@param spriteBounds Rectangle
---@param includeLocked boolean
---@param includeHidden boolean
---@param includeTiles boolean
---@param includeBkg boolean
---@param colorMode ColorMode
---@param palette Palette
---@param layersStrArr string[]
local function layerToSvgStr(
    layer, frame,
    border, padding, wScale, hScale,
    spriteBounds,
    includeLocked, includeHidden,
    includeTiles, includeBkg,
    colorMode, palette,
    layersStrArr)
    local isEditable <const> = layer.isEditable
    local isVisible <const> = layer.isVisible
    local isGroup <const> = layer.isGroup
    local isRef <const> = layer.isReference
    local isBkg <const> = layer.isBackground
    local isTilemap <const> = layer.isTilemap

    if (includeLocked or isEditable)
        and (includeHidden or isVisible) then
        -- Possible for layer name to be empty string.
        local layerName = "layer"
        if layer.name and #layer.name > 0 then
            layerName = string.lower(
                Utilities.validateFilename(layer.name))
        end
        local visStr = ""
        if not isVisible then
            visStr = " visibility=\"hidden\""
        end

        if isGroup then
            ---@type string[]
            local childStrs <const> = {}
            local children <const> = layer.layers --[=[@as Layer[]]=]
            local lenChildren <const> = #children

            if lenChildren > 0 then
                local i = 0
                while i < lenChildren do
                    i = i + 1
                    local child <const> = children[i]
                    layerToSvgStr(
                        child, frame, border, padding, wScale, hScale,
                        spriteBounds, includeLocked, includeHidden,
                        includeTiles, includeBkg, colorMode, palette, childStrs)
                end

                local grpStr <const> = string.format(
                    "<g id=\"%s\"%s>\n%s\n</g>",
                    layerName, visStr, table.concat(childStrs, "\n"))
                layersStrArr[#layersStrArr + 1] = grpStr
            end
        elseif (not isRef)
            and (includeTiles or (not isTilemap))
            and (includeBkg or (not isBkg)) then
            local cel <const> = layer:cel(frame)
            if cel then
                -- A definition could be created for tile sets, then accessed
                -- with use xlink:href, but best to keep things simple for
                -- compatibility with Inkscape, Processing, Blender, etc.
                local celImg = cel.image
                if layer.isTilemap then
                    celImg = AseUtilities.tilesToImage(
                        celImg, layer.tileset, colorMode)
                end

                if not celImg:isEmpty() then
                    -- Layer opacity and cel opacity are compounded.
                    local celAlpha <const> = cel.opacity
                    local lyrAlpha <const> = layer.opacity
                    local alphaStr = ""
                    if lyrAlpha < 0xff or celAlpha < 0xff then
                        local cmpAlpha <const> = (lyrAlpha / 255.0)
                            * (celAlpha * 255.0)
                        alphaStr = string.format(
                            " opacity=\"%.6f\"",
                            cmpAlpha)
                    end

                    -- feBlend seems more backward compatible, but inline
                    -- CSS style results in shorter code.
                    local bmStr <const> = blendModeToStr(layer.blendMode)

                    -- Clip off cels that are beyond sprite canvas.
                    local celBounds <const> = cel.bounds
                    local xCel <const> = celBounds.x
                    local yCel <const> = celBounds.y
                    local intersect <const> = celBounds:intersect(spriteBounds)
                    intersect.x = intersect.x - xCel
                    intersect.y = intersect.y - yCel

                    local imgStr <const> = imgToSvgStr(
                        celImg, border, padding,
                        wScale, hScale, xCel, yCel,
                        palette)

                    local grpStr <const> = string.format(
                        "<g id=\"%s\"%s style=\"mix-blend-mode: %s;\"%s>\n%s\n</g>",
                        layerName, visStr, bmStr, alphaStr, imgStr)
                    layersStrArr[#layersStrArr + 1] = grpStr
                end
            end -- End cel exists check.
        end     -- End isGroup branch.
    end         -- End isVisible and isEditable.
end

local dlg = Dialog { title = "SVG Export" }

dlg:check {
    id = "flattenImage",
    label = "Flatten:",
    text = "&Sprite",
    selected = defaults.flattenImage,
    onclick = function()
        local args <const> = dlg.data
        local flat <const> = args.flattenImage --[[@as boolean]]
        local state <const> = args.frameTarget --[[@as string]]
        local isManual <const> = state == "MANUAL"
        local notFlat <const> = not flat

        dlg:modify { id = "frameTarget", visible = flat }
        dlg:modify { id = "rangeStr", visible = flat and isManual }
        dlg:modify { id = "strExample", visible = false }
        dlg:modify { id = "useLoop", visible = flat }
        dlg:modify { id = "timeScalar", visible = flat }

        dlg:modify { id = "includeLocked", visible = notFlat }
        dlg:modify { id = "includeHidden", visible = notFlat }
        dlg:modify { id = "includeTiles", visible = notFlat }
        dlg:modify { id = "includeBkg", visible = notFlat }
        dlg:modify { id = "zIndexWarning", visible = notFlat }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "frameTarget",
    label = "Frames:",
    option = defaults.frameTarget,
    options = frameTargetOptions,
    visible = defaults.flattenImage,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.frameTarget --[[@as string]]
        local isManual <const> = state == "MANUAL"
        dlg:modify { id = "rangeStr", visible = isManual }
        dlg:modify { id = "strExample", visible = false }
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "rangeStr",
    label = "Entry:",
    text = defaults.rangeStr,
    focus = false,
    visible = defaults.flattenImage
        and defaults.frameTarget == "MANUAL",
    onchange = function()
        dlg:modify { id = "strExample", visible = true }
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "strExample",
    label = "Example:",
    text = defaults.strExample,
    visible = false
}

dlg:newrow { always = false }

dlg:number {
    id = "timeScalar",
    label = "Speed:",
    text = string.format("%.3f", defaults.timeScalar),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.flattenImage
}

dlg:newrow { always = false }

dlg:check {
    id = "useLoop",
    label = "Loop:",
    text = "&Infinite",
    selected = defaults.useLoop,
    visible = defaults.flattenImage
}

dlg:newrow { always = false }

dlg:check {
    id = "includeLocked",
    label = "Include:",
    text = "&Locked",
    selected = defaults.includeLocked,
    visible = not defaults.flattenImage
}

dlg:check {
    id = "includeHidden",
    text = "&Hidden",
    selected = defaults.includeHidden,
    visible = not defaults.flattenImage
}

dlg:newrow { always = false }

dlg:check {
    id = "includeTiles",
    text = "&Tiles",
    selected = defaults.includeTiles,
    visible = not defaults.flattenImage
}

dlg:check {
    id = "includeBkg",
    text = "&Background",
    selected = defaults.includeBkg,
    visible = not defaults.flattenImage
}

dlg:newrow { always = false }

dlg:label {
    id = "zIndexWarning",
    label = "Note:",
    text = "Z Indices not supported.",
    visible = not defaults.flattenImage
}

dlg:newrow { always = false }

dlg:slider {
    id = "scale",
    label = "Scale:",
    min = 1,
    max = 32,
    value = defaults.scale
}

dlg:newrow { always = false }

dlg:slider {
    id = "border",
    label = "Border:",
    min = 0,
    max = 64,
    value = defaults.border,
    onchange = function()
        local args <const> = dlg.data
        local border <const> = args.border --[[@as integer]]
        local gtz <const> = border > 0
        dlg:modify { id = "borderClr", visible = gtz }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "borderClr",
    color = Color { r = 0, g = 0, b = 0 },
    visible = defaults.border > 0
}

dlg:newrow { always = false }

dlg:slider {
    id = "padding",
    label = "Px Grid:",
    min = 0,
    max = 64,
    value = defaults.padding,
    onchange = function()
        local args <const> = dlg.data
        local padding <const> = args.padding --[[@as integer]]
        local gtz <const> = padding > 0
        dlg:modify { id = "paddingClr", visible = gtz }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "paddingClr",
    color = Color { r = 255, g = 255, b = 255 },
    visible = defaults.padding > 0
}

dlg:newrow { always = false }

dlg:check {
    id = "useChecker",
    label = "Background:",
    text = "Chec&ker",
    selected = defaults.useChecker
}

dlg:newrow { always = false }

dlg:check {
    id = "usePixelAspect",
    label = "Apply:",
    text = "Pi&xel Aspect",
    selected = defaults.usePixelAspect
}

dlg:newrow { always = false }

dlg:file {
    id = "filepath",
    label = "Path:",
    filetypes = { "svg" },
    save = true,
    focus = true
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        -- Early returns.
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        -- Unpack file path.
        local args <const> = dlg.data
        local filepath <const> = args.filepath --[[@as string]]
        if (not filepath) or (#filepath < 1) then
            app.alert { title = "Error", text = "Filepath is empty." }
            return
        end

        local ext <const> = app.fs.fileExtension(filepath)
        if string.lower(ext) ~= "svg" then
            app.alert { title = "Error", text = "Extension is not svg." }
            return
        end

        -- Unpack arguments.
        local flattenImage <const> = args.flattenImage --[[@as boolean]]
        local border <const> = args.border or defaults.border --[[@as integer]]
        local borderClr <const> = args.borderClr --[[@as Color]]
        local padding <const> = args.padding
            or defaults.padding --[[@as integer]]
        local paddingClr <const> = args.paddingClr --[[@as Color]]
        local scale <const> = args.scale or defaults.scale --[[@as integer]]
        local useChecker <const> = args.useChecker --[[@as boolean]]
        local usePixelAspect <const> = args.usePixelAspect --[[@as boolean]]

        -- Process scale
        local wScale = scale
        local hScale = scale
        if usePixelAspect then
            local pxRatio <const> = activeSprite.pixelRatio
            wScale = wScale * math.max(1, math.abs(pxRatio.width))
            hScale = hScale * math.max(1, math.abs(pxRatio.height))
        end

        -- Doc prefs are needed to get the frame UI offset, grid color and
        -- background checker.
        local docPrefs <const> = app.preferences.document(activeSprite)

        -- Unpack sprite spec.
        local activeSpec <const> = activeSprite.spec
        local colorMode <const> = activeSpec.colorMode
        local wNative <const> = activeSpec.width
        local hNative <const> = activeSpec.height

        -- Determine size of scaled image plus pixel padding, then the right
        -- edge facing the border, then the total dimension.
        local wClip <const> = wScale * wNative + padding * (wNative + 1)
        local hClip <const> = hScale * hNative + padding * (hNative + 1)
        local wnBorder <const> = wClip + border
        local hnBorder <const> = hClip + border
        local wTotal <const> = wnBorder + border
        local hTotal <const> = hnBorder + border

        -- Cache these methods because they are used so often
        local strfmt <const> = string.format
        local tconcat <const> = table.concat

        local defsStr = ""
        local bkgStr = ""
        if useChecker then
            local bgPref <const> = docPrefs.bg

            local size <const> = bgPref.size --[[@as Size]]
            local wCheck <const> = math.max(1, math.abs(size.width))
            local hCheck <const> = math.max(1, math.abs(size.height))
            local wCheckScaled <const> = wCheck * wScale
            local hCheckScaled <const> = hCheck * hScale
            local wcs2 = wCheckScaled + wCheckScaled
            local hcs2 = hCheckScaled + hCheckScaled

            local aColor <const> = bgPref.color1 --[[@as Color]]
            local aHex <const> = aColor.red << 0x10
                | aColor.green << 0x08
                | aColor.blue
            local bColor <const> = bgPref.color2 --[[@as Color]]
            local bHex <const> = bColor.red << 0x10
                | bColor.green << 0x08
                | bColor.blue

            local sqFmt <const> = "<path d=\"M %d %d L %d %d L %d %d L %d %d "
                .. "Z\" fill=\"#%06x\" />\n"
            defsStr = tconcat({
                "<defs>\n",
                strfmt(
                    "<pattern id=\"checkerPattern\" x=\"%d\" y=\"%d\" "
                    .. "width=\"%d\" height=\"%d\" patternUnits=\"%s\">\n",
                    border, border, wcs2, hcs2, "userSpaceOnUse"),
                strfmt(sqFmt, 0, 0, wCheckScaled, 0, wCheckScaled, hCheckScaled,
                    0, hCheckScaled, aHex),
                strfmt(sqFmt, wCheckScaled, 0, wcs2, 0, wcs2, hCheckScaled,
                    wCheckScaled, hCheckScaled, bHex),
                strfmt(sqFmt, 0, hCheckScaled, wCheckScaled, hCheckScaled,
                    wCheckScaled, hcs2, 0, hcs2, bHex),
                strfmt(sqFmt, wCheckScaled, hCheckScaled, wcs2, hCheckScaled,
                    wcs2, hcs2, wCheckScaled, hcs2, aHex),
                "</pattern>\n",
                "</defs>\n"
            })

            bkgStr = strfmt(
                "<path id =\"checker\" d=\"M %d %d L %d %d L %d %d L %d %d Z\" "
                .. "fill=\"url(#checkerPattern)\" />\n",
                border, border, wnBorder, border,
                wnBorder, hnBorder, border, hnBorder)
        end

        ---@type string[]
        local layersStrArr <const> = {}
        if flattenImage then
            local frameTarget = args.frameTarget
                or defaults.frameTarget --[[@as string]]
            local rangeStr = args.rangeStr
                or defaults.rangeStr --[[@as string]]

            local chosenFrIdcs = Utilities.flatArr2(AseUtilities.getFrames(
                activeSprite, frameTarget, true, rangeStr))
            local lenChosenFrames <const> = #chosenFrIdcs
            local animate <const> = lenChosenFrames > 1

            if animate then
                local useLoop <const> = args.useLoop --[[@as boolean]]
                local timeScalar <const> = args.timeScalar
                    or defaults.timeScalar --[[@as number]]

                local tlPrefs <const> = docPrefs.timeline
                local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]
                local spritePalettes <const> = activeSprite.palettes
                local spriteFrames <const> = activeSprite.frames

                local animBeginStr = "0s"
                if useLoop then
                    animBeginStr = strfmt(
                        "0s;anim%d.end",
                        lenChosenFrames)
                end
                local timeScaleVrf = 1.0
                if timeScalar ~= 0.0 then
                    timeScaleVrf = 1.0 / math.abs(timeScalar)
                end

                -- There was flickering in Firefox until "from=\"visible\""
                -- was added. The display and opacity attributes might also
                -- work for animation.
                local frameFormat <const> = tconcat({
                    "<g",
                    " id=\"frame%d\"",
                    " visibility=\"hidden\"",
                    ">\n",
                    "<animate",
                    " id=\"anim%d\"",
                    " attributeName=\"visibility\"",
                    " from=\"visible\"",
                    " to=\"visible\"",
                    " begin=\"%s\"",
                    " dur=\"%s\"",
                    " />\n%s\n</g>"
                })

                -- Cache methods used in loop.
                local getPalette <const> = AseUtilities.getPalette

                ---@type string[]
                local frameStrs <const> = {}

                local i = 0
                while i < lenChosenFrames do
                    i = i + 1
                    local frIdx <const> = chosenFrIdcs[i]
                    local frObj <const> = spriteFrames[frIdx]
                    local duration <const> = frObj.duration

                    -- Create image SVG string.
                    local flatImg <const> = Image(activeSpec)
                    flatImg:drawSprite(activeSprite, frObj)
                    local palette <const> = getPalette(frIdx, spritePalettes)
                    local imgStr <const> = imgToSvgStr(
                        flatImg, border, padding,
                        wScale, hScale, 0, 0,
                        palette)

                    -- Create frame SVG string.
                    local durStr = "indefinite"
                    if useLoop or i < lenChosenFrames then
                        -- Before time scalar, only 3 decimals were needed
                        -- because duration was truncated from millis.
                        durStr = strfmt("%.6fs", timeScaleVrf * duration)
                    end
                    local frameStr <const> = strfmt(
                        frameFormat,
                        frameUiOffset + frIdx, i,
                        animBeginStr, durStr,
                        imgStr)
                    frameStrs[i] = frameStr

                    -- Update for next iteration in loop.
                    animBeginStr = strfmt("anim%d.end", i)
                end

                layersStrArr[1] = tconcat(frameStrs, "\n")
            else
                local activeFrame = site.frame
                if lenChosenFrames > 0 then
                    activeFrame = activeSprite.frames[chosenFrIdcs[1]]
                end
                if not activeFrame then
                    app.alert {
                        title = "Error",
                        text = "There is no active frame."
                    }
                    return
                end

                local palette <const> = AseUtilities.getPalette(
                    activeFrame, activeSprite.palettes)

                local flatImg <const> = Image(activeSpec)
                flatImg:drawSprite(activeSprite, activeFrame)
                layersStrArr[1] = imgToSvgStr(
                    flatImg, border, padding,
                    wScale, hScale, 0, 0,
                    palette)
            end
        else
            local includeLocked <const> = args.includeLocked --[[@as boolean]]
            local includeHidden <const> = args.includeHidden --[[@as boolean]]
            local includeTiles <const> = args.includeTiles --[[@as boolean]]
            local includeBkg <const> = args.includeBkg --[[@as boolean]]

            local spriteBounds <const> = activeSprite.bounds
            local spriteLayers <const> = activeSprite.layers
            local lenSpriteLayers <const> = #spriteLayers

            local activeFrame <const> = site.frame
            if not activeFrame then
                app.alert {
                    title = "Error",
                    text = "There is no active frame."
                }
                return
            end

            local palette <const> = AseUtilities.getPalette(
                activeFrame, activeSprite.palettes)

            local j = 0
            while j < lenSpriteLayers do
                j = j + 1
                local layer <const> = spriteLayers[j]
                layerToSvgStr(
                    layer, activeFrame, border, padding, wScale, hScale,
                    spriteBounds, includeLocked, includeHidden, includeTiles,
                    includeBkg, colorMode, palette, layersStrArr)
            end
        end

        local padStr = ""
        local aPadding <const> = paddingClr.alpha
        if padding > 0 and aPadding > 0 then
            local webHex <const> = paddingClr.red << 0x10
                | paddingClr.green << 0x08
                | paddingClr.blue

            local alphaStr = ""
            if aPadding < 0xff then
                alphaStr = strfmt(" fill-opacity=\"%.6f\"", aPadding / 255.0)
            end

            -- Cut out a hole for each pixel (counter-clockwise).
            ---@type string[]
            local holeStrArr <const> = {}
            local lenPixels <const> = wNative * hNative
            local i = 0
            while i < lenPixels do
                local y <const> = i // wNative
                local x <const> = i % wNative

                local x1mrg <const> = border + (x + 1) * padding
                local y1mrg <const> = border + (y + 1) * padding

                local ax <const> = x1mrg + x * wScale
                local ay <const> = y1mrg + y * hScale
                local bx <const> = ax + wScale
                local by <const> = ay + hScale

                i = i + 1
                holeStrArr[i] = strfmt(
                    "M %d %d L %d %d L %d %d L %d %d Z",
                    ax, ay, ax, by, bx, by, bx, ay)
            end

            padStr = strfmt(
                "\n<path id=\"grid\" fill=\"#%06X\"%s "
                .. "d=\"M %d %d L %d %d L %d %d L %d %d Z %s\" />",
                webHex, alphaStr,
                border, border,
                wnBorder, border,
                wnBorder, hnBorder,
                border, hnBorder,
                tconcat(holeStrArr, " ")
            )
        end

        local borderStr = ""
        local aBorder <const> = borderClr.alpha
        if border > 0 and aBorder > 0 then
            local webHex <const> = borderClr.red << 0x10
                | borderClr.green << 0x08
                | borderClr.blue

            local alphaStr = ""
            if aBorder < 0xff then
                alphaStr = strfmt(
                    " fill-opacity=\"%.6f\"",
                    aBorder / 255.0)
            end

            borderStr = strfmt(
                "\n<path id=\"border\" fill=\"#%06X\"%s "
                .. "d=\"M 0 0 L %d 0 L %d %d L 0 %d Z"
                .. "M %d %d L %d %d L %d %d L %d %d Z\" />",
                webHex, alphaStr,
                wTotal, wTotal,
                hTotal, hTotal,
                border, border,
                border, hnBorder,
                wnBorder, hnBorder,
                wnBorder, border)
        end

        -- If there were any diagonal guidelines, then this shape rendering
        -- is no longer a suitable choice. However, geometricPrecision causes
        -- problems with background checker pattern.
        local renderHintStr = "shape-rendering=\"crispEdges\" "

        local svgStr <const> = tconcat({
            "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n",
            "<svg ",
            "xmlns=\"http://www.w3.org/2000/svg\" ",
            "xmlns:xlink=\"http://www.w3.org/1999/xlink\" ",
            renderHintStr,
            "stroke=\"none\" ",
            "preserveAspectRatio=\"xMidYMid slice\" ",
            strfmt(
                "width=\"%d\" height=\"%d\" ",
                wTotal, hTotal),
            strfmt(
                "viewBox=\"0 0 %d %d\">\n",
                wTotal, hTotal),
            defsStr,
            bkgStr,
            tconcat(layersStrArr, "\n"),
            padStr,
            borderStr,
            "\n</svg>"
        })

        local file <const>, err <const> = io.open(filepath, "w")
        if file then
            file:write(svgStr)
            file:close()
        end

        if err then
            app.alert { title = "Error", text = err }
            return
        end

        app.alert { title = "Success", text = "File exported." }
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

dlg:show { wait = false }
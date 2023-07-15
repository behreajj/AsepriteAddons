local frameTargetOptions = { "ACTIVE", "ALL", "MANUAL", "RANGE" }

local defaults = {
    flattenImage = true,
    frameTarget = "ACTIVE",
    rangeStr = "",
    strExample = "4,6:9,13",
    useLoop = true,
    includeLocked = true,
    includeHidden = false,
    includeTiles = true,
    includeBkg = true,
    border = 0,
    padding = 0,
    scale = 1,
    usePixelAspect = true,
}

---@param bm BlendMode|integer blend mode
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
    -- SVGs displayed in Firefox and Inkscape have thin gaps
    -- between squares at fractional zoom levels, e.g., 133%.
    -- Subtracting an epsilon from the left edge and adding to
    -- the right edge interferes with margin, can cause other
    -- zooming artifacts. Creating a path for each color
    -- then using subpaths for each square diminishes issue.
    local strfmt = string.format
    local tconcat = table.concat

    local imgSpec = img.spec
    local imgWidth = imgSpec.width
    local colorMode = imgSpec.colorMode

    ---@type table<integer, integer[]>
    local pixelDict = {}
    local pxItr = img:pixels()

    if colorMode == ColorMode.INDEXED then
        local aseColorToHex = AseUtilities.aseColorToHex
        local alphaIdx = imgSpec.transparentColor
        local rgbColorMode = ColorMode.RGB
        for pixel in pxItr do
            local clrIdx = pixel()
            if clrIdx ~= alphaIdx then
                local idx = pixel.x + pixel.y * imgWidth

                local aseColor = palette:getColor(clrIdx)
                local hex = aseColorToHex(aseColor, rgbColorMode)

                local idcs = pixelDict[hex]
                if idcs then
                    idcs[#idcs + 1] = idx
                else
                    pixelDict[hex] = { idx }
                end
            end
        end
    elseif colorMode == ColorMode.GRAY then
        for pixel in pxItr do
            local gray = pixel()
            if gray & 0xff00 ~= 0 then
                local idx = pixel.x + pixel.y * imgWidth

                local a = (gray >> 0x08) & 0xff
                local v = gray & 0xff
                local hex = a << 0x18 | v << 0x10 | v << 0x08 | v

                local idcs = pixelDict[hex]
                if idcs then
                    idcs[#idcs + 1] = idx
                else
                    pixelDict[hex] = { idx }
                end
            end
        end
    elseif colorMode == ColorMode.RGB then
        for pixel in pxItr do
            local hex = pixel()
            if hex & 0xff000000 ~= 0 then
                local idx = pixel.x + pixel.y * imgWidth
                local idcs = pixelDict[hex]
                if idcs then
                    idcs[#idcs + 1] = idx
                else
                    pixelDict[hex] = { idx }
                end
            end
        end
    end

    ---@type string[]
    local pathsArr = {}
    for hex, idcs in pairs(pixelDict) do
        ---@type string[]
        local subPathsArr = {}
        local lenIdcs = #idcs
        local i = 0
        while i < lenIdcs do
            i = i + 1
            local idx = idcs[i]
            local x0 = xOff + (idx % imgWidth)
            local y0 = yOff + (idx // imgWidth)

            local x1mrg = border + (x0 + 1) * padding
            local y1mrg = border + (y0 + 1) * padding

            local ax = x1mrg + x0 * wScale
            local ay = y1mrg + y0 * hScale
            local bx = ax + wScale
            local by = ay + hScale

            subPathsArr[i] = strfmt(
                "M %d %d L %d %d L %d %d L %d %d Z",
                ax, ay, bx, ay, bx, by, ax, by)

            -- More compressed version:
            -- subPathsArr[i] = strfmt(
            --     "M%d %dh%dv%dh%dv%dZ",
            --     ax, ay, wScale, hScale, -wScale, -hScale)
        end

        local lenSubPaths = #subPathsArr
        if lenSubPaths > 0 then
            local webHex = (hex & 0xff) << 0x10
                | (hex & 0xff00)
                | (hex >> 0x10 & 0xff)
            local alphaStr = ""
            local a = hex >> 0x18 & 0xff
            if a < 0xff then
                alphaStr = strfmt(
                    " fill-opacity=\"%.6f\"",
                    a / 255.0)
            end
            local pathStr = strfmt(
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
    local isEditable = layer.isEditable
    local isVisible = layer.isVisible
    local isGroup = layer.isGroup
    local isRef = layer.isReference
    local isBkg = layer.isBackground
    local isTilemap = layer.isTilemap

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
            local childStrs = {}
            local children = layer.layers --[=[@as Layer[]]=]
            local lenChildren = #children

            if lenChildren > 0 then
                local i = 0
                while i < lenChildren do
                    i = i + 1
                    local child = children[i]
                    layerToSvgStr(
                        child, frame,
                        border, padding, wScale, hScale,
                        spriteBounds,
                        includeLocked,
                        includeHidden,
                        includeTiles,
                        includeBkg,
                        colorMode,
                        palette,
                        childStrs)
                end

                local grpStr = string.format(
                    "<g id=\"%s\"%s>\n%s\n</g>",
                    layerName, visStr, table.concat(childStrs, "\n"))
                layersStrArr[#layersStrArr + 1] = grpStr
            end
        elseif (not isRef)
            and (includeTiles or (not isTilemap))
            and (includeBkg or (not isBkg)) then
            local cel = layer:cel(frame)
            if cel then
                -- A definition could be created for tile sets,
                -- then accessed with use xlink:href, but best to
                -- keep things simple for compatibility with Inkscape,
                -- Processing, Blender, etc.
                local celImg = cel.image
                if layer.isTilemap then
                    celImg = AseUtilities.tilesToImage(
                        celImg, layer.tileset, colorMode)
                end

                if not celImg:isEmpty() then
                    -- Layer opacity and cel opacity are compounded.
                    local celAlpha = cel.opacity
                    local lyrAlpha = layer.opacity
                    local alphaStr = ""
                    if lyrAlpha < 0xff or celAlpha < 0xff then
                        local cmpAlpha = (lyrAlpha * 0.003921568627451)
                            * (celAlpha * 0.003921568627451)
                        alphaStr = string.format(
                            " opacity=\"%.6f\"",
                            cmpAlpha)
                    end

                    -- feBlend seems more backward compatible, but inline
                    -- CSS style results in shorter code.
                    local bmStr = blendModeToStr(layer.blendMode)

                    -- Clip off cels that are beyond sprite canvas.
                    local celBounds = cel.bounds
                    local xCel = celBounds.x
                    local yCel = celBounds.y
                    local intersect = celBounds:intersect(spriteBounds)
                    intersect.x = intersect.x - xCel
                    intersect.y = intersect.y - yCel

                    local imgStr = imgToSvgStr(
                        celImg, border, padding,
                        wScale, hScale, xCel, yCel,
                        palette)

                    local grpStr = string.format(
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
        local args = dlg.data
        local flat = args.flattenImage --[[@as boolean]]
        local state = args.frameTarget --[[@as string]]
        local isManual = state == "MANUAL"

        -- dlg:modify { id = "frameTarget", visible = flat }
        -- dlg:modify { id = "rangeStr", visible = flat and isManual }
        -- dlg:modify { id = "strExample", visible = false }
        -- dlg:modify { id = "useLoop", visible = flat }

        local notFlat = not flat
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
    -- visible = defaults.flattenImage,
    visible = false,
    onchange = function()
        local args = dlg.data
        local state = args.frameTarget --[[@as string]]
        local isManual = state == "MANUAL"
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
    -- visible = defaults.flattenImage
    --     and defaults.frameTarget == "MANUAL",
    visible = false,
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

dlg:check {
    id = "useLoop",
    label = "Loop:",
    text = "&Infinite",
    selected = defaults.useLoop,
    -- visible = defaults.flattenImage
    visible = false
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
        local args = dlg.data
        local border = args.border --[[@as integer]]
        local gtz = border > 0
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
        local args = dlg.data
        local padding = args.padding --[[@as integer]]
        local gtz = padding > 0
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
    id = "usePixelAspect",
    label = "Apply:",
    text = "Pi&xel Aspect",
    selected = defaults.usePixelAspect,
    visible = true
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
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        -- Unpack file path.
        local args = dlg.data
        local filepath = args.filepath --[[@as string]]
        if (not filepath) or (#filepath < 1) then
            app.alert { title = "Error", text = "Filepath is empty." }
            return
        end

        local ext = app.fs.fileExtension(filepath)
        if string.lower(ext) ~= "svg" then
            app.alert { title = "Error", text = "Extension is not svg." }
            return
        end

        -- Unpack arguments.
        local flattenImage = args.flattenImage --[[@as boolean]]
        local border = args.border
            or defaults.border --[[@as integer]]
        local borderClr = args.borderClr --[[@as Color]]
        local padding = args.padding
            or defaults.padding --[[@as integer]]
        local paddingClr = args.paddingClr --[[@as Color]]
        local scale = args.scale or defaults.scale --[[@as integer]]
        local usePixelAspect = args.usePixelAspect --[[@as boolean]]

        -- Process scale
        local wScale = scale
        local hScale = scale
        if usePixelAspect then
            local pxRatio = activeSprite.pixelRatio
            local pxw = math.max(1, math.abs(pxRatio.width))
            local pxh = math.max(1, math.abs(pxRatio.height))
            wScale = wScale * pxw
            hScale = hScale * pxh
        end

        local activeSpec = activeSprite.spec
        local colorMode = activeSpec.colorMode
        local wNative = activeSpec.width
        local hNative = activeSpec.height

        local wClip = wScale * wNative
            + padding * (wNative + 1)
        local hClip = hScale * hNative
            + padding * (hNative + 1)

        local wTotal = wClip + border + border
        local hTotal = hClip + border + border

        ---@type string[]
        local layersStrArr = {}
        if flattenImage then
            local frameTarget = args.frameTarget
                or defaults.frameTarget --[[@as string]]
            local rangeStr = args.rangeStr
                or defaults.rangeStr --[[@as string]]
            local chosenFrIdcs = Utilities.flatArr2(
                AseUtilities.getFrames(
                    activeSprite, frameTarget,
                    true, rangeStr))
            local lenChosenFrames = #chosenFrIdcs
            local animate = lenChosenFrames > 1

            if animate then
                local useLoop = args.useLoop --[[@as boolean]]

                local docPrefs = app.preferences.document(activeSprite)
                local frameUiOffset = docPrefs.timeline.first_frame - 1
                local spritePalettes = activeSprite.palettes
                local spriteFrames = activeSprite.frames
                local currentTime = 0.0

                local animBeginStr = "0s"
                if useLoop then
                    animBeginStr = string.format(
                        "0s;anim%03d.end",
                        lenChosenFrames)
                end

                -- Causes flickering in Mozilla Firefox.
                -- fill freeze|remove doesn't work.
                -- backface-visibility added to group style doesn't work.
                -- Might need to be a sequence of values where all but one
                -- are visible, with discrete calc mode.
                local frameFormat = table.concat({
                    "<g",
                    " id=\"frame%03d\"",
                    " visibility=\"hidden\"",
                    -- " display=\"none\"",
                    -- " opacity=\"0\"",
                    ">",
                    "<animate",
                    " id=\"anim%03d\"",
                    " attributeName=\"visibility\"",
                    " to=\"visible\"",
                    " begin=\"%s\"",
                    " dur=\"%s\"",
                    "/>%s</g>"
                })

                -- Cache methods used in loop.
                local strfmt = string.format
                local floor = math.floor
                local getPalette = AseUtilities.getPalette

                ---@type string[]
                local frameStrs = {}

                local i = 0
                while i < lenChosenFrames do
                    i = i + 1
                    local frIdx = chosenFrIdcs[i]
                    local frObj = spriteFrames[frIdx]
                    local duration = frObj.duration

                    -- Create image SVG string.
                    local flatImg = Image(activeSpec)
                    flatImg:drawSprite(activeSprite, frObj)
                    local palette = getPalette(frIdx, spritePalettes)
                    local imgStr = imgToSvgStr(
                        flatImg, border, padding,
                        wScale, hScale, 0, 0,
                        palette)

                    -- Create frame SVG string.
                    local durStr = "indefinite"
                    if useLoop or i < lenChosenFrames then
                        durStr = strfmt("%.6fs", duration)
                        -- Switching to milliseconds does not change flickering.
                        -- durStr = strfmt(
                        --     "%dms",
                        --     floor(duration * 1000.0 + 0.5))
                    end
                    local frameStr = strfmt(
                        frameFormat,
                        frameUiOffset + frIdx, i,
                        animBeginStr, durStr,
                        imgStr)
                    frameStrs[i] = frameStr

                    -- Update for next iteration in loop.
                    currentTime = currentTime + duration
                    animBeginStr = strfmt("anim%03d.end", i)
                end

                layersStrArr[1] = table.concat(frameStrs)
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

                local palette = AseUtilities.getPalette(
                    activeFrame, activeSprite.palettes)

                local flatImg = Image(activeSpec)
                flatImg:drawSprite(activeSprite, activeFrame)
                layersStrArr[1] = imgToSvgStr(
                    flatImg, border, padding,
                    wScale, hScale, 0, 0,
                    palette)
            end
        else
            local includeLocked = args.includeLocked --[[@as boolean]]
            local includeHidden = args.includeHidden --[[@as boolean]]
            local includeTiles = args.includeTiles --[[@as boolean]]
            local includeBkg = args.includeBkg --[[@as boolean]]

            local spriteBounds = activeSprite.bounds
            local spriteLayers = activeSprite.layers
            local lenSpriteLayers = #spriteLayers

            local activeFrame = site.frame
            if not activeFrame then
                app.alert {
                    title = "Error",
                    text = "There is no active frame."
                }
                return
            end

            local palette = AseUtilities.getPalette(
                activeFrame, activeSprite.palettes)

            local j = 0
            while j < lenSpriteLayers do
                j = j + 1
                local layer = spriteLayers[j]
                layerToSvgStr(
                    layer, activeFrame,
                    border, padding, wScale, hScale,
                    spriteBounds,
                    includeLocked,
                    includeHidden,
                    includeTiles,
                    includeBkg,
                    colorMode,
                    palette,
                    layersStrArr)
            end
        end

        local wnBorder = wTotal - border
        local hnBorder = hTotal - border

        local padStr = ""
        local aPadding = paddingClr.alpha
        if padding > 0 and aPadding > 0 then
            local webHex = paddingClr.red << 0x10
                | paddingClr.green << 0x08
                | paddingClr.blue

            local alphaStr = ""
            if aPadding < 0xff then
                alphaStr = string.format(
                    " fill-opacity=\"%.6f\"",
                    aPadding * 0.003921568627451)
            end

            -- Cut out a hole for each pixel (counter-clockwise).
            ---@type string[]
            local holeStrArr = {}
            local lenPixels = wNative * hNative
            local strfmt = string.format
            local i = 0
            while i < lenPixels do
                local y = i // wNative
                local x = i % wNative

                local x1mrg = border + (x + 1) * padding
                local y1mrg = border + (y + 1) * padding

                local ax = x1mrg + x * wScale
                local ay = y1mrg + y * hScale
                local bx = ax + wScale
                local by = ay + hScale

                i = i + 1
                holeStrArr[i] = strfmt(
                    "M %d %d L %d %d L %d %d L %d %d Z",
                    ax, ay, ax, by, bx, by, bx, ay)
            end

            padStr = string.format(
                "\n<path id=\"grid\" fill=\"#%06X\"%s "
                .. "d=\"M %d %d L %d %d L %d %d L %d %d Z %s\" />",
                webHex, alphaStr,
                border, border,
                wnBorder, border,
                wnBorder, hnBorder,
                border, hnBorder,
                table.concat(holeStrArr, " ")
            )
        end

        local borderStr = ""
        local aBorder = borderClr.alpha
        if border > 0 and aBorder > 0 then
            local webHex = borderClr.red << 0x10
                | borderClr.green << 0x08
                | borderClr.blue

            local alphaStr = ""
            if aBorder < 0xff then
                alphaStr = string.format(
                    " fill-opacity=\"%.6f\"",
                    aBorder * 0.003921568627451)
            end

            borderStr = string.format(
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

        local svgStr = table.concat({
            "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n",
            "<svg ",
            "xmlns=\"http://www.w3.org/2000/svg\" ",
            "xmlns:xlink=\"http://www.w3.org/1999/xlink\" ",
            "shape-rendering=\"crispEdges\" ",
            "stroke=\"none\" ",
            "preserveAspectRatio=\"xMidYMid slice\" ",
            string.format(
                "width=\"%d\" height=\"%d\" ",
                wTotal, hTotal),
            string.format(
                "viewBox=\"0 0 %d %d\">\n",
                wTotal, hTotal),
            table.concat(layersStrArr, "\n"),
            padStr,
            borderStr,
            "\n</svg>"
        })

        local file, err = io.open(filepath, "w")
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
dofile("../../support/aseutilities.lua")

local frameTargetOptions <const> = {
    "ACTIVE",
    "ALL",
    "MANUAL",
    "RANGE",
    "TAG"
}

local defaults <const> = {
    -- TODO: Option to include metadata?
    -- https://community.aseprite.org/t/general-exif-or-other-metadata-support/23830
    -- https://svgwg.org/svg2-draft/struct.html#MetadataElement
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
    roundPercent = 0,
    scale = 1,
    useChecker = false,
    usePixelAspect = true,
    lblReset = 100,
    lblBold = 5
}

local roundedRectFormat <const> = table.concat({
    "M %.3f %d ",
    "L %.3f %d ",
    "C %.3f %d %d %.3f %d %.3f ",
    "L %d %.3f ",
    "C %d %.3f %.3f %d %.3f %d ",
    "L %.3f %d ",
    "C %.3f %d %d %.3f %d %.3f ",
    "L %d %.3f ",
    "C %d %.3f %.3f %d %.3f %d ",
    "Z"
})

-- One decimal points are for the circle center,
-- which is the top left corner plus half the size.
local circleFormat <const> = table.concat({
    "M %.1f %d ",
    "C %.3f %d %d %.3f %d %.1f ",
    "C %d %.3f %.3f %d %.1f %d ",
    "C %.3f %d %d %.3f %d %.1f ",
    "C %d %.3f %.3f %d %.1f %d ",
    "Z"
})

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

---@param aIdx integer
---@param bIdx integer
---@param imgWidth integer
---@return boolean
local function comparator(aIdx, bIdx, imgWidth)
    local ay <const> = aIdx // imgWidth
    local by <const> = bIdx // imgWidth
    if ay < by then return true end
    if ay > by then return false end
    return (aIdx % imgWidth) < (bIdx % imgWidth)
end

---@param img Image image
---@param border integer border size
---@param padding integer margin size
---@param rounding number rounding
---@param wPixel integer scale width
---@param hPixel integer scale height
---@param xOff integer x offset
---@param yOff integer y offset
---@param palette Palette palette
---@param frIdx integer frame index
---@return string
---@return integer[]
---@return integer[][]
local function imgToSvgStr(
    img,
    border, padding, rounding,
    wPixel, hPixel, xOff, yOff,
    palette, frIdx)
    -- https://github.com/aseprite/aseprite/issues/3561
    -- SVGs displayed in Firefox and Inkscape have thin gaps between squares at
    -- fractional zoom levels, e.g., 133%. Subtracting an epsilon from the left
    -- edge and adding to the right edge interferes with margin, can cause other
    -- zooming artifacts. Creating a path for each color then using subpaths for
    -- each square diminishes issue.
    local strfmt <const> = string.format
    local tconcat <const> = table.concat
    local strbyte <const> = string.byte

    local imgSpec <const> = img.spec
    local imgWidth <const> = imgSpec.width
    local imgHeight <const> = imgSpec.height
    local colorMode <const> = imgSpec.colorMode
    local imgBytes <const> = img.bytes
    local imgbpp <const> = img.bytesPerPixel

    local wScalePad <const> = wPixel + padding
    local hScalePad <const> = hPixel + padding
    local imgArea <const> = imgWidth * imgHeight
    local borderPad <const> = border + padding
    local xOffFull <const> = xOff * wScalePad + borderPad
    local yOffFull <const> = yOff * hScalePad + borderPad
    local rk <const> = 0.55228474983079 * rounding
    local wHalf <const> = wPixel * 0.5
    local hHalf <const> = hPixel * 0.5
    local roundLtEq0 <const> = rounding <= 0.0
    local roundGtEq1 <const> = wPixel == hPixel
        and rounding >= math.min(wHalf, hHalf)
    local frIdxShifted <const> = ((frIdx - 1) & 0xff) << 0x20

    ---@type table<integer, integer[]>
    local pixelDict <const> = {}

    if colorMode == ColorMode.INDEXED then
        ---@type table<integer, integer>
        local clrIdxToHex <const> = {}
        local aseColorToHex <const> = AseUtilities.aseColorToHex
        local alphaIndex <const> = imgSpec.transparentColor
        local rgbColorMode <const> = ColorMode.RGB

        local i = 0
        while i < imgArea do
            local clrIdx <const> = strbyte(imgBytes, 1 + i)
            if clrIdx ~= alphaIndex then
                local hex = clrIdxToHex[clrIdx]
                if not hex then
                    hex = aseColorToHex(palette:getColor(clrIdx), rgbColorMode)
                    clrIdxToHex[clrIdx] = hex
                end

                if hex & 0xff000000 ~= 0 then
                    local idcs <const> = pixelDict[hex]
                    if idcs then
                        idcs[#idcs + 1] = i
                    else
                        pixelDict[hex] = { i }
                    end
                end
            end
            i = i + 1
        end
    elseif colorMode == ColorMode.GRAY then
        local i = 0
        while i < imgArea do
            local ibpp <const> = i * imgbpp
            local v <const>, a <const> = strbyte(imgBytes,
                1 + ibpp, imgbpp + ibpp)
            if a > 0 then
                local hex <const> = a << 0x18 | v << 0x10 | v << 0x08 | v

                local idcs <const> = pixelDict[hex]
                if idcs then
                    idcs[#idcs + 1] = i
                else
                    pixelDict[hex] = { i }
                end
            end
            i = i + 1
        end
    elseif colorMode == ColorMode.RGB then
        local i = 0
        while i < imgArea do
            local ibpp <const> = i * imgbpp
            local r <const>, g <const>, b <const>, a <const> = strbyte(
                imgBytes, 1 + ibpp, imgbpp + ibpp)
            if a > 0 then
                local hex <const> = a << 0x18 | b << 0x10 | g << 0x08 | r
                local idcs <const> = pixelDict[hex]
                if idcs then
                    idcs[#idcs + 1] = i
                else
                    pixelDict[hex] = { i }
                end
            end
            i = i + 1
        end
    end

    ---@type integer[]
    local hexArr <const> = {}
    ---@type integer[][]
    local idcsArr <const> = {}
    local lenUniques = 0
    for hex, idcs in pairs(pixelDict) do
        lenUniques = lenUniques + 1
        hexArr[lenUniques] = hex
        idcsArr[lenUniques] = idcs
    end

    table.sort(hexArr, function(a, b)
        return comparator(pixelDict[a][1], pixelDict[b][1], imgWidth)
    end)

    table.sort(idcsArr, function(a, b)
        return comparator(a[1], b[1], imgWidth)
    end)

    ---@type string[]
    local pathsArr <const> = {}
    local h = 0
    while h < lenUniques do
        h = h + 1
        local hex <const> = hexArr[h]
        local idcs <const> = idcsArr[h]

        ---@type string[]
        local subPathsArr <const> = {}
        local lenIdcs <const> = #idcs

        if roundLtEq0 then
            -- Draw a square.
            local i = 0
            while i < lenIdcs do
                i = i + 1
                local idx <const> = idcs[i]

                local x0 <const> = (idx % imgWidth) * wScalePad + xOffFull
                local y0 <const> = (idx // imgWidth) * hScalePad + yOffFull
                local x1 <const> = x0 + wPixel
                local y1 <const> = y0 + hPixel

                subPathsArr[i] = strfmt(
                    "M %d %d L %d %d L %d %d L %d %d Z",
                    x0, y0, x1, y0, x1, y1, x0, y1)
            end
        elseif roundGtEq1 then
            -- Draw a circle.
            local i = 0
            while i < lenIdcs do
                i = i + 1
                local idx <const> = idcs[i]

                local x0 <const> = (idx % imgWidth) * wScalePad + xOffFull
                local y0 <const> = (idx // imgWidth) * hScalePad + yOffFull
                local x1 <const> = x0 + wPixel
                local y1 <const> = y0 + hPixel
                local xc <const> = x0 + wHalf
                local yc <const> = y0 + hHalf

                subPathsArr[i] = strfmt(
                    circleFormat,
                    xc, y0,
                    xc + rk, y0, x1, yc - rk, x1, yc,
                    x1, yc + rk, xc + rk, y1, xc, y1,
                    xc - rk, y1, x0, yc + rk, x0, yc,
                    x0, yc - rk, xc - rk, y0, xc, y0)
            end
        else
            local i = 0
            while i < lenIdcs do
                i = i + 1
                local idx <const> = idcs[i]

                local x0 <const> = (idx % imgWidth) * wScalePad + xOffFull
                local y0 <const> = (idx // imgWidth) * hScalePad + yOffFull
                local x1 <const> = x0 + wPixel
                local y1 <const> = y0 + hPixel

                local x0In <const> = x0 + rounding
                local x1In <const> = x1 - rounding
                local y0In <const> = y0 + rounding
                local y1In <const> = y1 - rounding

                subPathsArr[i] = strfmt(
                    roundedRectFormat,
                    x0In, y0,
                    x1In, y0, x1In + rk, y0, x1, y0In - rk, x1, y0In,
                    x1, y1In, x1, y1In + rk, x1In + rk, y1, x1In, y1,
                    x0In, y1, x0In - rk, y1, x0, y1In + rk, x0, y1In,
                    x0, y0In, x0, y0In - rk, x0In - rk, y0, x0In, y0)
            end
        end

        local lenSubPaths <const> = #subPathsArr
        if lenSubPaths > 0 then
            local webHex <const> = (hex & 0xff) << 0x10
                | (hex & 0xff00)
                | (hex >> 0x10 & 0xff)

            local a <const> = hex >> 0x18 & 0xff
            local alphaStr <const> = a < 0xff
                and strfmt(" fill-opacity=\"%.3f\"", a / 255.0)
                or ""

            local id <const> = frIdxShifted | hex

            pathsArr[#pathsArr + 1] = strfmt(
                "<path id=\"%010x\" fill=\"#%06X\"%s d=\"%s\" />",
                id, webHex, alphaStr,
                tconcat(subPathsArr, " "))
        end
    end

    return tconcat(pathsArr, "\n"), hexArr, idcsArr
end

---@param id string
---@param hexArr integer[],
---@param idcsArr integer[],
---@param imgWidth integer
---@param border integer
---@param padding integer
---@param wScale integer
---@param hScale integer
---@param xOff integer
---@param yOff integer
---@return string
local function genLabelSvgStr(
    id, hexArr, idcsArr, imgWidth,
    border, padding,
    wScale, hScale,
    xOff, yOff)
    -- For cross stitch template generation. See
    -- https://steamcommunity.com/app/431730/discussions/0/4307201018694191898/
    -- https://flosscross.com/
    -- https://stitchfiddle.com/

    ---@type string[]
    local labelsArr <const> = {}
    local strfmt <const> = string.format
    local wScaleHalf <const> = wScale * 0.5
    local hScaleHalf <const> = hScale * 0.5
    local borderPad <const> = border + padding
    local wScalePad <const> = wScale + padding
    local hScalePad <const> = hScale + padding

    local labelsIdx = 0
    labelsIdx = labelsIdx + 1
    labelsArr[labelsIdx] = strfmt("\n<g id=\"%s\">", id)

    local lenUniques = math.min(#hexArr, #idcsArr)
    local h = 0
    while h < lenUniques do
        h = h + 1
        local hex <const> = hexArr[h]
        local idcs <const> = idcsArr[h]

        local hsi <const> = ((hex >> 0x10 & 0xff)
            + (hex >> 0x08 & 0xff)
            + (hex & 0xff)) / 3.0
        local webHex <const> = hsi > 127 and 0 or 0xffffff

        labelsIdx = labelsIdx + 1
        labelsArr[labelsIdx] = strfmt(
            "<g id=\"color%d\" fill=\"#%06X\">",
            h - 1, webHex)
        local lenIdcs <const> = #idcs
        local i = 0
        while i < lenIdcs do
            i = i + 1
            local idx <const> = idcs[i]
            local x0 <const> = xOff + (idx % imgWidth)
            local y0 <const> = yOff + (idx // imgWidth)

            local cx <const> = borderPad + x0 * wScalePad + wScaleHalf
            local cy <const> = borderPad + y0 * hScalePad + hScaleHalf

            local textStr <const> = strfmt(
                "<text id=\"pixel%d_%d_%d\" x=\"%.1f\" y=\"%.1f\">%d</text>",
                h - 1, x0, y0, cx, cy, h)

            labelsIdx = labelsIdx + 1
            labelsArr[labelsIdx] = textStr
        end
        labelsIdx = labelsIdx + 1
        labelsArr[labelsIdx] = "</g>"
    end
    labelsIdx = labelsIdx + 1
    labelsArr[labelsIdx] = "</g>"

    return table.concat(labelsArr, "\n")
end

---@param layer Layer
---@param frIdx integer
---@param border integer
---@param padding integer
---@param rounding number
---@param wPixel integer
---@param hPixel integer
---@param includeLocked boolean
---@param includeHidden boolean
---@param includeTiles boolean
---@param includeBkg boolean
---@param colorMode ColorMode
---@param palette Palette
---@param layersStrArr string[]
local function layerToSvgStr(
    layer, frIdx,
    border, padding, rounding,
    wPixel, hPixel,
    includeLocked, includeHidden,
    includeTiles, includeBkg,
    colorMode, palette,
    layersStrArr)
    local isEditable <const> = layer.isEditable
    local isVisible <const> = layer.isVisible

    if (includeLocked or isEditable)
        and (includeHidden or isVisible) then
        -- Possible for layer name to be empty string.
        local layerName = "layer"
        if layer.name and #layer.name > 0 then
            layerName = string.lower(Utilities.validateFilename(layer.name))
        end

        local visStr = ""
        if not isVisible then
            visStr = " visibility=\"hidden\""
        end

        local isGroup <const> = layer.isGroup
        local isTilemap <const> = layer.isTilemap

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
                        child, frIdx, border, padding, rounding, wPixel, hPixel,
                        includeLocked, includeHidden,
                        includeTiles, includeBkg, colorMode, palette,
                        childStrs)
                end

                local grpStr <const> = string.format(
                    "<g id=\"%s\"%s>\n%s\n</g>",
                    layerName, visStr, table.concat(childStrs, "\n"))
                layersStrArr[#layersStrArr + 1] = grpStr
            end
        elseif (not layer.isReference)
            and (includeTiles or (not isTilemap))
            and (includeBkg or (not layer.isBackground)) then
            local cel <const> = layer:cel(frIdx)
            if cel then
                -- A definition could be created for tile sets, then accessed
                -- with use xlink:href, but best to keep things simple for
                -- compatibility with Inkscape, Processing, Blender, etc.
                local celImg = cel.image
                if isTilemap then
                    celImg = AseUtilities.tileMapToImage(
                        celImg, layer.tileset, colorMode)
                end

                if not celImg:isEmpty() then
                    -- Layer opacity and cel opacity are compounded.
                    local lyrAlpha <const> = layer.opacity or 255
                    local celAlpha <const> = cel.opacity

                    local alphaStr = ""
                    if lyrAlpha < 0xff or celAlpha < 0xff then
                        local cmpAlpha <const> = (lyrAlpha / 255.0)
                            * (celAlpha / 255.0)
                        alphaStr = string.format(
                            " opacity=\"%.3f\"",
                            cmpAlpha)
                    end

                    -- feBlend seems more backward compatible, but inline
                    -- CSS style results in shorter code.
                    local bmStr <const> = blendModeToStr(layer.blendMode
                        or BlendMode.NORMAL)

                    local celPos <const> = cel.position
                    local xCel <const> = celPos.x
                    local yCel <const> = celPos.y

                    local imgStr <const>, _ <const>, _ <const> = imgToSvgStr(
                        celImg,
                        border, padding, rounding,
                        wPixel, hPixel, xCel, yCel,
                        palette, frIdx)

                    local grpStr <const> = string.format(
                        "<g id=\"%s\"%s style=\"mix-blend-mode: %s;\"%s>\n%s\n</g>",
                        layerName, visStr, bmStr, alphaStr, imgStr)
                    layersStrArr[#layersStrArr + 1] = grpStr
                end -- End image is not empty.
            end     -- End cel exists check.
        end         -- End isGroup branch.
    end             -- End isVisible and isEditable.
end

local dlg <const> = Dialog { title = "SVG Export" }

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
        local isActive <const> = state == "ACTIVE"
        local notFlat <const> = not flat

        dlg:modify { id = "frameTarget", visible = flat }
        dlg:modify { id = "rangeStr", visible = flat and isManual }
        dlg:modify { id = "strExample", visible = false }
        dlg:modify { id = "useLoop", visible = flat }
        dlg:modify { id = "timeScalar", visible = flat }
        dlg:modify { id = "useLabels", visible = flat and isActive }

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
        local flat <const> = args.flattenImage --[[@as boolean]]
        local state <const> = args.frameTarget --[[@as string]]
        local isManual <const> = state == "MANUAL"
        local isActive <const> = state == "ACTIVE"
        dlg:modify { id = "rangeStr", visible = isManual }
        dlg:modify { id = "strExample", visible = false }
        dlg:modify { id = "useLabels", visible = flat and isActive }
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
        local paddingClr <const> = args.paddingClr --[[@as Color]]
        dlg:modify { id = "paddingClr", visible = padding > 0 }
        dlg:modify { id = "roundPercent", visible = padding <= 0
            or paddingClr.alpha <= 0 }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "paddingClr",
    color = Color { r = 255, g = 255, b = 255 },
    visible = defaults.padding > 0,
    onchange = function()
        local args <const> = dlg.data
        local paddingClr <const> = args.paddingClr --[[@as Color]]
        dlg:modify { id = "roundPercent", visible = paddingClr.alpha <= 0 }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "roundPercent",
    label = "Rounding:",
    min = 0,
    max = 100,
    value = defaults.roundPercent,
    visible = defaults.padding <= 0
}

dlg:newrow { always = false }

dlg:check {
    id = "usePixelAspect",
    label = "Apply:",
    text = "Pi&xel Aspect",
    selected = defaults.usePixelAspect
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
    id = "useLabels",
    label = "Text:",
    text = "L&abels",
    selected = defaults.useLabels,
    visible = defaults.flattenImage
        and defaults.frameTarget == "ACTIVE"
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
        local frameTarget <const> = args.frameTarget
            or defaults.frameTarget --[[@as string]]
        local rangeStr <const> = args.rangeStr
            or defaults.rangeStr --[[@as string]]
        local flattenImage <const> = args.flattenImage --[[@as boolean]]
        local border <const> = args.border or defaults.border --[[@as integer]]
        local borderClr <const> = args.borderClr --[[@as Color]]
        local padding <const> = args.padding
            or defaults.padding --[[@as integer]]
        local paddingClr <const> = args.paddingClr --[[@as Color]]
        local roundPercent <const> = args.roundPercent
            or defaults.roundPercent --[[@as integer]]
        local scale <const> = args.scale or defaults.scale --[[@as integer]]
        local useChecker <const> = args.useChecker --[[@as boolean]]
        local usePixelAspect <const> = args.usePixelAspect --[[@as boolean]]
        local useLabels <const> = args.useLabels --[[@as boolean]]

        -- Process scale
        local wPixel = scale
        local hPixel = scale
        if usePixelAspect then
            local pxRatio <const> = activeSprite.pixelRatio
            wPixel = wPixel * math.max(1, math.abs(pxRatio.width))
            hPixel = hPixel * math.max(1, math.abs(pxRatio.height))
        end

        local aPadding <const> = paddingClr.alpha
        local usePadding <const> = padding > 0 and aPadding > 0
        local rdVerif = 0.0
        if not usePadding then
            local roundFac <const> = roundPercent * 0.01
            local shortEdge <const> = 0.5 * math.min(wPixel, hPixel)
            rdVerif = shortEdge * roundFac
        end

        -- Process space for labels
        local usePixelLabels <const> = useLabels
            and flattenImage
            and frameTarget == "ACTIVE"
        local useRowColLabels <const> = useLabels
        local wRowColLabel <const> = useRowColLabels and wPixel or 0
        local hRowColLabel <const> = useRowColLabels and hPixel or 0

        -- Unpack sprite spec.
        local activeSpec <const> = activeSprite.spec
        local colorMode <const> = activeSpec.colorMode
        local wNative <const> = activeSpec.width
        local hNative <const> = activeSpec.height

        -- Determine size of scaled image plus pixel padding, then the right
        -- edge facing the border, then the total dimension.
        local wClip <const> = wPixel * wNative + padding * (wNative + 1)
        local hClip <const> = hPixel * hNative + padding * (hNative + 1)
        local wnBorder <const> = wClip + border
        local hnBorder <const> = hClip + border
        local wTotal <const> = wnBorder + border
        local hTotal <const> = hnBorder + border
        local wViewBox <const> = wTotal + wRowColLabel
        local hViewBox <const> = hTotal + hRowColLabel

        -- Cache these methods because they are used so often
        local strfmt <const> = string.format
        local tconcat <const> = table.concat
        local getPalette <const> = AseUtilities.getPalette

        local defsStr = ""
        local checkerStr = ""
        if useChecker then
            local wCheck <const>,
            hCheck <const>,
            aAse <const>,
            bAse <const> = AseUtilities.getBkgChecker(activeSprite)

            local wCheckScaled <const> = wCheck * wPixel
            local hCheckScaled <const> = hCheck * hPixel
            local wcs2 <const> = wCheckScaled + wCheckScaled
            local hcs2 <const> = hCheckScaled + hCheckScaled

            local aWebHex <const> = aAse.red << 0x10
                | aAse.green << 0x08
                | aAse.blue

            local bWebHex <const> = bAse.red << 0x10
                | bAse.green << 0x08
                | bAse.blue

            local sqFmt <const> = "<path d=\"M %d %d L %d %d L %d %d L %d %d "
                .. "Z M %d %d L %d %d L %d %d L %d %d Z\" fill=\"#%06x\" />\n"
            defsStr = tconcat({
                "<defs>\n",
                strfmt(
                    "<pattern id=\"checkerPattern\" x=\"%d\" y=\"%d\" "
                    .. "width=\"%d\" height=\"%d\" patternUnits=\"%s\">\n",
                    border, border, wcs2, hcs2, "userSpaceOnUse"),
                strfmt(sqFmt, 0, 0, wCheckScaled, 0, wCheckScaled, hCheckScaled,
                    0, hCheckScaled, wCheckScaled, hCheckScaled, wcs2,
                    hCheckScaled, wcs2, hcs2, wCheckScaled, hcs2, aWebHex),
                strfmt(sqFmt, wCheckScaled, 0, wcs2, 0, wcs2, hCheckScaled,
                    wCheckScaled, hCheckScaled, 0, hCheckScaled, wCheckScaled,
                    hCheckScaled, wCheckScaled, hcs2, 0, hcs2, bWebHex),
                "</pattern>\n",
                "</defs>\n"
            })

            checkerStr = strfmt(
                "<path id =\"checker\" d=\"M %d %d L %d %d L %d %d L %d %d Z\" "
                .. "fill=\"url(#checkerPattern)\" />\n",
                border, border, wnBorder, border,
                wnBorder, hnBorder, border, hnBorder)
        end

        -- In indexed color mode, the transparent color is ignored when the
        -- sprite has a background color.
        local alphaIdxStr = ""
        if activeSprite.backgroundLayer ~= nil
            and colorMode == ColorMode.INDEXED then
            -- This poses a problem for animation, because the background
            -- color could change per multi-palette sprites.
            local alphaIdx <const> = activeSpec.transparentColor
            local palette1 <const> = getPalette(1, activeSprite.palettes)
            local lenPalette1 = #palette1

            local bkgHex = 0x0
            if alphaIdx >= 0 and alphaIdx < lenPalette1 then
                bkgHex = AseUtilities.aseColorToHex(
                    palette1:getColor(alphaIdx), ColorMode.RGB)
            end

            -- An indexed color mode sprite may contain a background, yet have
            -- translucent, or even transparent colors in its palette.
            if bkgHex & 0xff000000 ~= 0 then
                local webHex <const> = (bkgHex & 0xff) << 0x10
                    | (bkgHex & 0xff00)
                    | (bkgHex >> 0x10 & 0xff)
                local aBkg <const> = (bkgHex >> 0x18) & 0xff

                local alphaStr <const> = aBkg < 0xff
                    and strfmt(" fill-opacity=\"%.3f\"", aBkg / 255.0)
                    or ""

                local visStr <const> = activeSprite.backgroundLayer.isVisible
                    and ""
                    or " visibility=\"hidden\""

                alphaIdxStr = strfmt(
                    "<path id =\"bkg\"%s d=\"M %d %d L %d %d L %d %d L %d %d Z\" "
                    .. "fill=\"#%06X\"%s />\n",
                    visStr, border, border, wnBorder, border,
                    wnBorder, hnBorder, border, hnBorder,
                    webHex, alphaStr)
            end
        end

        ---@type string[]
        local layerStrsArr <const> = {}
        ---@type string[]
        local labelsStrArr <const> = {}
        if flattenImage then
            local chosenFrIdcs <const> = Utilities.flatArr2(
                AseUtilities.getFrames(
                    activeSprite, frameTarget, true, rangeStr))
            local lenChosenFrIdcs <const> = #chosenFrIdcs
            if lenChosenFrIdcs <= 0 then
                app.alert {
                    title = "Error",
                    text = "No frames were selected."
                }
                return
            end

            local animate <const> = lenChosenFrIdcs > 1
            if animate then
                local useLoop <const> = args.useLoop --[[@as boolean]]
                local timeScalar <const> = args.timeScalar
                    or defaults.timeScalar --[[@as number]]

                local docPrefs <const> = app.preferences.document(activeSprite)
                local tlPrefs <const> = docPrefs.timeline
                local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]
                local spritePalettes <const> = activeSprite.palettes
                local spriteFrames <const> = activeSprite.frames

                local animBeginStr = "0s"
                if useLoop then
                    animBeginStr = strfmt(
                        "0s;anim%d.end",
                        lenChosenFrIdcs)
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

                ---@type string[]
                local pixelFrameStrs <const> = {}

                local i = 0
                while i < lenChosenFrIdcs do
                    i = i + 1
                    local frIdx <const> = chosenFrIdcs[i]
                    local frObj <const> = spriteFrames[frIdx]
                    local duration <const> = frObj.duration

                    -- Create image SVG string.
                    local flatImg <const> = Image(activeSpec)
                    flatImg:drawSprite(activeSprite, frObj)
                    local palette <const> = getPalette(frIdx, spritePalettes)

                    -- It's not worth allowing pixel labels per frame because
                    -- the same color could have different indices per each
                    -- and a palette display on the side would also need to be
                    -- animated.
                    local imgStr <const>, _ <const>, _ <const> = imgToSvgStr(
                        flatImg,
                        border, padding, rdVerif,
                        wPixel, hPixel, 0, 0,
                        palette, frIdx)

                    -- Create frame SVG string.
                    local durStr = "indefinite"
                    if useLoop or i < lenChosenFrIdcs then
                        -- Before time scalar, only 3 decimals were needed
                        -- because duration was truncated from millis.
                        durStr = strfmt("%.6fs", timeScaleVrf * duration)
                    end
                    pixelFrameStrs[i] = strfmt(
                        frameFormat,
                        frameUiOffset + frIdx, i,
                        animBeginStr, durStr,
                        imgStr)

                    -- Update for next iteration in loop.
                    animBeginStr = strfmt("anim%d.end", i)
                end

                layerStrsArr[1] = tconcat(pixelFrameStrs, "\n")
            else
                local activeFrObj = site.frame
                if lenChosenFrIdcs > 0 then
                    activeFrObj = activeSprite.frames[chosenFrIdcs[1]]
                end
                if not activeFrObj then
                    app.alert {
                        title = "Error",
                        text = "There is no active frame."
                    }
                    return
                end

                local palette <const> = AseUtilities.getPalette(
                    activeFrObj, activeSprite.palettes)

                local flatImg <const> = Image(activeSpec)
                flatImg:drawSprite(activeSprite, activeFrObj)
                local layerStr <const>,
                hexArr <const>,
                idcsArr <const> = imgToSvgStr(
                    flatImg,
                    border, padding, rdVerif,
                    wPixel, hPixel, 0, 0,
                    palette, activeFrObj.frameNumber)
                layerStrsArr[1] = layerStr

                if usePixelLabels then
                    labelsStrArr[1] = genLabelSvgStr("pixellabels", hexArr, idcsArr,
                        flatImg.width, border, padding, wPixel, hPixel, 0, 0)
                end
            end
        else
            local includeLocked <const> = args.includeLocked --[[@as boolean]]
            local includeHidden <const> = args.includeHidden --[[@as boolean]]
            local includeTiles <const> = args.includeTiles --[[@as boolean]]
            local includeBkg <const> = args.includeBkg --[[@as boolean]]

            local spriteLayers <const> = activeSprite.layers
            local lenSpriteLayers <const> = #spriteLayers

            local activeFrObj <const> = site.frame
            if not activeFrObj then
                app.alert {
                    title = "Error",
                    text = "There is no active frame."
                }
                return
            end
            local activeFrIdx <const> = activeFrObj.frameNumber

            local palette <const> = AseUtilities.getPalette(
                activeFrObj, activeSprite.palettes)

            local j = 0
            while j < lenSpriteLayers do
                j = j + 1
                local layer <const> = spriteLayers[j]
                layerToSvgStr(
                    layer, activeFrIdx, border, padding, rdVerif,
                    wPixel, hPixel,
                    includeLocked, includeHidden, includeTiles,
                    includeBkg, colorMode, palette, layerStrsArr)
            end
        end

        local padStr = ""
        if usePadding then
            local webHex <const> = paddingClr.red << 0x10
                | paddingClr.green << 0x08
                | paddingClr.blue

            local alphaStr <const> = aPadding < 0xff
                and strfmt(" fill-opacity=\"%.3f\"", aPadding / 255.0)
                or ""

            local borderPad <const> = border + padding
            local wScalePad <const> = wPixel + padding
            local hScalePad <const> = hPixel + padding

            -- Cut out a hole for each pixel (counter-clockwise).
            ---@type string[]
            local holeStrArr <const> = {}
            local lenPixels <const> = wNative * hNative
            local i = 0
            while i < lenPixels do
                local x0 <const> = (i % wNative) * wScalePad + borderPad
                local y0 <const> = (i // wNative) * hScalePad + borderPad
                local x1 <const> = x0 + wPixel
                local y1 <const> = y0 + hPixel

                i = i + 1
                holeStrArr[i] = strfmt(
                    "M %d %d L %d %d L %d %d L %d %d Z",
                    x0, y0, x0, y1, x1, y1, x1, y0)
            end

            padStr = strfmt(
                "\n<path id=\"grid\" fill=\"#%06X\"%s "
                .. "d=\"M %d %d L %d %d L %d %d L %d %d Z %s\" />",
                webHex, alphaStr,
                border, border,
                wnBorder, border,
                wnBorder, hnBorder,
                border, hnBorder,
                tconcat(holeStrArr, " "))
        end

        local borderStr = ""
        local aBorder <const> = borderClr.alpha
        local useBorder <const> = border > 0 and aBorder > 0
        if useBorder then
            local webHex <const> = borderClr.red << 0x10
                | borderClr.green << 0x08
                | borderClr.blue

            local alphaStr <const> = aBorder < 0xff
                and strfmt(" fill-opacity=\"%.3f\"", aBorder / 255.0)
                or ""

            -- Round interior cut out of border if if rdVerif is
            -- greater than zero? Might not be worth it, since
            -- pixels on non-corner edges of border will show gaps.
            borderStr = strfmt(
                "\n<path id=\"border\" fill=\"#%06X\"%s "
                .. "d=\"M 0 0 L %d 0 L %d %d L 0 %d Z"
                .. " M %d %d L %d %d L %d %d L %d %d Z\" />",
                webHex, alphaStr,
                wTotal, wTotal,
                hTotal, hTotal,
                border, border,
                border, hnBorder,
                wnBorder, hnBorder,
                wnBorder, border)
        end

        if useRowColLabels then
            local lblReset <const> = defaults.lblReset
            local lblBold <const> = defaults.lblBold
            local borderPad <const> = border + padding
            local wPixelHalf <const> = wPixel * 0.5
            local hPixelHalf <const> = hPixel * 0.5
            local xRowLabel <const> = wnBorder + border + wPixelHalf
            local yColLabel <const> = hnBorder + border + hPixelHalf

            labelsStrArr[#labelsStrArr + 1] = "<g id=\"collabels\" fill=\"#000000\">"
            local j = 0
            while j < wNative do
                local x1mrg <const> = borderPad + j * padding
                local cx <const> = x1mrg + j * wPixel + wPixelHalf
                local fwStr <const> = j % lblBold == 0
                    and " font-weight=\"bold\""
                    or ""
                labelsStrArr[#labelsStrArr + 1] = strfmt(
                    "<text id=\"collabel%d\" x=\"%.1f\" y=\"%.1f\"%s>%d</text>",
                    j, cx, yColLabel, fwStr, j % lblReset)
                j = j + 1
            end
            labelsStrArr[#labelsStrArr + 1] = "</g>"

            -- Since these are on the bottom edge of the SVG, draw them after
            -- columns, so that elements are sorted top to bottom.
            labelsStrArr[#labelsStrArr + 1] = "<g id=\"rowlabels\" fill=\"#000000\">"
            local i = 0
            while i < hNative do
                local y1mrg <const> = borderPad + i * padding
                local cy <const> = y1mrg + i * hPixel + hPixelHalf
                local fwStr <const> = i % lblBold == 0
                    and " font-weight=\"bold\""
                    or ""
                labelsStrArr[#labelsStrArr + 1] = strfmt(
                    "<text id=\"rowlabel%d\" x=\"%.1f\" y=\"%.1f\"%s>%d</text>",
                    i, xRowLabel, cy, fwStr, i % lblReset)
                i = i + 1
            end
            labelsStrArr[#labelsStrArr + 1] = "</g>"
        end

        -- If there were any diagonal guidelines, then this shape rendering
        -- is no longer a suitable choice. However, geometricPrecision causes
        -- problems with background checker pattern.
        local renderHintStr = "shape-rendering=\"crispEdges\" "
        if (not useChecker) and (useLabels or rdVerif > 0.0) then
            renderHintStr = "shape-rendering=\"geometricPrecision\" "
        end

        -- Firefox has a minimum font size in its settings that may
        -- prevent text from displaying correctly.
        local fontSize <const> = math.max(1, math.min(wPixel, hPixel) * 0.5)
        local fontBlock <const> = useLabels
            and table.concat({ "font-family=\"sans-serif\" ",
                strfmt("font-size=\"%dpx\" ", fontSize),
                "text-anchor=\"middle\" ",
                "dominant-baseline=\"middle\" ", })
            or ""

        local svgStr <const> = tconcat({
            "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n",
            "<svg ",
            "xmlns=\"http://www.w3.org/2000/svg\" ",
            "xmlns:xlink=\"http://www.w3.org/1999/xlink\" ",
            renderHintStr,
            "stroke=\"none\" ",
            fontBlock,
            "preserveAspectRatio=\"xMidYMid slice\" ",
            strfmt(
                "width=\"%d\" height=\"%d\" ",
                wViewBox, hViewBox),
            strfmt(
                "viewBox=\"0 0 %d %d\">\n",
                wViewBox, hViewBox),
            defsStr,
            checkerStr,
            alphaIdxStr,
            tconcat(layerStrsArr, "\n"),
            padStr,
            borderStr,
            tconcat(labelsStrArr, "\n"),
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

        local colorSpace <const> = activeSpec.colorSpace
        if colorSpace ~= ColorSpace { sRGB = true }
            and colorSpace ~= ColorSpace() then
            app.alert {
                title = "Warning",
                text = {
                    "SVGs are not color managed.",
                    "Exported color may differ from original."
                }
            }
        else
            app.alert { title = "Success", text = "File exported." }
        end
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

dlg:show {
    autoscrollbars = true,
    wait = false
}
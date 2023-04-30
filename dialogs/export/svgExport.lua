dofile("../../support/aseutilities.lua")

local defaults = {
    scale = 1,
    margin = 0,
    border = 0,
    prApply = false,
    flattenImage = true
}

---
---@param bm BlendMode|integer blend mode
---@return string
local function blendModeToStr(bm)
    -- The blend mode for group layers is nil.
    if bm then
        -- As of v1.3, blend mode normal reports as
        -- SRC-OVER. CSS does not support addition,
        -- subtract or divide.
        if bm == BlendMode.NORMAL
            or bm == BlendMode.ADDITION
            or bm == BlendMode.SUBTRACT
            or bm == BlendMode.DIVIDE then
            return "normal"
        end

        local bmStr = "normal"
        for k, v in pairs(BlendMode) do
            if bm == v then
                bmStr = k
                break
            end
        end
        bmStr = string.gsub(string.lower(bmStr), "_", "-")

        -- No HSL prefix in CSS.
        if string.sub(bmStr, 1, 3) == "hsl" then
            bmStr = string.sub(bmStr, 5)
        end

        return bmStr
    else
        return "normal"
    end
end

---
---@param img Image image
---@param border integer border size
---@param margin integer margin size
---@param scale integer scale
---@param xOff integer x offset
---@param yOff integer y offset
---@return string
local function imgToSvgStr(img, border, margin, scale, xOff, yOff)
    -- https://github.com/aseprite/aseprite/issues/3561
    -- SVGs displayed in Firefox and Inkscape have thin gaps
    -- between squares at fractional zoom levels, e.g., 133%.
    -- Subtracting an epsilon from the left edge and adding to
    -- the right edge interferes with margin, can cause other
    -- zooming artifacts. Creating a path for each color
    -- then using subpaths for each square diminishes issue.
    local strfmt = string.format
    local tconcat = table.concat

    local imgWidth = img.width
    local pxItr = img:pixels()
    ---@type table<integer, integer[]>
    local pixelDict = {}
    for pixel in pxItr do
        local hex = pixel()
        if hex & 0xff000000 ~= 0 then
            local idx = pixel.x + pixel.y * imgWidth
            local idcs = pixelDict[hex]
            if idcs then
                pixelDict[hex][#idcs + 1] = idx
            else
                pixelDict[hex] = { idx }
            end
        end
    end

    ---@type string[]
    local pathsArr = {}
    for hex, idcs in pairs(pixelDict) do
        local a = hex >> 0x18 & 0xff

        local pathStr = strfmt(
            "\n<path id=\"%08x\" ", hex)
        if a < 0xff then
            pathStr = pathStr .. strfmt(
                "fill-opacity=\"%.6f\" ",
                a * 0.003921568627451)
        end
        pathStr = pathStr .. strfmt(
            "fill=\"#%06X\" d=\"",
            ((hex & 0xff) << 0x10
                | (hex & 0xff00)
                | (hex >> 0x10 & 0xff)))

        ---@type string[]
        local subPathsArr = {}
        local lenIdcs = #idcs
        local i = 0
        while i < lenIdcs do
            i = i + 1
            local idx = idcs[i]
            local x0 = xOff + (idx % imgWidth)
            local y0 = yOff + (idx // imgWidth)

            local x1mrg = border + (x0 + 1) * margin
            local y1mrg = border + (y0 + 1) * margin

            local ax = x1mrg + x0 * scale
            local ay = y1mrg + y0 * scale
            local bx = ax + scale
            local by = ay + scale

            subPathsArr[i] = strfmt(
                "M %d %d L %d %d L %d %d L %d %d Z",
                ax, ay, bx, ay, bx, by, ax, by)

            -- More compressed version:
            -- subPathsArr[i] = strfmt(
            --     "M%d %dh%dv%dh%dv%dZ",
            --     ax, ay, scale, scale, -scale, -scale)
        end

        pathStr = pathStr
            .. (tconcat(subPathsArr, ' ') .. "\" />")
        pathsArr[#pathsArr + 1] = pathStr
    end

    return tconcat(pathsArr)
end

---
---@param layer Layer layer
---@param frame Frame frame
---@param spriteBounds Rectangle sprite bounds
---@param border integer border size
---@param scale integer scale
---@param margin integer margin size
---@return string
local function layerToSvgStr(
    layer, frame, spriteBounds,
    border, scale, margin)
    local str = ""

    local lyrAlpha = 0xff
    local isGroup = layer.isGroup
    if not isGroup then
        lyrAlpha = layer.opacity
    end

    if layer.isVisible and lyrAlpha > 0 then
        -- Possible for layer name to be empty string.
        local layerName = "Layer"
        if layer.name and #layer.name > 0 then
            layerName = Utilities.validateFilename(layer.name)
        end

        if isGroup then
            local grpStr = string.format(
                "\n<g id=\"%s\">", layerName)

            local groupLayers = layer.layers --[[@as Layer[] ]]
            local lenGroupLayers = #groupLayers
            ---@type string[]
            local groupStrArr = {}
            local i = 0
            while i < lenGroupLayers do
                i = i + 1
                groupStrArr[i] = layerToSvgStr(
                    groupLayers[i],
                    frame, spriteBounds,
                    border, scale, margin)
            end

            grpStr = grpStr .. (table.concat(groupStrArr) .. "\n</g>")
            str = str .. grpStr
        else
            local cel = layer:cel(frame)
            if cel then
                local celImg = cel.image
                if layer.isTilemap then
                    celImg = AseUtilities.tilesToImage(
                        celImg, layer.tileset, ColorMode.RGB)
                end

                local celBounds = cel.bounds
                local xCel = celBounds.x
                local yCel = celBounds.y
                local intersect = celBounds:intersect(spriteBounds)
                intersect.x = intersect.x - xCel
                intersect.y = intersect.y - yCel

                -- feBlend seems more backward compatible, but inline
                -- CSS style results in shorter code.
                local bmStr = blendModeToStr(layer.blendMode)
                local grpStr = string.format(
                    "\n<g id=\"%s\" style=\"mix-blend-mode: %s;\"",
                    layerName, bmStr)

                -- Layer opacity and cel opacity are compounded.
                local celAlpha = cel.opacity
                if lyrAlpha < 0xff or celAlpha < 0xff then
                    local cmpAlpha = (lyrAlpha * 0.003921568627451)
                        * (celAlpha * 0.003921568627451)
                    grpStr = grpStr .. string.format(
                        " opacity=\"%.6f\"",
                        cmpAlpha)
                end

                grpStr = grpStr .. ">"

                grpStr = grpStr .. imgToSvgStr(
                    celImg, border, margin, scale,
                    xCel, yCel)

                grpStr = grpStr .. "\n</g>"
                str = str .. grpStr
            end
        end
    end

    return str
end

local dlg = Dialog { title = "SVG Export" }

dlg:slider {
    id = "scale",
    label = "Scale:",
    min = 1,
    max = 64,
    value = defaults.border
}

dlg:newrow { always = false }

dlg:slider {
    id = "margin",
    label = "Px Grid:",
    min = 0,
    max = 64,
    value = defaults.margin,
    onchange = function()
        local gtz = dlg.data.margin > 0
        dlg:modify { id = "marginClr", visible = gtz }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "marginClr",
    color = Color { r = 255, g = 255, b = 255 },
    visible = defaults.margin > 0
}

dlg:newrow { always = false }

dlg:slider {
    id = "border",
    label = "Border:",
    min = 0,
    max = 64,
    value = defaults.border,
    onchange = function()
        local gtz = dlg.data.border > 0
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

dlg:check {
    id = "prApply",
    label = "Apply:",
    text = "Pixel Aspect",
    selected = defaults.prApply
}

dlg:newrow { always = false }

dlg:check {
    id = "flattenImage",
    label = "Flatten:",
    selected = defaults.flattenImage
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
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

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

        local oldColorMode = activeSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

        -- Unpack arguments.
        local scale = args.scale or defaults.scale --[[@as integer]]
        local margin = args.margin or defaults.margin --[[@as integer]]
        local marginClr = args.marginClr --[[@as Color]]
        local border = args.border or defaults.border --[[@as integer]]
        local borderClr = args.borderClr --[[@as Color]]
        local prApply = args.prApply --[[@as boolean]]
        local flattenImage = args.flattenImage --[[@as boolean]]

        -- Calculate dimensions.
        local nativeWidth = activeSprite.width
        local nativeHeight = activeSprite.height
        local lenPixels = nativeWidth * nativeHeight
        local scaledWidth = nativeWidth * scale
        local scaledHeight = nativeHeight * scale
        local totalWidth = scaledWidth
            + (nativeWidth + 1) * margin
            + border * 2
        local totalHeight = scaledHeight
            + (nativeHeight + 1) * margin
            + border * 2

        local wAspSclr = 1
        local hAspSclr = 1
        local preserveAspectStr = "preserveAspectRatio=\"xMidYMid slice\" "
        if prApply then
            local pxRatio = activeSprite.pixelRatio
            local pxw = math.max(1, math.abs(pxRatio.width))
            local pxh = math.max(1, math.abs(pxRatio.height))
            if pxw > pxh then hAspSclr = pxw / pxh end
            if pxh > pxw then wAspSclr = pxh / pxw end
            preserveAspectStr = "preserveAspectRatio=\"none\" "
        end

        -- Cache any methods used in for loops.
        local strfmt = string.format
        local concat = table.concat
        local str = concat({
            "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n",
            "<svg ",
            "xmlns=\"http://www.w3.org/2000/svg\" ",
            "xmlns:xlink=\"http://www.w3.org/1999/xlink\" ",
            "shape-rendering=\"crispEdges\" ",
            "stroke=\"none\" ",
            preserveAspectStr,
            strfmt("width=\"%d\" height=\"%d\" ",
                totalWidth, totalHeight),
            strfmt("viewBox=\"0 0 %.4f %.4f\">",
                wAspSclr * totalWidth,
                hAspSclr * totalHeight)
        })

        -- Each path element can contain sub-paths set off by Z (close)
        -- and M (move to) commands.
        local wnBorder = totalWidth - border
        local hnBorder = totalHeight - border
        if border > 0 and borderClr.alpha > 0 then
            -- Create outer frame of border (clockwise).
            str = str .. strfmt(
                "\n<path id=\"border\" d=\"M 0 0 L %d 0 L %d %d L 0 %d Z ",
                totalWidth, totalWidth, totalHeight, totalHeight)

            -- Cut out inner frame of border (counter-clockwise).
            str = str .. strfmt(
                "M %d %d L %d %d L %d %d L %d %d Z\" ",
                border, border,
                border, hnBorder,
                wnBorder, hnBorder,
                wnBorder, border)

            if borderClr.alpha < 255 then
                str = str .. strfmt(
                    "fill-opacity=\"%.6f\" ",
                    borderClr.alpha * 0.003921568627451)
            end

            str = str .. strfmt(
                "fill=\"#%06X\" />",
                borderClr.red << 0x10
                | borderClr.green << 0x08
                | borderClr.blue)
        end

        if margin > 0 and marginClr.alpha > 0 then
            -- Create outer frame of margins (clockwise).
            str = str .. strfmt(
                "\n<path id=\"margins\" d=\"M %d %d L %d %d L %d %d L %d %d Z",
                border, border,
                wnBorder, border,
                wnBorder, hnBorder,
                border, hnBorder)

            -- Cut out a hole for each pixel (counter-clockwise).
            ---@type string[]
            local holeStrArr = {}
            local i = 0
            while i < lenPixels do
                local y = i // nativeWidth
                local x = i % nativeWidth

                local x1mrg = border + (x + 1) * margin
                local y1mrg = border + (y + 1) * margin

                local ax = x1mrg + x * scale
                local ay = y1mrg + y * scale
                local bx = ax + scale
                local by = ay + scale

                i = i + 1
                holeStrArr[i] = strfmt(
                    " M %d %d L %d %d L %d %d L %d %d Z",
                    ax, ay, ax, by, bx, by, bx, ay)
            end

            str = str .. concat(holeStrArr)
            str = str .. "\" "

            if marginClr.alpha < 255 then
                str = str .. strfmt(
                    "fill-opacity=\"%.6f\" ",
                    marginClr.alpha * 0.003921568627451)
            end

            str = str .. strfmt(
                "fill=\"#%06X\" />",
                marginClr.red << 0x10
                | marginClr.green << 0x08
                | marginClr.blue)
        end

        local activeFrame = app.activeFrame --[[@as Frame]]

        if flattenImage then
            local flatImg = Image(nativeWidth, nativeHeight)
            flatImg:drawSprite(activeSprite, activeFrame)
            str = str .. imgToSvgStr(flatImg, border, margin, scale, 0, 0)
        else
            local spriteBounds = Rectangle(
                0, 0, nativeWidth, nativeHeight)
            local spriteLayers = activeSprite.layers
            ---@type string[]
            local layersStrArr = {}
            local lenSpriteLayers = #spriteLayers
            local j = 0
            while j < lenSpriteLayers do
                j = j + 1
                local spriteLayer = spriteLayers[j]

                layersStrArr[j] = layerToSvgStr(
                    spriteLayer,
                    activeFrame, spriteBounds,
                    border, scale, margin)
            end
            str = str .. concat(layersStrArr)
        end

        str = str .. "\n</svg>"

        local file, err = io.open(filepath, "w")
        if file then
            file:write(str)
            file:close()
        end

        AseUtilities.changePixelFormat(oldColorMode)
        app.refresh()

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
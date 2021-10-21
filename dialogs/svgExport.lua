local defaults = {
    scale = 1,
    margin = 0,
    marginClr = Color(0, 0, 0, 255),
    border = 0,
    borderClr = Color(255, 255, 255, 255),
    pullFocus = false
}

local function layerToSvgStr(
    layer, activeFrame, spriteBounds,
    border, scale, margin)

    local str = ""
    local lyrAlpha = layer.opacity
    if layer.isVisible and lyrAlpha > 0 then
        if layer.isGroup then
            local grpStr = string.format(
                "\n<g id=\"%s\">",
                layer.name)

            local groupLayers = layer.layers
            local groupLayersLen = #groupLayers
            local groupStrArr = {}
            for i = 1, groupLayersLen, 1 do
                    groupStrArr[i] = layerToSvgStr(
                        groupLayers[i],
                        activeFrame,
                        spriteBounds,
                        border, scale, margin)
            end

            grpStr = grpStr .. table.concat(groupStrArr)
            grpStr = grpStr .. "\n</g>"
            str = str .. grpStr
        else
            local cel = layer:cel(activeFrame)
            if cel then
                local celImg = cel.image
                if celImg then

                    -- Cache functions used in for loop.
                    local strfmt = string.format
                    local append = table.insert

                    local celBounds = cel.bounds
                    local xCel = celBounds.x
                    local yCel = celBounds.y
                    local intersect = celBounds:intersect(spriteBounds)
                    intersect.x = intersect.x - xCel
                    intersect.y = intersect.y - yCel
                    local imgItr = celImg:pixels(intersect)

                    local grpStr = strfmt(
                        "\n<g id=\"%s\"",
                        layer.name)

                    -- Layer opacity and cel opacity are compounded
                    -- together to simplify.
                    local celAlpha = cel.opacity
                    if lyrAlpha < 0xff
                        or celAlpha < 0xff then
                        local cmpAlpha = (lyrAlpha * 0.00392156862745098)
                            * (celAlpha * 0.00392156862745098)
                        grpStr = grpStr .. strfmt(
                            " opacity=\"%.6f\"",
                            cmpAlpha)
                    end

                    grpStr = grpStr .. ">"

                    local pathStrArr = {}
                    for elm in imgItr do
                        local hex = elm()
                        local a = hex >> 0x18 & 0xff
                        if a > 0 then
                            local x0 = xCel + elm.x
                            local y0 = yCel + elm.y

                            local x1mrg = border + (x0 + 1) * margin
                            local y1mrg = border + (y0 + 1) * margin

                            local ax = x1mrg + x0 * scale
                            local ay = y1mrg + y0 * scale
                            local bx = ax + scale
                            local by = ay + scale

                            local pathStr = strfmt(
                                "\n<path d=\"M %d %d L %d %d L %d %d L %d %d Z\" ",
                                ax, ay, bx, ay, bx, by, ax, by)

                            if a < 255 then
                                pathStr = pathStr .. strfmt(
                                    "fill-opacity=\"%.6f\" ",
                                    a * 0.00392156862745098)
                            end

                            -- Green does not need to be unpacked from the
                            -- hexadecimal because its order is unchanged.
                            pathStr = pathStr .. strfmt(
                                "fill=\"#%06X\" />",
                                ((hex & 0xff) << 0x10
                                    | (hex & 0xff00)
                                    | (hex >> 0x10 & 0xff)))
                            append(pathStrArr, pathStr)
                        end
                    end

                    grpStr = grpStr .. table.concat(pathStrArr)
                    grpStr = grpStr .. "\n</g>"
                    str = str .. grpStr
                end
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
    label = "Margin:",
    min = 0,
    max = 64,
    value = defaults.border
}

dlg:newrow { always = false }

dlg:color {
    id = "marginClr",
    color = defaults.marginClr
}

dlg:newrow { always = false }

dlg:slider {
    id = "border",
    label = "Border:",
    min = 0,
    max = 64,
    value = defaults.border
}

dlg:newrow { always = false }

dlg:color {
    id = "borderClr",
    color = defaults.borderClr
}

dlg:newrow { always = false }

dlg:file {
    id = "filepath",
    label = "Path:",
    filetypes = { "svg" },
    save = true
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if activeSprite then
            local oldColorMode = activeSprite.colorMode
            app.command.ChangePixelFormat { format = "rgb" }

            -- Collect inputs.
            local args = dlg.data
            local scale = args.scale or defaults.scale
            local border = args.border or defaults.border
            local borderClr = args.borderClr or defaults.borderClr
            local margin = args.margin or defaults.margin
            local marginClr = args.marginClr or defaults.marginClr

            -- Calculate dimensions.
            local nativeWidth = activeSprite.width
            local nativeHeight = activeSprite.height
            local pixelLen = nativeWidth * nativeHeight
            local scaledWidth = nativeWidth * scale
            local scaledHeight = nativeHeight * scale
            local totalWidth = scaledWidth
                + (nativeWidth + 1) * margin
                + border * 2
            local totalHeight = scaledHeight
                + (nativeHeight + 1) * margin
                + border * 2

            -- Cache any methods used in for loops.
            local strfmt = string.format

            local str = ""
            str = str .. "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n"
            str = str .. "<svg "
            str = str .. "xmlns=\"http://www.w3.org/2000/svg\" "
            str = str .. "xmlns:xlink=\"http://www.w3.org/1999/xlink\" "
            str = str .. "shape-rendering=\"crispEdges\" "
            str = str .. "stroke=\"none\" "
            str = str .. strfmt("width=\"%d\" height=\"%d\" ",
                totalWidth, totalHeight)
            str = str .. strfmt("viewBox=\"0 0 %d %d\">",
                totalWidth, totalHeight)

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
                        borderClr.alpha * 0.00392156862745098)
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
                local holeStrArr = {}
                for i = 0, pixelLen - 1, 1 do
                    local y = i // nativeWidth
                    local x = i % nativeWidth

                    local x1mrg = border + (x + 1) * margin
                    local y1mrg = border + (y + 1) * margin

                    local ax = x1mrg + x * scale
                    local ay = y1mrg + y * scale
                    local bx = ax + scale
                    local by = ay + scale

                    holeStrArr[1 + i] = strfmt(
                        " M %d %d L %d %d L %d %d L %d %d Z",
                        ax, ay, ax, by, bx, by, bx, ay)
                end

                str = str .. table.concat(holeStrArr)
                str = str .. "\" "

                if marginClr.alpha < 255 then
                    str = str .. strfmt(
                        "fill-opacity=\"%.6f\" ",
                        marginClr.alpha * 0.00392156862745098)
                end

                str = str .. strfmt(
                    "fill=\"#%06X\" />",
                    marginClr.red << 0x10
                        | marginClr.green << 0x08
                        | marginClr.blue)
            end

            local activeFrame = app.activeFrame
            local spriteBounds = Rectangle(
                0, 0, nativeWidth, nativeHeight)
            local spriteLayers = activeSprite.layers

            local layersStrArr = {}
            local spriteLayersLen = #spriteLayers
            for i = 1, spriteLayersLen, 1 do
                layersStrArr[i] = layerToSvgStr(
                    spriteLayers[i],
                    activeFrame,
                    spriteBounds,
                    border, scale, margin)
            end

            str = str .. table.concat(layersStrArr)
            str = str .. "\n</svg>"

            local filepath = args.filepath
            if filepath and #filepath > 0 then
                -- app.fs.isFile doesn't apply to files
                -- that have been typed in by the user,
                -- but have not yet been created.
                local ext = app.fs.fileExtension(filepath)
                if ext ~= "svg" then
                    app.alert("Extension is not svg.")
                else
                    local file = io.open(filepath, "w")
                    file:write(str)
                    file:close()
                end
            else
                app.alert("Filepath is empty.")
            end

            if oldColorMode == ColorMode.INDEXED then
                app.command.ChangePixelFormat { format = "indexed" }
            elseif oldColorMode == ColorMode.GRAY then
                app.command.ChangePixelFormat { format = "gray" }
            end

            app.refresh()
            dlg:close()
        else
            app.alert("There is no active sprite.")
        end
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }

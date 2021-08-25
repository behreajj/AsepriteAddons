local defaults = {
    scale = 1,
    margin = 0,
    marginClr = Color(0, 0, 0, 255),
    border = 0,
    borderClr = Color(255, 255, 255, 255),
    pullFocus = false
}

local function layerToSvgStr(layer, activeFrame, spriteBounds, border, scale, margin)
    local str = ""

    if layer.isVisible then
        if layer.isGroup then
            local grpStr = string.format(
                "\n<g id=\"%s\">",
                layer.name)

            -- Do these need to be sorted for draw order??
            local groupLayers = {}
            for i = 1, #layer.layers, 1 do
                groupLayers[i] = layer.layers[i]
            end

            -- table.sort(groupLayers, function(a, b)
            --     if a.isGroup and not b.isGroup then return false end
            --     if b.isGroup and not a.isGroup then return true end
            --     return a.stackIndex > b.stackIndex
            -- end)

            local groupLayersLen = #groupLayers
            for i = 1, groupLayersLen, 1 do
                    grpStr = grpStr .. layerToSvgStr(
                        groupLayers[i],
                        activeFrame,
                        spriteBounds,
                        border, scale, margin)
            end

            grpStr = grpStr .. "\n</g>"
            str = str .. grpStr
        else
            local cel = layer:cel(activeFrame)
            if cel then
                local celImg = cel.image
                if celImg then
                    local celBounds = cel.bounds
                    local xCel = celBounds.x
                    local yCel = celBounds.y
                    local intersect = celBounds:intersect(spriteBounds)

                    intersect.x = intersect.x - xCel
                    intersect.y = intersect.y - yCel
                    local imgItr = celImg:pixels(intersect)

                    local grpStr = string.format(
                        "\n<g id=\"%s\" opacity=\"%.6f\">",
                        layer.name, layer.opacity / 255.0)

                    for elm in imgItr do
                        local hex = elm()
                        local a = hex >> 0x18 & 0xff
                        if a > 0 then
                            local xPixel = elm.x
                            local yPixel = elm.y

                            local x0 = xCel + xPixel
                            local y0 = yCel + yPixel
                            local y1 = y0 + 1
                            local x1 = x0 + 1

                            local x0scl = x0 * scale
                            local y0scl = y0 * scale
                            local x1scl = x1 * scale
                            local y1scl = y1 * scale

                            local x1mrg = x1 * margin
                            local y1mrg = y1 * margin

                            grpStr = grpStr .. string.format(
                                "\n<path d=\"M %d %d L %d %d L %d %d L %d %d Z\" ",
                                border + x0scl + x1mrg,
                                border + y0scl + y1mrg,

                                border + x1scl + x1mrg,
                                border + y0scl + y1mrg,

                                border + x1scl + x1mrg,
                                border + y1scl + y1mrg,

                                border + x0scl + x1mrg,
                                border + y1scl + y1mrg)

                            if a < 255 then
                                grpStr = grpStr .. string.format(
                                    "fill-opacity=\"%.6f\" ",
                                    a / 255.0)
                            end

                            --There should be a more efficient way to do this.
                            --https://stackoverflow.com/questions/12304848/fast-algorithm-to-invert-an-argb-color-value-to-abgr
                            local b = hex >> 0x10 & 0xff
                            local g = hex >> 0x08 & 0xff
                            local r = hex & 0xff

                            grpStr = grpStr .. string.format(
                                "fill=\"#%06X\" />",
                                (r << 0x10 | g << 0x08 | b))
                        end
                    end

                    grpStr = grpStr .. "\n</g>"
                    str = str .. grpStr
                end
            end
        end
    end

    return str
end

local dlg = Dialog {
    title = "SVG Export"
}

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
    filetypes = { "gpl" },
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

            local args = dlg.data
            local scale = args.scale or defaults.scale
            local border = args.border or defaults.border
            local borderClr = args.borderClr or defaults.borderClr
            local margin = args.margin or defaults.margin
            local marginClr = args.marginClr or defaults.marginClr

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

            local str = "<svg "
            str = str .. "xmlns=\"http://www.w3.org/2000/svg\" "
            str = str .. "xmlns:xlink=\"http://www.w3.org/1999/xlink\" "
            str = str .. "shape-rendering=\"crispEdges\" "
            str = str .. "stroke=\"none\" "
            str = str .. string.format("width=\"%d\" ", totalWidth)
            str = str .. string.format("height=\"%d\" ", totalHeight)
            str = str .. string.format("viewBox=\"0 0 %d %d\">",
                totalWidth, totalHeight)

            -- TODO: Add opaque background option?

            if border > 0 and borderClr.alpha > 0 then
                -- Create outer frame of border (clockwise).
                str = str .. string.format(
                    "\n<path id=\"border\" d=\"M 0 0 L %d 0 L %d %d L 0 %d Z ",
                    totalWidth, totalWidth, totalHeight, totalHeight)
                -- Cut out inner frame of border (counter-clockwise).
                str = str .. string.format(
                    "M %d %d L %d %d L %d %d L %d %d Z\" ",
                    border, border,
                    border, totalHeight - border,
                    totalWidth - border, totalHeight - border,
                    totalWidth - border, border)

                if borderClr.alpha < 255 then
                    str = str .. string.format(
                        "fill-opacity=\"%.6f\" ",
                        borderClr.alpha / 255.0)
                end

                str = str .. string.format(
                    "fill=\"#%06X\" />",
                    (borderClr.red << 0x10
                    | borderClr.green << 0x08
                    | borderClr.blue))
            end

            if margin > 0 and marginClr.alpha > 0 then
                -- Create outer frame of margins (clockwise).
                str = str .. string.format(
                    "\n<path id=\"margins\" d=\"M %d %d L %d %d L %d %d L %d %d Z",
                    border, border,
                    totalWidth - border, border,
                    totalWidth - border, totalHeight - border,
                    border, totalHeight - border)

                -- Cut out a hole for each pixel (counter-clockwise).
                for i = 0, pixelLen - 1, 1 do
                    local y0 = i // nativeWidth
                    local x0 = i % nativeWidth
                    local y1 = y0 + 1
                    local x1 = x0 + 1

                    local x0scl = x0 * scale
                    local y0scl = y0 * scale
                    local x1scl = x1 * scale
                    local y1scl = y1 * scale

                    local x1mrg = x1 * margin
                    local y1mrg = y1 * margin

                    str = str .. string.format(
                        " M %d %d L %d %d L %d %d L %d %d Z",
                        border + x0scl + x1mrg,
                        border + y0scl + y1mrg,

                        border + x0scl + x1mrg,
                        border + y1scl + y1mrg,

                        border + x1scl + x1mrg,
                        border + y1scl + y1mrg,

                        border + x1scl + x1mrg,
                        border + y0scl + y1mrg)
                end

                str = str .. "\" "

                if marginClr.alpha < 255 then
                    str = str .. string.format(
                        "fill-opacity=\"%.6f\" ",
                        marginClr.alpha / 255.0)
                end

                str = str .. string.format(
                    "fill=\"#%06X\" />",
                    (marginClr.red << 0x10
                    | marginClr.green << 0x08
                    | marginClr.blue))
            end

            local activeFrame = app.activeFrame
            local spriteBounds = Rectangle(
                0, 0,
                nativeWidth, nativeHeight)

            local spriteLayers = {}
            for i = 1, #activeSprite.layers, 1 do
                spriteLayers[i] = activeSprite.layers[i]
            end

            local spriteLayersLen = #spriteLayers
            for i = 1, spriteLayersLen, 1 do
                str = str .. layerToSvgStr(
                    spriteLayers[i],
                    activeFrame,
                    spriteBounds,
                    border, scale, margin)
            end

            str = str .. "\n</svg>"

            local filepath = args.filepath
            if filepath and #filepath > 0 then
                local ext = filepath:sub(-#"svg"):lower()
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

local defaults = {
    scale = 1,
    margin = 0,
    marginClr = Color(255, 255, 255, 255),
    border = 0,
    borderClr = Color(0, 0, 0, 255),
    prApply = false,
    flattenImage = true
}

local function imgToSvgStr(img, border, margin, scale, xOff, yOff)
    local strfmt = string.format
    local append = table.insert
    local pathStrArr = {}
    local imgItr = img:pixels()
    for elm in imgItr do
        local hex = elm()
        local a = hex >> 0x18 & 0xff
        if a > 0 then
            local x0 = xOff + elm.x
            local y0 = yOff + elm.y

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
                    a * 0.003921568627451)
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

    return table.concat(pathStrArr)
end

local function layerToSvgStr(
    layer, activeFrame, spriteBounds,
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
            layerName = layer.name
        end

        if isGroup then
            local grpStr = string.format(
                "\n<g id=\"%s\">", layerName)

            local groupLayers = layer.layers
            local groupLayersLen = #groupLayers
            local groupStrArr = {}
            local i = 0
            while i < groupLayersLen do
                i = i + 1
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
                local celBounds = cel.bounds
                local xCel = celBounds.x
                local yCel = celBounds.y
                local intersect = celBounds:intersect(spriteBounds)
                intersect.x = intersect.x - xCel
                intersect.y = intersect.y - yCel

                local grpStr = string.format(
                    "\n<g id=\"%s\"", layerName)

                -- Layer opacity and cel opacity are compounded
                -- together to simplify.
                local celAlpha = cel.opacity
                if lyrAlpha < 0xff
                    or celAlpha < 0xff then
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
    label = "Margin:",
    min = 0,
    max = 64,
    value = defaults.margin
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
    focus = true,
    filetypes = { "svg" },
    save = true
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite." }
            return
        end

        local oldColorMode = activeSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

        -- Collect inputs.
        local args = dlg.data
        local scale = args.scale or defaults.scale
        local margin = args.margin or defaults.margin
        local marginClr = args.marginClr or defaults.marginClr
        local border = args.border or defaults.border
        local borderClr = args.borderClr or defaults.borderClr
        local prApply = args.prApply
        local flattenImage = args.flattenImage

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
                hAspSclr * totalHeight) })

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

        local activeFrame = app.activeFrame

        if flattenImage then
            local flatImg = Image(nativeWidth, nativeHeight)
            flatImg:drawSprite(activeSprite, activeFrame)
            str = str .. imgToSvgStr(flatImg, border, margin, scale, 0, 0)
        else
            local spriteBounds = Rectangle(
                0, 0, nativeWidth, nativeHeight)
            local spriteLayers = activeSprite.layers
            local layersStrArr = {}
            local spriteLayersLen = #spriteLayers
            local j = 0
            while j < spriteLayersLen do j = j + 1
                layersStrArr[j] = layerToSvgStr(
                    spriteLayers[j],
                    activeFrame,
                    spriteBounds,
                    border, scale, margin)
            end
            str = str .. concat(layersStrArr)
        end

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
                local file, err = io.open(filepath, "w")
                if file then
                    file:write(str)
                    file:close()
                end

                if err then
                    app.alert("Error saving file: " .. err)
                end
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

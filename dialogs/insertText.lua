dofile("../support/aseutilities.lua")

local msgSrcs = { "ENTRY", "FILE" }
local txtFormats = { "gpl", "pal", "txt" }

local function slice (tbl, start, finish)
    local pos = 1
    local sl = {}
    local stop = finish

    for i = start, stop, 1 do
        sl[pos] = tbl[i]
        pos = pos + 1
    end

    return sl
end

local defaults = {
    msgSrc = "ENTRY",
    msgEntry = "Lorem ipsum dolor sit amet",
    charLimit = 72,
    animate = false,
    fps = 24,
    fillClr = Color(255, 255, 255, 255),
    shdColor = Color(0, 0, 0, 204),
    bkgColor = Color(20, 20, 20, 204),
    xOrigin = 0,
    yOrigin = 0,
    useShadow = true,
    alignLine = "LEFT",
    alignChar = "TOP",
    scale = 2,
    leading = 0,
    pullFocus = false
}

local dlg = Dialog { title = "Insert Text" }

dlg:combobox {
    id = "msgSrc",
    label = "Text:",
    option = defaults.msgSrc,
    options = msgSrcs,
    onchange = function()
        local state = dlg.data.msgSrc

        dlg:modify {
            id = "msgEntry",
            visible = state == "ENTRY"
        }

        dlg:modify {
            id = "msgFilePath",
            visible = state == "FILE"
        }
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "msgEntry",
    text = defaults.msgEntry,
    focus = "false",
    visible = defaults.msgSrc == "ENTRY"
}

dlg:newrow { always = false }

dlg:file {
    id = "msgFilePath",
    filetypes = txtFormats,
    open = true,
    visible = defaults.msgSrc == "FILE"
}

dlg:newrow { always = false }

dlg:slider {
    id = "charLimit",
    label = "Line Break:",
    min = 16,
    max = 80,
    value = defaults.charLimit
}

dlg:newrow { always = false }

dlg:check {
    id = "animate",
    label = "Animate:",
    selected = defaults.animate,
    onclick = function()
        dlg:modify {
            id = "fps",
            visible = dlg.data.animate
        }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "fps",
    label = "FPS:",
    min = 1,
    max = 50,
    value = defaults.fps,
    visible = defaults.animate
}

dlg:newrow { always = false }

dlg:slider {
    id = "xOrigin",
    label = "Origin:",
    min = 0,
    max = 100,
    value = defaults.xOrigin
}

dlg:slider {
    id = "yOrigin",
    min = 0,
    max = 100,
    value = defaults.yOrigin
}

dlg:newrow { always = false }

dlg:slider {
    id = "scale",
    label = "Scale:",
    min = 1,
    max = 24,
    value = defaults.scale
}

dlg:newrow { always = false }

dlg:slider {
    id = "leading",
    label = "Leading:",
    min = 0,
    max = 64,
    value = defaults.leading
}

dlg:newrow { always = false }

dlg:combobox {
    id = "alignHoriz",
    label = "Pivot:",
    option = defaults.alignLine,
    options = AseUtilities.GLYPH_ALIGN_HORIZ
}

dlg:combobox {
    id = "alignVert",
    option = defaults.alignChar,
    options = AseUtilities.GLYPH_ALIGN_VERT
}

dlg:newrow { always = false }

dlg:color {
    id = "fillClr",
    label = "Fill:",
    color = defaults.fillClr
}

dlg:newrow { always = false }

dlg:color {
    id = "shdColor",
    label = "Shadow:",
    color = defaults.shdColor,
    visible = defaults.useShadow
}

dlg:newrow { always = false }

dlg:color {
    id = "bkgColor",
    label = "Background:",
    color = defaults.bkgColor
}

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data

        -- Constants, as far as we're concerned.
        local lut = Utilities.GLYPH_LUT
        local gw = 8
        local gh = 8
        local mxDrop = 2

        -- Cache methods used in for loops to local.
        local displayString = AseUtilities.drawStringHoriz

        -- Unpack arguments.
        local msgSrc = args.msgSrc or defaults.msgSrc
        local msgEntry = args.msgEntry
        local msgFilePath = args.msgFilePath
        local charLimit = args.charLimit or defaults.charLimit
        local animate = args.animate
        local fps = args.fps or defaults.fps
        local xOrigin = args.xOrigin or defaults.xOrigin
        local yOrigin = args.yOrigin or defaults.xOrigin
        local scale = args.scale or defaults.scale
        local leading = args.leading or defaults.leading
        local alignLine = args.alignHoriz or defaults.alignLine
        local alignChar = args.alignVert or defaults.alignChar
        local aseFill = args.fillClr or defaults.fillClr
        local aseShd = args.shdColor or defaults.shdColor
        local aseBkg = args.bkgColor or defaults.bkgColor

        -- Reinterpret and validate.
        local duration = 1.0 / math.max(1, fps)
        if msgEntry == nil or #msgEntry < 1 then
            msgEntry = defaults.msgEntry
        end

        -- Cache Aseprite colors to hexadecimals.
        local hexBkg = aseBkg.rgbaPixel
        local hexShd = aseShd.rgbaPixel
        local hexFill = aseFill.rgbaPixel

        local charTableStill = {}

        if msgSrc == "FILE" then
            if msgFilePath and #msgFilePath > 0 then
                local file, err = io.open(msgFilePath, "r")
                local flatStr = nil
                if file ~= nil then
                    flatStr = file:read("*all")
                    charTableStill = Utilities.lineWrapStringToChars(
                        flatStr, charLimit)
                    file:close()
                end

                if err ~= nil then
                    app.alert("Error opening file: " .. err)
                end

                if err or flatStr == nil or #flatStr < 1 then
                    app.alert("There was a problem finding the file contents.")
                    charTableStill = Utilities.lineWrapStringToChars(
                        msgEntry, charLimit)
                end
            end
        else
            charTableStill = Utilities.lineWrapStringToChars(
                msgEntry, charLimit)
        end

        -- Find the widths (measured in characters)
        -- for each line. Find the maximum line width.
        local lineWidths = {}
        local maxLineWidth = 0
        local lineCount = #charTableStill
        local totalCharCount = 0
        for i = 1, lineCount, 1 do
            local charsLine = charTableStill[i]
            local lineWidth = #charsLine
            if lineWidth > maxLineWidth then
                maxLineWidth = lineWidth
            end
            totalCharCount = totalCharCount + lineWidth
            lineWidths[i] = lineWidth
        end

        -- Calculate display width and height from
        -- scale multiplied by glyph width and height.
        local dw = gw * scale
        local dh = gh * scale

        -- Calculate dimensions of new image.
        local widthImg = dw * maxLineWidth
        local heightImg = dh * lineCount
            + scale * (lineCount - 1) -- drop shadow
            + leading * (lineCount - 1) -- leading
            + (scale + 1) * mxDrop -- for descenders

        -- Acquire or create sprite.
        -- Acquire top layer.
        local sprite = AseUtilities.initCanvas(
            widthImg, heightImg, "Text")
        local widthSprite = sprite.width
        local heightSprite = sprite.height
        local layer = sprite.layers[#sprite.layers]

        -- Only support RGB color mode.
        if sprite.colorMode ~= ColorMode.RGB then
            app.alert("Only RGB color mode is supported.")
            dlg:close()
            return
        end

        -- Determine if background and shadow should
        -- be used based on their alpha.
        local useBkg = (hexBkg & 0xff000000) ~= 0
        local useShadow = (hexShd & 0xff000000) ~= 0

        -- Create background source image to copy.
        local bkgSrcImg = Image(widthImg, heightImg)
        if useBkg then
            local bkgPxItr = bkgSrcImg:pixels()
            for elm in bkgPxItr do elm(hexBkg) end
        end

        -- Convert from percentage to pixel dimensions.
        xOrigin = math.tointeger(
            0.5 + xOrigin * 0.01 * widthSprite)
        yOrigin = math.tointeger(
            0.5 + yOrigin * 0.01 * heightSprite)

        -- Find the display width and center of a line.
        local dispWidth = maxLineWidth * dw
        local dispCenter = dispWidth // 2

        -- For static text, the cel position can be set.
        -- The numbers in lineOffsets use characters as a measure,
        -- so they need to be multiplied by dw (display width) later.
        local stillPos = Point(xOrigin, yOrigin)
        local lineOffsets = {}
        if alignLine == "CENTER" then
            stillPos.x = stillPos.x - dispCenter

            for i = 1, lineCount, 1 do
                lineOffsets[i] = (maxLineWidth - lineWidths[i]) // 2
            end
        elseif alignLine == "RIGHT" then
            stillPos.x = stillPos.x - dispWidth

            for i = 1, lineCount, 1 do
                lineOffsets[i] = maxLineWidth - lineWidths[i]
            end
        else
            for i = 1, lineCount, 1 do
                lineOffsets[i] = 0
            end
        end

        -- Align characters.
        if alignChar == "CENTER" then
            stillPos.y = stillPos.y - heightImg // 2
        elseif alignChar == "BOTTOM" then
            stillPos.y = stillPos.y - heightImg
        end

        if animate then
            local frames = AseUtilities.createNewFrames(
                sprite, totalCharCount, duration)
            if #frames > 0 then
                local cels = AseUtilities.createNewCels(
                    sprite,
                    frames[1].frameNumber, #frames,
                    layer.stackIndex, 1,
                    Image(1, 1),
                    stillPos)

                if #cels > 0 then
                    local yCaret = 0
                    local flatIdx = 1
                    app.transaction(function()
                        for i = 1, lineCount, 1 do
                            local charsLine = charTableStill[i]
                            local lineWidth = lineWidths[i]
                            local animImage = nil
                            for j = 1, lineWidth, 1 do
                                local animSlice = slice(charsLine, 1, j)
                                local animPosx = 0
                                if alignLine == "CENTER" then
                                    animPosx = animPosx + dispCenter - (j * dw) // 2
                                elseif alignLine == "RIGHT" then
                                    animPosx = animPosx + dispWidth - j * dw
                                end

                                animImage = bkgSrcImg:clone()

                                if useShadow then
                                    displayString(
                                        lut, animImage, animSlice, hexShd,
                                        animPosx, yCaret + scale, gw, gh, scale)
                                end
                                displayString(
                                    lut, animImage, animSlice, hexFill,
                                    animPosx, yCaret, gw, gh, scale)

                                local animCel = cels[flatIdx]
                                animCel.image = animImage

                                flatIdx = flatIdx + 1
                            end

                            yCaret = yCaret + dh + scale + leading
                            bkgSrcImg = animImage:clone()
                        end
                    end)
                end
            end

        else
            local activeFrame = app.activeFrame or sprite.frames[1]
            local activeCel = layer:cel(activeFrame)
                or sprite:newCel(layer, activeFrame)
            activeCel.position = stillPos

            local yCaret = 0
            app.transaction(function()
                for i = 1, lineCount, 1 do
                    local charsLine = charTableStill[i]
                    local lineOffset = lineOffsets[i] * dw

                    if useShadow then
                        displayString(
                            lut, bkgSrcImg, charsLine, hexShd,
                            lineOffset, yCaret + scale, gw, gh, scale)
                    end
                    displayString(
                        lut, bkgSrcImg, charsLine, hexFill,
                        lineOffset, yCaret, gw, gh, scale)

                    yCaret = yCaret + dh + scale + leading

                    activeCel.image = bkgSrcImg
                end
            end)
        end

        app.refresh()
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
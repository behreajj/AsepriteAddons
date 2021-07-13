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
    animate = false,
    duration = 100.0,
    fillClr = Color(255, 255, 255, 255),
    shdColor = Color(0, 0, 0, 204),
    bkgColor = Color(20, 20, 20, 204),
    xOrigin = 0,
    yOrigin = 0,
    useShadow = true,
    alignLine = "LEFT",
    alignChar = "TOP",
    scale = 2,
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
            id = "msgFile",
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
    id = "msgFile",
    filetypes = txtFormats,
    open = true,
    visible = defaults.msgSrc == "FILE"
}

dlg:newrow { always = false }

dlg:check {
    id = "animate",
    label = "Animate:",
    selected = defaults.animate,
    onclick = function()
        dlg:modify {
            id = "duration",
            visible = dlg.data.animate
        }
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "duration",
    label = "Duration:",
    text = string.format("%.1f", defaults.duration),
    decimals = 1,
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

        -- Unpack arguments.
        local msgSrc = args.msgSrc
        local animate = args.animate
        local xOrigin = args.xOrigin
        local yOrigin = args.yOrigin
        local scale = args.scale
        local alignLine = args.alignHoriz
        local alignChar = args.alignVert
        local aseFill = args.fillClr
        local aseShd = args.shdColor
        local aseBkg = args.bkgColor

        local lineCount = 0
        local staticChars = {}
        local lineWidths = {}
        local maxLineWidth = 0

        -- TODO: Handle operation from CLI?
        -- TODO: Handle unreasonably long lines?

        if msgSrc == "FILE" then

            local msgFilePath = args.msgFile
            if msgFilePath and #msgFilePath > 0 then
                -- print(msgFilePath)
                local file = io.open(msgFilePath, "r")
                if file then
                    local linesItr = io.lines(msgFilePath)
                    for strLine in linesItr do
                        -- print(strLine)
                        local lineLen = #strLine
                        local charLine = {}
                        for i = 1, lineLen, 1 do
                            local currChar = strLine:sub(i, i)
                            -- Still append spaces, as someone
                            -- might use them for distribution.
                            -- if not ((i == 1 or i == lineLen)
                            --     and currChar == ' ') then
                            table.insert(charLine, currChar)
                            -- end
                        end

                        table.insert(staticChars, charLine)

                        -- Calculate line widths.
                        local lineWidth = #charLine
                        table.insert(lineWidths, lineWidth)
                        if lineWidth > maxLineWidth then
                            maxLineWidth = lineWidth
                        end

                        lineCount = lineCount + 1
                    end
                    file:close()
                end
            end

        else
            local msg = args.msgEntry
            if msg == nil or #msg < 1 then
                msg = defaults.msgEntry
            end

            local msgLen = #msg
            local prevChar = ''
            local currChar = ''
            local charLine = {}
            for i = 1, msgLen, 1 do
                currChar = msg:sub(i, i)
                if prevChar == '\\' then
                    if currChar == 'n' then
                        local lineWidth = #charLine
                        table.insert(lineWidths, lineWidth)
                        if lineWidth > maxLineWidth then
                            maxLineWidth = lineWidth
                        end

                        table.insert(staticChars, charLine)
                        lineCount = lineCount + 1
                        charLine = {}
                    else
                        table.insert(charLine, currChar)
                    end
                elseif currChar ~= '\\' then
                    table.insert(charLine, currChar)
                end

                prevChar = currChar
            end

            -- Final line.
            if prevChar ~= '\\' and currChar ~= 'n' then
                table.insert(staticChars, charLine)
                local lineWidth = #charLine
                table.insert(lineWidths, lineWidth)
                if lineWidth > maxLineWidth then
                    maxLineWidth = lineWidth
                end
                lineCount = lineCount + 1
            end
        end

        -- Cache Aseprite colors to hexadecimals.
        local hexBkg = aseBkg.rgbaPixel
        local hexShd = aseShd.rgbaPixel
        local hexFill = aseFill.rgbaPixel

        local dw = gw * scale
        local dh = gh * scale
        local useBkg = (hexBkg & 0xff000000) > 0
        local useShadow = (hexShd & 0xff000000) > 0
        local stCharLen = #staticChars

        -- Determine dimensions of new image.
        local widthImg = dw * maxLineWidth
        local heightImg = dh * lineCount + scale * (lineCount - 1)

        -- Acquire or create sprite.
        -- Acquire top layer.
        local sprite = AseUtilities.initCanvas(widthImg, heightImg, "Text")
        local widthSprite = sprite.width
        local heightSprite = sprite.height
        local layer = sprite.layers[#sprite.layers]

        -- Convert from percentage to pixel dimensions.
        xOrigin = math.tointeger(0.5 + xOrigin * 0.01 * widthSprite)
        yOrigin = math.tointeger(0.5 + yOrigin * 0.01 * heightSprite)

        -- Choose display function based on vertical or horizontal.
        local displayString = AseUtilities.drawStringHoriz

        -- Create background source image to copy.
        local bkgSrcImg = Image(widthImg, heightImg)
        if useBkg then
            local bkgPxItr = bkgSrcImg:pixels()
            for elm in bkgPxItr do
                elm(hexBkg)
            end
        end

        -- Find the display width and center of a line.
        local dispWidth = maxLineWidth * dw
        local dispCenter = dispWidth // 2

        -- For static text, the cel position can be set.
        local staticPos = Point(xOrigin, yOrigin)
        local lineOffsets = {}
        if alignLine == "CENTER" then
            staticPos.x = staticPos.x - dispCenter

            for i = 1, lineCount, 1 do
                lineOffsets[i] = (maxLineWidth - lineWidths[i]) // 2
            end
        elseif alignLine == "RIGHT" then
            staticPos.x = staticPos.x - dispWidth

            for i = 1, lineCount, 1 do
                lineOffsets[i] = maxLineWidth - lineWidths[i]
            end
        else
            for i = 1, lineCount, 1 do
                lineOffsets[i] = 0
            end
        end

        if alignChar == "CENTER" then
            staticPos.y = staticPos.y - heightImg // 2
        elseif alignChar == "BOTTOM" then
            staticPos.y = staticPos.y - heightImg
        end

        if animate then

            local duration = args.duration or defaults.duration
            duration = duration * 0.001
            app.transaction(function()

                local yCaret = 0
                for i = 1, stCharLen, 1 do
                    local charLine = staticChars[i]
                    local charCount = #charLine
                    local animImage = nil

                    for j = 1, charCount, 1 do
                        local animSlice = slice(charLine, 1, j)
                        local slLen = #animSlice

                        local animFrame = sprite:newEmptyFrame()
                        animFrame.duration = duration
                        local animCel = sprite:newCel(layer, animFrame)
                        animCel.position = staticPos

                        local animPosx = 0
                        if alignLine == "CENTER" then
                            animPosx = animPosx + dispCenter - (slLen * dw) // 2
                        elseif alignLine == "RIGHT" then
                            animPosx = animPosx + dispWidth - slLen * dw
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

                        animCel.image = animImage
                    end

                    yCaret = yCaret + dh + scale

                    bkgSrcImg = animImage:clone()
                end
            end)

        else

            -- Static text is the default.
            local staticFrame = app.activeFrame or 1
            local staticCel = sprite:newCel(layer, staticFrame)
            staticCel.position = staticPos

            local yCaret = 0
            for i = 1, stCharLen, 1 do
                local charLine = staticChars[i]
                local lineOffset = lineOffsets[i] * dw

                if useShadow then
                    displayString(
                        lut, bkgSrcImg, charLine, hexShd,
                        lineOffset, yCaret + scale, gw, gh, scale)
                end
                displayString(
                    lut, bkgSrcImg, charLine, hexFill,
                    lineOffset, yCaret, gw, gh, scale)

                yCaret = yCaret + dh + scale
            end

            staticCel.image = bkgSrcImg

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

dlg:show {
    wait = false
}

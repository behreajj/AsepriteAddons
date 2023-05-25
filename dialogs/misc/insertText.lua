dofile("../../support/textutilities.lua")

local msgSrcs = { "ENTRY", "FILE" }
local txtFormats = { "gpl", "md", "pal", "txt" }

local function slice(tbl, start, finish)
    local sl = {}
    local dest = finish or #tbl
    local orig = (start or 1) - 1
    local range = dest - orig
    if range < 1 then return {} end
    local pos = 0
    while pos < range do
        pos = pos + 1
        sl[pos] = tbl[orig + pos]
    end
    return sl
end

local defaults = {
    msgSrc = "ENTRY",
    msgEntry = "Lorem ipsum dolor sit amet",
    charLimit = 72,
    animate = false,
    fps = 24,
    fillClr = Color { r = 255, g = 255, b = 255 },
    shdColor = Color { r = 0, g = 0, b = 0, a = 204 },
    bkgColor = Color { r = 0, g = 0, b = 0, a = 0 },
    xOrigin = 0,
    yOrigin = 0,
    useShadow = true,
    alignLine = "LEFT",
    alignChar = "TOP",
    scale = 2,
    leading = 0,
    printElapsed = false,
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

        local isf = state == "FILE"
        dlg:modify { id = "msgFilePath", visible = isf }
        dlg:modify { id = "printElapsed", visible = isf }
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "msgEntry",
    text = defaults.msgEntry,
    focus = true,
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

-- For now, this is not worth the
-- hassle that it creates.
-- dlg:newrow { always = false }

-- dlg:check {
--     id = "animate",
--     label = "Animate:",
--     selected = defaults.animate,
--     onclick = function()
--         dlg:modify {
--             id = "fps",
--             visible = dlg.data.animate
--         }
--     end
-- }

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
    options = TextUtilities.GLYPH_ALIGN_HORIZ
}

dlg:combobox {
    id = "alignVert",
    option = defaults.alignChar,
    options = TextUtilities.GLYPH_ALIGN_VERT
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

dlg:newrow { always = false }

dlg:check {
    id = "printElapsed",
    label = "Print:",
    text = "Diagnostic",
    selected = defaults.printElapsed,
    visible = defaults.msgSrc == "FILE"
}

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Begin measuring elapsed time.
        local args = dlg.data
        local printElapsed = args.printElapsed --[[@as boolean]]
        local startTime = 0
        local endTime = 0
        local elapsed = 0
        if printElapsed then startTime = os.clock() end

        -- Only support RGB color mode.
        if app.activeSprite
            and app.activeSprite.colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported." }
            dlg:close()
            return
        end

        -- Constants, as far as we're concerned.
        local lut = TextUtilities.GLYPH_LUT
        local gw = TextUtilities.GLYPH_WIDTH
        local gh = TextUtilities.GLYPH_HEIGHT
        local mxDrop = 2

        -- Cache methods used in for loops to local.
        local displayString = TextUtilities.drawString

        -- Unpack arguments.
        local msgSrc = args.msgSrc or defaults.msgSrc
        local msgEntry = args.msgEntry --[[@as string]]
        local msgFilePath = args.msgFilePath --[[@as string]]
        local charLimit = args.charLimit or defaults.charLimit --[[@as integer]]
        local animate = args.animate
        local fps = args.fps or defaults.fps --[[@as integer]]
        local xOrigin = args.xOrigin or defaults.xOrigin --[[@as integer]]
        local yOrigin = args.yOrigin or defaults.yOrigin --[[@as integer]]
        local scale = args.scale or defaults.scale --[[@as integer]]
        local leading = args.leading or defaults.leading --[[@as integer]]
        local alignLine = args.alignHoriz or defaults.alignLine --[[@as string]]
        local alignChar = args.alignVert or defaults.alignChar --[[@as string]]
        local aseFill = args.fillClr --[[@as Color]]
        local aseShd = args.shdColor --[[@as Color]]
        local aseBkg = args.bkgColor --[[@as Color]]

        -- Reinterpret and validate.
        local duration = 1.0 / math.max(1, fps)
        if msgEntry == nil or #msgEntry < 1 then
            msgEntry = defaults.msgEntry
        end

        -- Cache Aseprite colors to hexadecimals.
        local hexBkg = AseUtilities.aseColorToHex(aseBkg, ColorMode.RGB)
        local hexShd = AseUtilities.aseColorToHex(aseShd, ColorMode.RGB)
        local hexFill = AseUtilities.aseColorToHex(aseFill, ColorMode.RGB)

        local charTableStill = {}

        if msgSrc == "FILE" then
            if msgFilePath and #msgFilePath > 0 then
                local file, err = io.open(msgFilePath, "r")
                local flatStr = nil
                if file ~= nil then
                    flatStr = file:read("*all")
                    charTableStill = TextUtilities.lineWrapStringToChars(
                        flatStr, charLimit)
                    file:close()
                end

                if err ~= nil then
                    app.alert("Error opening file: " .. err)
                end

                if err or flatStr == nil or #flatStr < 1 then
                    app.alert("There was a problem finding the file contents.")
                    charTableStill = TextUtilities.lineWrapStringToChars(
                        msgEntry, charLimit)
                end
            else
                app.alert { title = "Error", text = "Empty file path." }
                return
            end
        else
            charTableStill = TextUtilities.lineWrapStringToChars(
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
            + scale * (lineCount - 1)   -- drop shadow
            + leading * (lineCount - 1) -- leading
            + (scale + 1) * mxDrop      -- for descenders

        local layer = nil
        local site = app.site
        local sprite = site.sprite
        if not sprite then
            sprite = Sprite(widthImg, heightImg)
            app.transaction("Set Palette", function()
                if app.defaultPalette then
                    sprite:setPalette(app.defaultPalette)
                else
                    local pal = sprite.palettes[1]
                    pal:resize(3)
                    pal:setColor(0, hexBkg)
                    pal:setColor(1, hexShd)
                    pal:setColor(2, hexFill)
                end
            end)

            layer = sprite.layers[1]
            layer.name = "Text"
        else
            app.transaction("New Layer", function()
                layer = sprite:newLayer()
                layer.name = "Text"
            end)
        end

        local widthSprite = sprite.width
        local heightSprite = sprite.height

        -- Determine if background and shadow should
        -- be used based on their alpha.
        local useBkg = (hexBkg & 0xff000000) ~= 0
        local useShadow = (hexShd & 0xff000000) ~= 0

        -- Create background source image to copy.
        local bkgSrcSpec = ImageSpec {
            width = widthImg,
            height = heightImg }
        bkgSrcSpec.colorSpace = sprite.colorSpace
        local bkgSrcImg = Image(bkgSrcSpec)
        if useBkg then
            bkgSrcImg:clear(hexBkg)
        end

        -- Convert from percentage to pixel dimensions.
        xOrigin = math.floor(
            0.5 + xOrigin * 0.01 * widthSprite)
        yOrigin = math.floor(
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

            local h = 0
            while h < lineCount do
                h = h + 1
                lineOffsets[h] = (maxLineWidth - lineWidths[h]) // 2
            end
        elseif alignLine == "RIGHT" then
            stillPos.x = stillPos.x - dispWidth

            local h = 0
            while h < lineCount do
                h = h + 1
                lineOffsets[h] = maxLineWidth - lineWidths[h]
            end
        else
            local h = 0
            while h < lineCount do
                h = h + 1
                lineOffsets[h] = 0
            end
        end

        -- Align characters.
        if alignChar == "CENTER" then
            stillPos.y = stillPos.y - heightImg // 2
        elseif alignChar == "BOTTOM" then
            stillPos.y = stillPos.y - heightImg
        end

        local activeFrameObj = site.frame
            or sprite.frames[1]
        local actFrIdx = activeFrameObj.frameNumber
        if animate then
            local frames = sprite.frames
            local lenFrames = #frames
            local reqFrames = actFrIdx
                + totalCharCount - (1 + lenFrames)

            -- Extra error check wrapping when debugging:
            -- https://github.com/aseprite/aseprite/issues/3276
            app.transaction("New Frames", function()
                AseUtilities.createFrames(
                    sprite, reqFrames, duration)
            end)

            app.transaction("New Cels", function()
                AseUtilities.createCels(
                    sprite,
                    actFrIdx, totalCharCount,
                    layer.stackIndex, 1,
                    Image(1, 1), stillPos, 0x0)
            end)

            local yCaret = 0
            local currFrameIdx = actFrIdx - 1

            -- If a transaction is placed around
            -- the outer loop, seems like it hogs up
            -- too much memory. But without any, there
            -- are too many little transactions. The
            -- compromise is to wrap the inner loop.
            local i = 0
            while i < lineCount do
                i = i + 1
                local charsLine = charTableStill[i]
                local lineWidth = lineWidths[i]
                local animImage = nil

                -- Ideally, this would create new images that are
                -- not connected to any cel, then create the cel
                -- and assign the image in the sprite method.
                app.transaction("Insert Text", function()
                    local j = 0
                    while j < lineWidth do
                        currFrameIdx = currFrameIdx + 1
                        local animCel = layer:cel(currFrameIdx)
                        if animCel then
                            animImage = bkgSrcImg:clone()

                            j = j + 1
                            local animSlice = slice(charsLine, 1, j)
                            local animPosx = 0
                            if alignLine == "CENTER" then
                                animPosx = animPosx + dispCenter - (j * dw) // 2
                            elseif alignLine == "RIGHT" then
                                animPosx = animPosx + dispWidth - j * dw
                            end

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
                    end
                end)

                yCaret = yCaret + dh + scale + leading
                bkgSrcImg = animImage:clone()
            end
        else
            local activeCel = layer:cel(actFrIdx)
                or sprite:newCel(layer, actFrIdx)
            activeCel.position = stillPos

            local yCaret = 0
            app.transaction("Insert Text", function()
                local k = 0
                while k < lineCount do
                    k = k + 1
                    local charsLine = charTableStill[k]
                    local lineOffset = lineOffsets[k] * dw

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

        if printElapsed then
            endTime = os.clock()
            elapsed = endTime - startTime
            local txtArr = {
                string.format("Start: %.2f", startTime),
                string.format("End: %.2f", endTime),
                string.format("Elapsed: %.6f", elapsed),
                string.format("Lines: %d", lineCount),
                string.format("Characters: %d", totalCharCount)
            }
            app.alert { title = "Diagnostic", text = txtArr }
        end

        app.refresh()
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
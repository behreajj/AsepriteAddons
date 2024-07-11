dofile("../../support/textutilities.lua")

local msgSrcs <const> = { "ENTRY", "FILE" }
local txtFormats <const> = { "gpl", "md", "pal", "txt" }

---@param tbl string[]
---@param start integer
---@param finish integer
---@return string[]
local function slice(tbl, start, finish)
    local sl <const> = {}
    local dest <const> = finish or #tbl
    local orig <const> = (start or 1) - 1
    local range <const> = dest - orig
    if range < 1 then return {} end
    local pos = 0
    while pos < range do
        pos = pos + 1
        sl[pos] = tbl[orig + pos]
    end
    return sl
end

local defaults <const> = {
    msgSrc = "ENTRY",
    msgEntry = "Lorem ipsum dolor sit amet",
    charLimit = 72,
    animate = false,
    fps = 24,
    fillClr = Color { r = 255, g = 255, b = 255 },
    shdColor = Color { r = 0, g = 0, b = 0, a = 204 },
    bkgColor = Color { r = 0, g = 0, b = 0, a = 0 },
    xOrig = 0,
    yOrig = 0,
    useShadow = true,
    alignLine = "LEFT",
    alignChar = "TOP",
    scale = 2,
    leading = 0,
    printElapsed = false,
    pullFocus = false
}

local dlg <const> = Dialog { title = "Insert Text" }

dlg:combobox {
    id = "msgSrc",
    label = "Text:",
    option = defaults.msgSrc,
    options = msgSrcs,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.msgSrc --[[@as string]]
        dlg:modify {
            id = "msgEntry",
            visible = state == "ENTRY"
        }

        local isf <const> = state == "FILE"
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

dlg:newrow { always = false }

dlg:check {
    id = "animate",
    label = "Animate:",
    selected = defaults.animate,
    onclick = function()
        local args <const> = dlg.data
        local animate <const> = args.animate --[[@as boolean]]
        dlg:modify { id = "fps", visible = animate }
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
    id = "xOrig",
    label = "Origin:",
    min = 0,
    max = 100,
    value = defaults.xOrig
}

dlg:slider {
    id = "yOrig",
    min = 0,
    max = 100,
    value = defaults.yOrig
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
        local args <const> = dlg.data
        local printElapsed <const> = args.printElapsed --[[@as boolean]]
        local startTime <const> = os.clock()
        local endTime = 0
        local elapsed = 0

        -- Only support RGB color mode.
        if app.sprite
            and app.sprite.colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        -- Constants, as far as we're concerned.
        local lut <const> = TextUtilities.GLYPH_LUT
        local gw <const> = TextUtilities.GLYPH_WIDTH
        local gh <const> = TextUtilities.GLYPH_HEIGHT
        local mxDrop <const> = 2

        -- Cache methods used in for loops to local.
        local displayString <const> = TextUtilities.drawString
        local getPixels <const> = AseUtilities.getPixels
        local setPixels <const> = AseUtilities.setPixels

        -- Unpack arguments.
        local msgSrc <const> = args.msgSrc or defaults.msgSrc --[[@as string]]
        local msgEntry = args.msgEntry --[[@as string]]
        local msgFilePath <const> = args.msgFilePath --[[@as string]]
        local charLimit <const> = args.charLimit or defaults.charLimit --[[@as integer]]
        local animate <const> = args.animate --[[@as boolean]]
        local fps <const> = args.fps or defaults.fps --[[@as integer]]
        local xOrig = args.xOrig or defaults.xOrig --[[@as integer]]
        local yOrig = args.yOrig or defaults.yOrig --[[@as integer]]
        local scale <const> = args.scale or defaults.scale --[[@as integer]]
        local leading <const> = args.leading or defaults.leading --[[@as integer]]
        local alignLine = args.alignHoriz or defaults.alignLine --[[@as string]]
        local alignChar = args.alignVert or defaults.alignChar --[[@as string]]
        local aseFill <const> = args.fillClr --[[@as Color]]
        local aseShd <const> = args.shdColor --[[@as Color]]
        local aseBkg <const> = args.bkgColor --[[@as Color]]

        -- Reinterpret and validate.
        local duration <const> = 1.0 / math.max(1, fps)
        if msgEntry == nil or #msgEntry < 1 then
            msgEntry = defaults.msgEntry
        end

        -- Cache Aseprite colors to hexadecimals.
        local hexBkg <const> = AseUtilities.aseColorToHex(aseBkg, ColorMode.RGB)
        local hexShd <const> = AseUtilities.aseColorToHex(aseShd, ColorMode.RGB)
        local hexFill <const> = AseUtilities.aseColorToHex(aseFill, ColorMode.RGB)

        local rShd <const> = aseShd.red
        local gShd <const> = aseShd.green
        local bShd <const> = aseShd.blue
        local aShd <const> = aseShd.alpha

        local rFill <const> = aseFill.red
        local gFill <const> = aseFill.green
        local bFill <const> = aseFill.blue
        local aFill <const> = aseFill.alpha

        ---@type string[][]
        local charTableStill = {}

        if msgSrc == "FILE" then
            if msgFilePath and #msgFilePath > 0 then
                local file <const>, err <const> = io.open(msgFilePath, "r")
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
        ---@type integer[]
        local lineWidths <const> = {}
        local maxLineWidth = 0
        local lineCount <const> = #charTableStill
        local totalCharCount = 0
        local g = 0
        while g < lineCount do
            g = g + 1
            local charsLine <const> = charTableStill[g]
            local lineWidth <const> = #charsLine
            if lineWidth > maxLineWidth then
                maxLineWidth = lineWidth
            end
            totalCharCount = totalCharCount + lineWidth
            lineWidths[g] = lineWidth
        end

        -- Calculate display width and height from
        -- scale multiplied by glyph width and height.
        local dw <const> = gw * scale
        local dh <const> = gh * scale

        -- Calculate dimensions of new image.
        local widthImg <const> = dw * maxLineWidth
        local heightImg <const> = dh * lineCount
            + scale * (lineCount - 1)   -- drop shadow
            + leading * (lineCount - 1) -- leading
            + (scale + 1) * mxDrop      -- for descenders

        local layer = nil
        local site <const> = app.site
        local sprite = site.sprite
        if not sprite then
            -- If you need to create a new sprite, you might as well put the
            -- text in the canvas.
            alignLine = "LEFT"
            alignChar = "TOP"
            xOrig = 0
            yOrig = 0

            sprite = AseUtilities.createSprite(
                AseUtilities.createSpec(widthImg, heightImg), "Text")

            app.transaction("Set Palette", function()
                -- if app.defaultPalette then
                -- sprite:setPalette(app.defaultPalette)
                -- else
                local pal <const> = sprite.palettes[1]
                pal:resize(3)
                pal:setColor(0, hexBkg)
                pal:setColor(1, hexShd)
                pal:setColor(2, hexFill)
                -- end
            end)

            layer = sprite.layers[1]
            layer.name = "Text"
        else
            layer = sprite:newLayer()
            layer.name = "Text"
        end

        local spriteSpec <const> = sprite.spec
        local widthSprite <const> = spriteSpec.width
        local heightSprite <const> = spriteSpec.height

        -- Determine if background and shadow should
        -- be used based on their alpha.
        local useBkg <const> = (hexBkg & 0xff000000) ~= 0
        local useShadow <const> = (hexShd & 0xff000000) ~= 0

        -- Create background source image to copy.
        local bkgSrcImg = Image(AseUtilities.createSpec(widthImg, heightImg,
            spriteSpec.colorMode, spriteSpec.colorSpace,
            spriteSpec.transparentColor))
        if useBkg then
            bkgSrcImg:clear(hexBkg)
        end

        -- Convert from percentage to pixel dimensions.
        xOrig = math.floor(0.5 + xOrig * 0.01 * widthSprite)
        yOrig = math.floor(0.5 + yOrig * 0.01 * heightSprite)

        -- Find the display width and center of a line.
        local dispWidth <const> = maxLineWidth * dw
        local dispCenter <const> = dispWidth // 2

        -- For static text, the cel position can be set.
        -- The numbers in lineOffsets use characters as a measure,
        -- so they need to be multiplied by dw (display width) later.
        local stillPos <const> = Point(xOrig, yOrig)
        ---@type integer[]
        local lineOffsets <const> = {}
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

        local activeFrameObj <const> = site.frame or sprite.frames[1]
        local actFrIdx <const> = activeFrameObj.frameNumber
        if animate then
            local frames <const> = sprite.frames
            local lenFrames <const> = #frames
            local reqFrames <const> = actFrIdx
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

            -- If a transaction is placed around the outer loop, seems like it
            -- hogs up too much memory. But without any, there are too many
            -- little transactions. The compromise is to wrap the inner loop.
            local i = 0
            while i < lineCount do
                i = i + 1
                local charsLine <const> = charTableStill[i]
                local lineWidth <const> = lineWidths[i]
                local animImage = nil

                -- Ideally, this would create new images that are not connected
                -- to any cel, then create the cel and assign the image in the
                -- sprite method.
                app.transaction("Insert Text", function()
                    local j = 0
                    while j < lineWidth do
                        currFrameIdx = currFrameIdx + 1
                        local animCel <const> = layer:cel(currFrameIdx)
                        if animCel then
                            animImage = bkgSrcImg:clone()

                            j = j + 1
                            local animSlice <const> = slice(charsLine, 1, j)
                            local animPosx = 0
                            if alignLine == "CENTER" then
                                animPosx = animPosx + dispCenter - (j * dw) // 2
                            elseif alignLine == "RIGHT" then
                                animPosx = animPosx + dispWidth - j * dw
                            end

                            local pixels <const> = getPixels(animImage)
                            if useShadow then
                                displayString(
                                    lut, pixels, widthImg, animSlice,
                                    rShd, gShd, bShd, aShd,
                                    animPosx, yCaret + scale, gw, gh, scale)
                            end
                            displayString(
                                lut, pixels, widthImg, animSlice,
                                rFill, gFill, bFill, aFill,
                                animPosx, yCaret, gw, gh, scale)
                            setPixels(animImage, pixels)

                            animCel.image = animImage
                        end
                    end
                end)

                yCaret = yCaret + dh + scale + leading
                if animImage then bkgSrcImg = animImage:clone() end
            end
        else
            local activeCel <const> = layer:cel(actFrIdx)
                or sprite:newCel(layer, actFrIdx)
            activeCel.position = stillPos
            local pixels <const> = getPixels(bkgSrcImg)

            app.transaction("Insert Text", function()
                local yCaret = 0
                local k = 0
                while k < lineCount do
                    k = k + 1
                    local charsLine <const> = charTableStill[k]
                    local lineOffset <const> = lineOffsets[k] * dw

                    if useShadow then
                        displayString(
                            lut, pixels, widthImg, charsLine,
                            rShd, gShd, bShd, aShd,
                            lineOffset, yCaret + scale, gw, gh, scale)
                    end
                    displayString(
                        lut, pixels, widthImg, charsLine,
                        rFill, gFill, bFill, aFill,
                        lineOffset, yCaret, gw, gh, scale)
                    yCaret = yCaret + dh + scale + leading
                end
                setPixels(bkgSrcImg, pixels)
                activeCel.image = bkgSrcImg
            end)
        end

        if printElapsed then
            endTime = os.clock()
            elapsed = endTime - startTime
            local txtArr <const> = {
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

dlg:show {
    autoscrollbars = true,
    wait = false
}
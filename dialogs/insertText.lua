dofile("../support/aseutilities.lua")

local defaults = {
    msg = "Lorem ipsum dolor sit amet",
    animate = false,
    duration = 100.0,
    fillClr = Color(255, 255, 255, 255),
    shdColor = Color(0, 0, 0, 204),
    bkgColor = Color(20, 20, 20, 0),
    xOrigin = 50,
    yOrigin = 50,
    useShadow = true,
    alignLine = "CENTER",
    alignChar = "CENTER",
    scale = 2,
    pullFocus = false
}

local dlg = Dialog { title = "Insert Text" }

dlg:entry {
    id = "msg",
    label = "Message",
    text = defaults.msg,
    focus = "false"
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

dlg:slider {
    id = "scale",
    label = "Scale:",
    min = 1,
    max = 24,
    value = defaults.scale
}

dlg:combobox {
    id = "alignHoriz",
    label = "Line:",
    option = defaults.alignLine,
    options = AseUtilities.GLYPH_ALIGN_HORIZ
}

dlg:combobox {
    id = "alignVert",
    label = "Char:",
    option = defaults.alignChar,
    options = AseUtilities.GLYPH_ALIGN_VERT
}

dlg:color {
    id = "fillClr",
    label = "Fill:",
    color = defaults.fillClr
}

dlg:color {
    id = "shdColor",
    label = "Shadow:",
    color = defaults.shdColor,
    visible = defaults.useShadow
}

dlg:color {
    id = "bkgColor",
    label = "Background:",
    color = defaults.bkgColor
}

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

dlg:button {
    id = "confirm",
    text = "OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data

        -- Constants, as far as we're concerned.
        local lut = Utilities.GLYPH_LUT
        local gw = 8
        local gh = 8

        -- Unpack arguments.
        local msg = args.msg
        local animate = args.animate
        local xOrigin = args.xOrigin
        local yOrigin = args.yOrigin
        local scale = args.scale
        local orientation = args.orientation
        local alignLine = args.alignHoriz
        local alignChar = args.alignVert
        local aseFill = args.fillClr
        local aseShd = args.shdColor
        local aseBkg = args.bkgColor

        -- Validate message.
        local msgLen = #msg
        if msg == nil or msgLen < 1 then
            msg = defaults.msg
            msgLen = #msg
        end

        -- Unpack string to characters table.
        local staticChars = {}
        for i = 1, msgLen, 1 do
            staticChars[i] = msg:sub(i, i)
        end

        -- Cache Aseprite colors to hexadecimals.
        local hexBkg = aseBkg.rgbaPixel
        local hexShd = aseShd.rgbaPixel
        local hexFill = aseFill.rgbaPixel

        local dw = gw * scale
        local dh = gh * scale
        local useBkg = (hexBkg & 0xff000000) > 0
        local useShadow = (hexShd & 0xff000000) > 0

        -- Determine dimensions of new image.
        local widthImg = dw * msgLen
        local heightImg = dh
        if useShadow then heightImg = heightImg + scale end

        -- Acquire or create sprite.
        -- Acquire top layer.
        local sprite = AseUtilities.initCanvas(widthImg, heightImg, msg)
        local widthSprite = sprite.width
        local heightSprite = sprite.height
        local layer = sprite.layers[#sprite.layers]

        -- Convert from percentage to pixel dimensions.
        xOrigin = math.tointeger(0.5 + xOrigin * 0.01 * widthSprite)
        yOrigin = math.tointeger(0.5 + yOrigin * 0.01 * heightSprite)

        -- Choose display function based on vertical or horizontal.
        local displayString = nil
        if orientation == "VERTICAL" then
            displayString = AseUtilities.drawStringVert
        else
            displayString = AseUtilities.drawStringHoriz
        end

        -- Create background source image to copy.
        local bkgSrcImg = Image(widthImg, heightImg)
        if useBkg then
            local bkgPxItr = bkgSrcImg:pixels()
            for elm in bkgPxItr do
                elm(hexBkg)
            end
        end

        -- Find the display width and center of a line.
        local dispWidth = msgLen * dw
        local dispCenter = dispWidth // 2

        -- For static text, the cel position can be set.
        local staticPos = Point(xOrigin, yOrigin)
        if alignLine == "CENTER" then
            staticPos.x = staticPos.x - dispCenter
        elseif alignLine == "RIGHT" then
            staticPos.x = staticPos.x - dispWidth
        end

        if alignChar == "CENTER" then
            staticPos.y = staticPos.y - math.ceil((dh + scale) * 0.5)
        elseif alignChar == "BOTTOM" then
            staticPos.y = staticPos.y - (dh + scale)
        end

        -- TODO: Allow for parsing of line breaks from \n?
        if animate then

            local duration = args.duration or defaults.duration
            duration = duration * 0.001
            app.transaction(function()
                for i = 1, msgLen, 1 do
                    local animSlice = slice(staticChars, 1, i)
                    local slLen = #animSlice

                    -- For animated text, the dynamic text needs
                    -- to be compared to the static text.
                    local animPosx = 0
                    if alignLine == "CENTER" then
                        animPosx = dispCenter - (slLen * dw) // 2
                    elseif alignLine == "RIGHT" then
                        animPosx = dispWidth - slLen * dw
                    end

                    local animFrame = sprite:newEmptyFrame()
                    animFrame.duration = duration
                    local animCel = sprite:newCel(layer, animFrame)
                    animCel.position = staticPos

                    local animImage = bkgSrcImg:clone()

                    if useShadow then
                        displayString(
                            lut, animImage, animSlice, hexShd,
                            animPosx, scale, gw, gh, scale)
                    end
                    displayString(
                        lut, animImage, animSlice, hexFill,
                        animPosx, 0, gw, gh, scale)

                    animCel.image = animImage
                end
            end)

        else

            -- Static text is the default.
            local staticFrame = app.activeFrame or 1
            local staticCel = sprite:newCel(layer, staticFrame)
            staticCel.position = staticPos

            if useShadow then
                displayString(
                    lut, bkgSrcImg, staticChars, hexShd,
                    0, scale, gw, gh, scale)
            end
            displayString(
                lut, bkgSrcImg, staticChars, hexFill,
                0, 0, gw, gh, scale)

            staticCel.image = bkgSrcImg

        end

        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    wait = false
}

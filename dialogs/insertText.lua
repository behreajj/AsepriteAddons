dofile("../support/utilities.lua")

local function rotateCcw(v, w, h)
    local lenn1 = (w * h) - 1
    local wn1 = w - 1
    local vr = 0
    for i = 0, lenn1, 1 do
        local shift0 = lenn1 - i
        local bit = (v >> shift0) & 1

        local x = i // w
        local y = wn1 - (i % w)
        local j = y * h + x
        local shift1 = lenn1 - j
        vr = vr | (bit << shift1)
    end
    return vr
end

local function displayGlyph(
    image, glyph, hex,
    xLoc, yLoc,
    glyphWidth, glyphHeight)

    local h = glyphHeight or 5
    local w = glyphWidth or 3
    local y = yLoc or 0
    local x = xLoc or 0
    local clr = hex or 0xffffffff
    local g = glyph or 0

    local len = w * h
    local lenn1 = len - 1

    -- TODO: How to upscale a glyph by 2x, 3x, etc.?
    for i = 0, lenn1, 1 do
        local shift = lenn1 - i
        local mark = (g >> shift) & 1
        if mark ~= 0 then
            image:drawPixel(x + (i % w), y + (i // w), clr)
        end
    end
end

local function displayStringVert(image, chars, clr, x, y, w, h, lut)

    local writeChar = y
    local writeLine = x
    local charLen = #chars

    for i = 1, charLen, 1 do
        local ch = chars[i]
        if ch == '\n' then
            writeLine = writeLine + w + 2
            writeChar = y
        else
            local glyph = lut[ch]
            glyph = rotateCcw(glyph, w, h)

            displayGlyph(image, glyph, clr, writeLine, writeChar, h, w)
            writeChar = writeChar - h + 1
        end
    end
end

local function displayStringHoriz(image, chars, clr, x, y, w, h, lut)

    local writeChar = x
    local writeLine = y
    local charLen = #chars
    for i = 1, charLen, 1 do
        local ch = chars[i]
        -- print(ch)
        if ch == '\n' then
            -- Add 2, not 1, due to drop shadow.
            writeLine = writeLine + h + 2
            writeChar = x
        else
            local glyph = lut[ch]
            -- print(glyph)

            displayGlyph(image, glyph, clr, writeChar, writeLine, w, h)
            writeChar = writeChar + w + 1
        end
    end
end

local dlg = Dialog {
    title = "Print Message Test"
}

dlg:entry{
    id = "msg",
    label = "Message",
    text = "Lorem ipsum dolor sit amet",
    focus = "false"
}

dlg:color{
    id = "fillClr",
    label = "Fill:",
    color = Color(255, 255, 255, 255)
}

dlg:color{
    id = "shadowClr",
    label = "Shadow:",
    color = Color(0, 0, 0, 204)
}

dlg:number{
    id = "xOrigin",
    label = "Origin:",
    text = string.format("%.1f", 0),
    decimals = 5
}

dlg:number{
    id = "yOrigin",
    text = string.format("%.1f", 0),
    decimals = 5
}

dlg:check {
    id = "useShadow",
    label = "Drop Shadow:",
    selected = true
}

dlg:combobox {
    id = "orientation",
    label = "Orientation:",
    option = "HORIZONTAL",
    options = {"HORIZONTAL", "VERTICAL"},
}

dlg:combobox {
    id = "alignHoriz",
    label = "Line:",
    option = "LEFT",
    options = {"LEFT", "CENTER", "RIGHT"},
}

dlg:combobox {
    id = "alignVert",
    label = "Char:",
    option = "TOP",
    options = {"BOTTOM", "CENTER", "TOP"},
}

dlg:button{
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = app.activeSprite
            if sprite then

                -- Constants, as far as we're concerned.
                local lut = Utilities.GLYPH_LUT
                local gw = 3
                local gh = 5

                -- Unpack user inputs.
                local hexFill = args.fillClr.rgbaPixel
                local hexShd = args.shadowClr.rgbaPixel
                local xLoc = args.xOrigin or 0
                local yLoc = args.yOrigin or 0
                local orientation = args.orientation
                local alignHoriz = args.alignHoriz
                local alignVert = args.alignVert

                -- Create layer, cel.
                local layer = sprite:newLayer()
                local frame = app.activeFrame or 1
                local cel = sprite:newCel(layer, frame)
                local image = cel.image

                -- Validate message.
                local msg = args.msg
                local msgLen = #msg
                if msg == nil or msgLen < 1 then
                    msg = "Lorem ipsum dolor sit amet"
                    msgLen = #msg
                end

                -- Name layer after message.
                -- Alternatively, assign to cel data?
                layer.name = msg

                -- Unpack string to characters table.
                local msgUpper = string.upper(msg)
                local chars = {}
                for i = 1, msgLen, 1 do
                    chars[i] = msgUpper:sub(i, i)
                end

                local displayString = displayStringHoriz
                if orientation == "VERTICAL" then
                    displayString = displayStringVert

                    -- Because of rotation pivot,
                    -- characters need to be shifted up
                    -- by one glyph.
                    yLoc = yLoc - gw

                    if alignHoriz == "CENTER" then
                        local gwLen = msgLen * (gw + 1)
                        yLoc = yLoc + gwLen // 2
                    elseif alignHoriz == "RIGHT" then
                        local gwLen = msgLen * (gw + 1)
                        yLoc = yLoc + gwLen
                    end

                    if alignVert == "CENTER" then
                        xLoc = xLoc - (gh + 1) // 2
                    elseif alignVert == "BOTTOM" then
                        xLoc = xLoc - (gh - 1)
                    end
                else
                    if alignHoriz == "CENTER" then
                        local gwLen = msgLen * (gw + 1)
                        xLoc = xLoc - gwLen // 2
                    elseif alignHoriz == "RIGHT" then
                        local gwLen = msgLen * (gw + 1)
                        xLoc = xLoc - gwLen
                    end

                    if alignVert == "CENTER" then
                        yLoc = yLoc - (gh + 1) // 2
                    elseif alignVert == "BOTTOM" then
                        yLoc = yLoc - (gh - 1)
                    end
                end

                -- Display string, optionally with shadow.
                if args.useShadow then
                    displayString(image, chars, hexShd, xLoc, yLoc + 1, gw, gh, lut)
                end
                displayString(image, chars, hexFill, xLoc, yLoc, gw, gh, lut)

                app.refresh()
            else
                app.alert("There is no active sprite.")
            end
        else
            app.alert("Dialog arguments are invalid.")
        end
    end
}

dlg:button{
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show{
    wait = false
}

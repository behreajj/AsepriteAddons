dofile("../support/utilities.lua")

local alignVerts = {"BOTTOM", "CENTER", "TOP"}
local alignHorizs = {"LEFT", "CENTER", "RIGHT"}
local orientations = {"HORIZONTAL", "VERTICAL"}

local defaults = {
    msg = "Lorem ipsum dolor sit amet",
    fillClr = Color(255, 255, 255, 255),
    shadowClr = Color(0, 0, 0, 204),
    xOrigin = 0,
    yOrigin = 0,
    useShadow = true,
    orientation = "HORIZONTAL",
    alignHoriz = "LEFT",
    alignVert = "TOP",
    scale = 2,
    pullFocus = false
}

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

local function displayGlyph(image, glyph, clr, x, y, gw, gh)

    local len = gw * gh
    local lenn1 = len - 1

    for i = 0, lenn1, 1 do
        local shift = lenn1 - i
        local mark = (glyph >> shift) & 1
        if mark ~= 0 then
            image:drawPixel(x + (i % gw), y + (i // gw), clr)
        end
    end
end

local function displayGlyphNearest(image, glyph, clr, x, y, gw, gh, dw, dh)

    if gw == dw and gh == dh then
        return displayGlyph(image, glyph, clr, x, y, gw, gh)
    end

    local lenTrg = dw * dh
    local lenTrgn1 = lenTrg - 1
    local lenSrcn1 = gw * gh - 1
    local tx = gw / dw
    local ty = gh / dh
    local trunc = math.tointeger
    for k = 0, lenTrgn1, 1 do
        local xTrg = k % dw
        local yTrg = k // dw

        local xSrc = trunc(xTrg * tx)
        local ySrc = trunc(yTrg * ty)
        local idxSrc = ySrc * gw + xSrc

        local shift = lenSrcn1 - idxSrc
        local mark = (glyph >> shift) & 1
        if mark ~= 0 then
            image:drawPixel(x + xTrg, y + yTrg, clr)
        end
    end
end

local function displayStringVert(lut, image, chars, clr, x, y, gw, gh, scale)

    local writeChar = y
    local writeLine = x
    local charLen = #chars

    local dw = gw * scale
    local dh = gh * scale
    local scale2 = scale + scale

    for i = 1, charLen, 1 do
        local ch = chars[i]
        if ch == '\n' then
            writeLine = writeLine + dw + scale2
            writeChar = y
        else
            local glyph = lut[ch]
            glyph = rotateCcw(glyph, gw, gh)

            displayGlyphNearest(image, glyph, clr, writeLine, writeChar, gh, gw, dh, dw)
            writeChar = writeChar - dh + scale
        end
    end
end

local function displayStringHoriz(lut, image, chars, clr, x, y, gw, gh, scale)

    local writeChar = x
    local writeLine = y
    local charLen = #chars

    local dw = gw * scale
    local dh = gh * scale
    local scale2 = scale + scale

    for i = 1, charLen, 1 do
        local ch = chars[i]
        -- print(ch)
        if ch == '\n' then
            -- Add 2, not 1, due to drop shadow.
            writeLine = writeLine + dh + scale2
            writeChar = x
        else
            local glyph = lut[ch]
            -- print(glyph)

            displayGlyphNearest(image, glyph, clr, writeChar, writeLine, gw, gh, dw, dh)
            writeChar = writeChar + dw + scale
        end
    end
end

local dlg = Dialog {
    title = "Insert Text"
}

dlg:entry{
    id = "msg",
    label = "Message",
    text = defaults.msg,
    focus = "false"
}

dlg:number{
    id = "xOrigin",
    label = "Origin:",
    text = string.format("%.1f", defaults.xOrigin),
    decimals = 5
}

dlg:number{
    id = "yOrigin",
    text = string.format("%.1f", defaults.yOrigin),
    decimals = 5
}

dlg:slider{
    id = "scale",
    label = "Scale:",
    min = 1,
    max = 24,
    value = defaults.scale
}

dlg:combobox{
    id = "orientation",
    label = "Orientation:",
    option = defaults.orientation,
    options = orientations
}

dlg:combobox{
    id = "alignHoriz",
    label = "Line:",
    option = defaults.alignHoriz,
    options = alignHorizs
}

dlg:combobox{
    id = "alignVert",
    label = "Char:",
    option = defaults.alignVert,
    options = alignVerts
}

dlg:check{
    id = "useShadow",
    label = "Drop Shadow:",
    selected = defaults.useShadow,
    onclick = function()
        dlg:modify{
            id = "shadowClr",
            visible = dlg.data.useShadow
        }
    end
}

dlg:color{
    id = "fillClr",
    label = "Fill:",
    color = defaults.fillClr
}

dlg:color{
    id = "shadowClr",
    label = "Shadow:",
    color = defaults.shadowClr,
    visible = defaults.useShadow
}

dlg:button{
    id = "ok",
    text = "OK",
    focus = defaults.pullFocus,
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
                local useShadow = args.useShadow
                local orientation = args.orientation
                local alignHoriz = args.alignHoriz
                local alignVert = args.alignVert
                local scale = args.scale

                -- QUERY: Disallow alpha in fill color?
                -- This is due to the limitation of setting
                -- pixels w/ drawPixel rather than compositing.
                if useShadow then
                    hexFill = 0xff000000 | hexFill
                end

                -- Create layer, cel.
                local layer = sprite:newLayer()
                local frame = app.activeFrame or 1
                local cel = sprite:newCel(layer, frame)
                local image = cel.image

                -- Validate message.
                local msg = args.msg
                local msgLen = #msg
                if msg == nil or msgLen < 1 then
                    msg = "Lorem ipsum\ndolor sit amet"
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

                local dw = gw * scale
                local dh = gh * scale

                local displayString = displayStringHoriz
                if orientation == "VERTICAL" then
                    displayString = displayStringVert

                    -- Because of rotation pivot,
                    -- characters need to be shifted up
                    -- by one glyph.
                    yLoc = yLoc - dw

                    if alignHoriz == "CENTER" then
                        local dwLen = msgLen * (dw + scale)
                        yLoc = yLoc + dwLen // 2
                    elseif alignHoriz == "RIGHT" then
                        local dwLen = msgLen * (dw + scale)
                        yLoc = yLoc + dwLen
                    end

                    if alignVert == "CENTER" then
                        xLoc = xLoc - dh // 2
                    elseif alignVert == "BOTTOM" then
                        xLoc = xLoc - dh
                    end
                else

                    -- Horizontal case is default case.
                    if alignHoriz == "CENTER" then
                        local dwLen = msgLen * (dw + scale)
                        xLoc = xLoc - dwLen // 2
                    elseif alignHoriz == "RIGHT" then
                        local dwLen = msgLen * (dw + scale)
                        xLoc = xLoc - dwLen
                    end

                    if alignVert == "CENTER" then
                        yLoc = yLoc - dh // 2
                    elseif alignVert == "BOTTOM" then
                        yLoc = yLoc - dh
                    end
                end

                -- Display string, optionally with shadow.
                if useShadow then
                    displayString(lut, image, chars, hexShd, xLoc, yLoc + scale, gw, gh, scale)
                end
                displayString(lut, image, chars, hexFill, xLoc, yLoc, gw, gh, scale)

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

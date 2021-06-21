dofile("../support/aseutilities.lua")

local defaults = {
    msg = "Lorem ipsum dolor sit amet",
    fillClr = Color(255, 255, 255, 255),
    shdColor = Color(0, 0, 0, 204),
    xOrigin = 0,
    yOrigin = 0,
    useShadow = true,
    orientation = "HORIZONTAL",
    alignHoriz = "LEFT",
    alignVert = "TOP",
    scale = 2,
    pullFocus = false
}

local dlg = Dialog {
    title = "Insert Text"
}

dlg:entry {
    id = "msg",
    label = "Message",
    text = defaults.msg,
    focus = "false"
}

dlg:number {
    id = "xOrigin",
    label = "Origin:",
    text = string.format("%.1f", defaults.xOrigin),
    decimals = 5
}

dlg:number {
    id = "yOrigin",
    text = string.format("%.1f", defaults.yOrigin),
    decimals = 5
}

dlg:slider {
    id = "scale",
    label = "Scale:",
    min = 1,
    max = 24,
    value = defaults.scale
}

dlg:combobox {
    id = "orientation",
    label = "Orientation:",
    option = defaults.orientation,
    options = AseUtilities.ORIENTATIONS
}

dlg:combobox {
    id = "alignHoriz",
    label = "Line:",
    option = defaults.alignHoriz,
    options = AseUtilities.GLYPH_ALIGN_HORIZ
}

dlg:combobox {
    id = "alignVert",
    label = "Char:",
    option = defaults.alignVert,
    options = AseUtilities.GLYPH_ALIGN_VERT
}

dlg:check {
    id = "useShadow",
    label = "Drop Shadow:",
    selected = defaults.useShadow,
    onclick = function()
        dlg:modify{
            id = "shdColor",
            visible = dlg.data.useShadow
        }
    end
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

dlg:button {
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
                local hexShd = args.shdColor.rgbaPixel
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

                local displayString = AseUtilities.drawStringHoriz
                if orientation == "VERTICAL" then
                    displayString = AseUtilities.drawStringVert

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

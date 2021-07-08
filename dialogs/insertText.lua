dofile("../support/aseutilities.lua")

local defaults = {
    msg = "Lorem ipsum dolor sit amet",
    animate = false,
    fillClr = Color(255, 255, 255, 255),
    shdColor = Color(0, 0, 0, 204),
    xOrigin = 0,
    yOrigin = 0,
    useShadow = true,
    orientation = "HORIZONTAL",
    alignLine = "LEFT",
    alignChar = "TOP",
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

dlg:check {
    id = "animate",
    label = "Animate:",
    selected = defaults.animate
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
    option = defaults.alignLine,
    options = AseUtilities.GLYPH_ALIGN_HORIZ
}

dlg:combobox {
    id = "alignVert",
    label = "Char:",
    option = defaults.alignChar,
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

local function slice (tbl, start, finish)
    -- https://stackoverflow.com/questions/
    -- 39802578/in-lua-array-sub-element
    local pos = 1
    local sl = {}
    local stop = finish

    -- if tbl[finish] == ' ' then
    --     stop = stop - 1
    -- end

    for i = start, stop, 1 do
        sl[pos] = tbl[i]
        pos = pos + 1
    end

    return sl
end

local function setOffset(
    xOrigin, yOrigin, msgLen, orientation,
    dw, dh, scale, alignLine, alignChar)

    local xLoc = xOrigin
    local yLoc = yOrigin

    if orientation == "VERTICAL" then
        yLoc = yLoc - dw

        if alignLine == "CENTER" then
            local dwLen = msgLen * (dw - scale)
            yLoc = yLoc + dwLen // 2
        elseif alignLine == "RIGHT" then
            local dwLen = msgLen * (dw - scale)
            yLoc = yLoc + dwLen
        end

        if alignChar == "CENTER" then
            xLoc = xLoc - dh // 2
        elseif alignChar == "BOTTOM" then
            xLoc = xLoc - dh
        end
    else
        -- Horizontal case is default case.
        if alignLine == "CENTER" then
            local dwLen = msgLen * (dw + scale)
            xLoc = xLoc - dwLen // 2
        elseif alignLine == "RIGHT" then
            local dwLen = msgLen * (dw + scale)
            xLoc = xLoc - dwLen
        end

        if alignChar == "CENTER" then
            yLoc = yLoc - dh // 2
        elseif alignChar == "BOTTOM" then
            yLoc = yLoc - dh
        end
    end

    return xLoc, yLoc
end

dlg:button {
    id = "confirm",
    text = "OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        local sprite = app.activeSprite
        if sprite then

            -- Constants, as far as we're concerned.
            local lut = Utilities.GLYPH_LUT
            local gw = 8
            local gh = 8

            -- Unpack user inputs.
            local hexFill = args.fillClr.rgbaPixel
            local hexShd = args.shdColor.rgbaPixel
            local xOrigin = args.xOrigin or 0
            local yOrigin = args.yOrigin or 0
            local useShadow = args.useShadow
            local orientation = args.orientation
            local alignLine = args.alignHoriz
            local alignChar = args.alignVert
            local scale = args.scale
            local animate = args.animate

            -- Create layer, cel.
            local layer = sprite:newLayer()

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
            local staticChars = {}
            for i = 1, msgLen, 1 do
                staticChars[i] = msg:sub(i, i)
            end

            local dw = gw * scale
            local dh = gh * scale

            local displayString = nil
            if orientation == "VERTICAL" then
                displayString = AseUtilities.drawStringVert
            else
                displayString = AseUtilities.drawStringHoriz
            end

            if animate then

                for i = 1, msgLen, 1 do

                    local animFrame = sprite:newEmptyFrame()
                    local animCel = sprite:newCel(layer, animFrame)
                    local animImage = animCel.image
                    local sl = slice(staticChars, 1, i)
                    local slLen = #sl

                    local xLoc, yLoc = setOffset(
                        xOrigin, yOrigin, slLen, orientation,
                        dw, dh, scale, alignLine, alignChar)

                    if useShadow then
                        displayString(
                            lut, animImage, sl, hexShd,
                            xLoc, yLoc + scale, gw, gh, scale)
                    end
                    displayString(
                        lut, animImage, sl, hexFill,
                        xLoc, yLoc, gw, gh, scale)
                end

            else

                local staticFrame = app.activeFrame or 1
                local staticCel = sprite:newCel(layer, staticFrame)
                local staticImage = staticCel.image

                local xLoc, yLoc = setOffset(
                    xOrigin, yOrigin, msgLen, orientation,
                    dw, dh, scale, alignLine, alignChar)

                if useShadow then
                    displayString(
                        lut, staticImage, staticChars, hexShd,
                        xLoc, yLoc + scale, gw, gh, scale)
                end
                displayString(
                    lut, staticImage, staticChars, hexFill,
                    xLoc, yLoc, gw, gh, scale)

            end

            app.refresh()
        else
            app.alert("There is no active sprite.")
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

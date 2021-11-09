dofile("../../support/aseutilities.lua")

local defaults = {
    expand = false,
    padding = 0,
    pullFocus = false
}

local dlg = Dialog { title = "Trim Sprite" }

dlg:newrow { always = false }

dlg:check {
    id = "expand",
    label = "Expand:",
    selected = defaults.expand
}

dlg:newrow { always = false }

dlg:slider {
    id = "padding",
    label = "Padding:",
    min = 0,
    max = 32,
    value = defaults.padding
}

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert("There is no active sprite.")
            return
        end

        -- Cache global functions used in loop.
        local trim = AseUtilities.trimImageAlpha
        local min = math.min
        local max = math.max

        -- Unpack sprite attributes.
        local alphaIndex = activeSprite.transparentColor
        local colorMode = activeSprite.colorMode
        local spriteWidth = activeSprite.width
        local spriteHeight = activeSprite.height

        -- Unpack arguments.
        local args = dlg.data
        local expand = args.expand
        local padding = args.padding or defaults.padding

        local xMin = 2147483647
        local yMin = 2147483647
        local xMax = -2147483648
        local yMax = -2147483648

        local cels = activeSprite.cels
        local celsLen = #cels
        for i = 1, celsLen, 1 do
            local cel = cels[i]
            local celPos = cel.position
            local celImg = cel.image
            local trimmed, xTrm, yTrm = trim(celImg, 0, alphaIndex)

            local tlx = celPos.x + xTrm
            local tly = celPos.y + yTrm
            local brx = tlx + trimmed.width
            local bry = tly + trimmed.height

            if tlx < xMin then xMin = tlx end
            if tly < yMin then yMin = tly end
            if brx > xMax then xMax = brx end
            if bry > yMax then yMax = bry end

            cel.position = Point(tlx, tly)
            cel.image = trimmed
        end

        if xMax > xMin and yMax > yMin then
            if not expand then
                xMin = max(0, xMin)
                yMin = max(0, yMin)
                xMax = min(spriteWidth, xMax)
                yMax = min(spriteHeight, yMax)
            end

            local pad2 = padding + padding
            activeSprite:crop(
                xMin - padding,
                yMin - padding,
                pad2 + xMax - xMin,
                pad2 + yMax - yMin)
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
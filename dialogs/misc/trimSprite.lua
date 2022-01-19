dofile("../../support/aseutilities.lua")

local defaults = {
    expand = false,
    cropCels = true,
    padding = 0,
    pullFocus = false
}

local dlg = Dialog { title = "Trim Sprite" }

dlg:radio {
    id = "cropCels",
    label = "Crop",
    text = "Cels",
    selected = defaults.cropCels,
    onclick = function()
        local args = dlg.data
        dlg:modify {
            id = "expand",
            selected = not args.cropCels
        }
    end
}

dlg:newrow { always = false }

dlg:radio {
    id = "expand",
    label = "Expand",
    text = "Sprite",
    selected = defaults.expand,
    onclick = function()
        local args = dlg.data
        dlg:modify {
            id = "cropCels",
            selected = not args.expand
        }
    end
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
        local trimAlphaFunc = AseUtilities.trimImageAlpha
        local trimCelFunc = AseUtilities.trimCelToSprite
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
        local cropCels = args.cropCels
        local padding = args.padding or defaults.padding

        local xMin = 2147483647
        local yMin = 2147483647
        local xMax = -2147483648
        local yMax = -2147483648

        local cels = activeSprite.cels
        local celsLen = #cels
        app.transaction(function()
            for i = 1, celsLen, 1 do
                local cel = cels[i]
                local celPos = cel.position
                local celImg = cel.image
                local trimmed, xTrm, yTrm = trimAlphaFunc(celImg, 0, alphaIndex)

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
        end)

        if xMax > xMin and yMax > yMin then
            if not expand then
                xMin = max(0, xMin)
                yMin = max(0, yMin)
                xMax = min(spriteWidth, xMax)
                yMax = min(spriteHeight, yMax)
            end

            activeSprite:crop(
                xMin, yMin,
                xMax - xMin, yMax - yMin)

            if cropCels then
                app.transaction(function()
                    for i = 1, celsLen, 1 do
                        local cel = cels[i]
                        trimCelFunc(cel, activeSprite)
                    end
                end)
            end

            if padding > 0 then
                local pad2 = padding + padding
                activeSprite:crop(
                    -padding, -padding,
                    activeSprite.width + pad2,
                    activeSprite.height + pad2)
            end

            -- Resizing the sprite can be disorienting,
            -- so fit it to the screen afterward.
            app.command.FitScreen()
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
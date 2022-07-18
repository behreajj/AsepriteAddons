dofile("../../support/aseutilities.lua")

local defaults = {
    expand = false,
    cropCels = true,
    padding = 0,
    omitHidden = false,
    pullFocus = false
}

-- Also used in layersExport.
local function appendChildren(
    layer, array,
    omitHidden, checkTilemaps)

    if layer.isVisible or (not omitHidden) then
        if layer.isGroup then
            local childLayers = layer.layers
            local lenChildLayers = #childLayers
            local i = 0
            while i < lenChildLayers do
                i = i + 1
                local childLayer = childLayers[i]
                appendChildren(childLayer, array,
                    omitHidden, checkTilemaps)
            end
        elseif (not layer.isReference)
            and (not layer.isBackground) then
            local isTilemap = false
            if checkTilemaps then
                isTilemap = layer.isTilemap
            end

            if not isTilemap then
                table.insert(array, layer)
            end
        end
    end

    return array
end

local dlg = Dialog { title = "Trim Sprite" }

dlg:radio {
    id = "cropCels",
    label = "Crop:",
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
    label = "Expand:",
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

dlg:check {
    id = "omitHidden",
    label = "Omit Hidden:",
    text = "Layers",
    selected = defaults.omitHidden
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
            app.alert {
                title = "Error",
                text = "There is no active sprite." }
            return
        end

        -- Cache global functions used in loop.
        local trimAlphaFunc = AseUtilities.trimImageAlpha
        local trimCelFunc = AseUtilities.trimCelToSprite
        local min = math.min
        local max = math.max

        -- Version
        local version = app.version
        local checkTilemaps = version.major >= 1
            and version.minor >= 3

        -- Unpack sprite attributes.
        local alphaIndex = activeSprite.transparentColor
        local spriteWidth = activeSprite.width
        local spriteHeight = activeSprite.height

        -- Unpack arguments.
        local args = dlg.data
        local expand = args.expand
        local cropCels = args.cropCels
        local omitHidden = args.omitHidden
        local padding = args.padding or defaults.padding

        -- Get leaf layers with cel content.
        local layers = activeSprite.layers
        local lenLayers = #layers
        local leaves = {}
        local g = 0
        while g < lenLayers do g = g + 1
            appendChildren(layers[g], leaves,
                omitHidden, checkTilemaps)
        end

        -- Find cels at intersection of layers and frames.
        local frames = activeSprite.frames
        local lenFrames = #frames
        local lenLeaves = #leaves
        local cels = {}
        local lenCels = 0
        local h = 0
        while h < lenLeaves do h = h + 1
            local leaf = leaves[h]
            local i = 0
            while i < lenFrames do i = i + 1
                local cel = leaf:cel(frames[i])
                if cel then
                    lenCels = lenCels + 1
                    cels[lenCels] = cel
                end
            end
        end

        local xMin = 2147483647
        local yMin = 2147483647
        local xMax = -2147483648
        local yMax = -2147483648

        app.transaction(function()
            local j = 0
            while j < lenCels do j = j + 1
                local cel = cels[j]
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
                    local k = 0
                    while k < lenCels do k = k + 1
                        trimCelFunc(cels[k], activeSprite)
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
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }

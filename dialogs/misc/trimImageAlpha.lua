dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    padding = 0,
    target = "ACTIVE",
    pullFocus = false
}

local dlg = Dialog { title = "Trim Image Alpha" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:slider {
    id = "padding",
    label = "Padding:",
    min = 0,
    max = 32,
    value = defaults.padding
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local args = dlg.data
        local target = args.target
            or defaults.target --[[@as string]]
        local padding = args.padding
            or defaults.padding --[[@as integer]]

        -- Tile map layers should not be trimmed.
        local checkTilemaps = AseUtilities.tilesSupport()
        local alphaMask = activeSprite.transparentColor

        local cels = {}
        if target == "ACTIVE" then
            local activeCel = app.activeCel
            if activeCel then
                cels[1] = activeCel
            end
        elseif target == "RANGE" then
            local images = app.range.images
            local lenImgs = #images
            local i = 0
            while i < lenImgs do i = i + 1
                cels[i] = images[i].cel
            end
        else
            local frIdcs = {}
            local lenFrames = #activeSprite.frames
            local i = 0
            while i < lenFrames do i = i + 1
                frIdcs[i] = i
            end

            local appRange = app.range
            appRange.frames = frIdcs

            local images = appRange.images
            local lenImgs = #images
            local j = 0
            while j < lenImgs do j = j + 1
                cels[j] = images[j].cel
            end

            appRange:clear()
        end

        local lenCels = #cels
        local trimImage = AseUtilities.trimImageAlpha
        app.transaction(function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel = cels[i]
                local layer = cel.layer
                local layerIsTilemap = false
                if checkTilemaps then
                    layerIsTilemap = layer.isTilemap
                end

                if layerIsTilemap then
                    -- Tile map layers should only belong to
                    -- .aseprite files, and hence not need this.
                    -- elseif layer.isEditable then
                else
                    local trgImg, x, y = trimImage(
                        cel.image, padding, alphaMask)
                    local srcPos = cel.position
                    cel.position = Point(srcPos.x + x, srcPos.y + y)
                    cel.image = trgImg
                end
            end
        end)

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
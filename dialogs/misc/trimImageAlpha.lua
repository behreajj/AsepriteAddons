dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    padding = 0,
    target = "ALL",
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
        if activeSprite then
            local args = dlg.data
            local target = args.target
            local padding = args.padding

            -- Tile map layers should not be trimmed, so check
            -- if Aseprite is newer than 1.3.
            local version = app.version
            local checkForTilemaps = false
            if version.major >= 1 and version.minor >= 3 then
                checkForTilemaps = true
            end

            local alphaIndex = activeSprite.transparentColor

            local cels = {}
            if target == "ACTIVE" then
                local activeCel = app.activeCel
                if activeCel then
                    cels[1] = activeCel
                end
            elseif target == "RANGE" then
                cels = app.range.cels
            else
                cels = activeSprite.cels
            end

            local celsLen = #cels
            local trimImage = AseUtilities.trimImageAlpha
            app.transaction(function()
                for i = 1, celsLen, 1 do
                    local cel = cels[i]
                    if cel then
                        local layer = cel.layer
                        local layerIsTilemap = false
                        if checkForTilemaps then
                            layerIsTilemap = layer.isTilemap
                        end

                        if layerIsTilemap then
                            -- Tile map layers should only belong to
                            -- .aseprite files, and hence not need this.
                        else
                            local srcImg = cel.image
                            local trgImg, x, y = trimImage(srcImg, padding, alphaIndex)
                            local srcPos = cel.position
                            cel.position = Point(srcPos.x + x, srcPos.y + y)
                            cel.image = trgImg
                        end
                    end
                end
            end)

            app.refresh()
        else
            app.alert("There is no active sprite.")
        end
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
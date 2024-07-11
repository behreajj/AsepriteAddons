dofile("../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }

local defaults <const> = {
    padding = 0,
    target = "ACTIVE",
    includeLocked = false,
    includeHidden = true,
    includeTiles = true,
    pullFocus = false
}

local dlg <const> = Dialog { title = "Trim Image Alpha" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:check {
    id = "includeLocked",
    label = "Include:",
    text = "&Locked",
    selected = defaults.includeLocked
}

dlg:check {
    id = "includeHidden",
    text = "&Hidden",
    selected = defaults.includeHidden
}

dlg:newrow { always = false }

dlg:check {
    id = "includeTiles",
    text = "&Tiles",
    selected = defaults.includeTiles
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local activeLayer <const> = site.layer
        if not activeLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
            }
            return
        end

        local activeFrame <const> = site.frame
        if not activeFrame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
            }
            return
        end

        local args <const> = dlg.data
        local target <const> = args.target or defaults.target --[[@as string]]
        local padding <const> = args.padding or defaults.padding --[[@as integer]]
        local includeLocked <const> = args.includeLocked --[[@as boolean]]
        local includeHidden <const> = args.includeHidden --[[@as boolean]]
        local includeTiles <const> = args.includeTiles --[[@as boolean]]

        local trgCels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeSprite.frames, target,
            includeLocked, includeHidden, includeTiles, false)
        local lenTrgCels <const> = #trgCels
        if lenTrgCels <= 0 then
            app.alert {
                title = "Error",
                text = "No eligible cels were selected."
            }
            return
        end

        local trimImage <const> = AseUtilities.trimImageAlpha
        local trimMap <const> = AseUtilities.trimMapAlpha
        local alphaIndex <const> = activeSprite.transparentColor

        app.transaction("Trim Images", function()
            local i = 0
            while i < lenTrgCels do
                i = i + 1

                local cel <const> = trgCels[i]
                local srcImg <const> = cel.image
                local layer <const> = cel.layer

                local xTrm = 0
                local yTrm = 0
                local trimmed = srcImg

                if layer.isTilemap then
                    local tileSet <const> = layer.tileset
                    if tileSet then
                        local tileDim <const> = tileSet.grid.tileSize
                        local wTile <const> = tileDim.width
                        local hTile <const> = tileDim.height

                        trimmed, xTrm, yTrm = trimMap(
                            srcImg, alphaIndex, wTile, hTile)
                    end
                else
                    trimmed, xTrm, yTrm = trimImage(
                        srcImg, padding, alphaIndex)
                end

                local srcPos <const> = cel.position
                cel.position = Point(srcPos.x + xTrm, srcPos.y + yTrm)
                cel.image = trimmed
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

dlg:show {
    autoscrollbars = true,
    wait = false
}
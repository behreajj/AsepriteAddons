dofile("../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }

local defaults <const> = {
    padding = 0,
    target = "ACTIVE",
    includeLocked = false,
    includeHidden = true,
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

        local trgCels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            includeLocked, includeHidden, false, false)

        local lenTrgCels <const> = #trgCels
        local trimImage <const> = AseUtilities.trimImageAlpha
        local alphaMask <const> = activeSprite.transparentColor

        app.transaction("Trim Images", function()
            local i = 0
            while i < lenTrgCels do
                i = i + 1
                local cel <const> = trgCels[i]
                local trgImg <const>, x <const>, y <const> = trimImage(
                    cel.image, padding, alphaMask)
                local srcPos <const> = cel.position
                cel.position = Point(srcPos.x + x, srcPos.y + y)
                cel.image = trgImg
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
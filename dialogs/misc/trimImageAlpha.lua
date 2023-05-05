dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    padding = 0,
    target = "ACTIVE",
    includeLocked = false,
    includeHidden = true,
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
        local includeLocked = args.includeLocked --[[@as boolean]]
        local includeHidden = args.includeHidden --[[@as boolean]]

        local activeLayer = app.activeLayer
        local activeFrame = app.activeFrame
        local trgCels = AseUtilities.filterCels(
            activeSprite, activeLayer, activeFrame, target,
            includeLocked, includeHidden, false, false)

        local lenTrgCels = #trgCels
        local trimImage = AseUtilities.trimImageAlpha
        local alphaMask = activeSprite.transparentColor

        app.transaction("Trim Images", function()
            local i = 0
            while i < lenTrgCels do
                i = i + 1
                local cel = trgCels[i]
                local trgImg, x, y = trimImage(
                    cel.image, padding, alphaMask)
                local srcPos = cel.position
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
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
                        local srcImg = cel.image
                        -- if srcImg then
                        local trgImg, x, y = trimImage(srcImg, padding, alphaIndex)
                        local srcPos = cel.position
                        cel.position = Point(srcPos.x + x, srcPos.y + y)
                        cel.image = trgImg
                        -- end
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
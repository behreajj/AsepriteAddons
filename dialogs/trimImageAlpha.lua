dofile("../support/aseutilities.lua")

local defaults = {
    padding = 0,
    pullFocus = false
}

local dlg = Dialog { title = "Trim Image Alpha" }

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
        -- TODO: Consider making this a "trim cel image" dialog
        -- with a "ALPHA" and a "CANVAS" mode.

        local activeSprite = app.activeSprite
        if activeSprite then
            local args = dlg.data
            local padding = args.padding

            local oldMode = activeSprite.colorMode
            app.command.ChangePixelFormat { format = "rgb" }

            local cels = activeSprite.cels
            local celsLen = #cels
            local trimImage = AseUtilities.trimImageAlpha
            app.transaction(function()
                for i = 1, celsLen, 1 do
                    local cel = cels[i]
                    local srcImg = cel.image
                    if srcImg then
                        local trgImg, x, y = trimImage(srcImg, padding)
                        local srcPos = cel.position
                        cel.position = Point(srcPos.x + x, srcPos.y + y)
                        cel.image = trgImg
                    end
                end
            end)

            AseUtilities.changePixelFormat(oldMode)
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
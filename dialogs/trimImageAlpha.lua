dofile("../support/aseutilities.lua")

local defaults = {
    pullFocus = false
}

local dlg = Dialog { title = "Trim Image Alpha" }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- TODO: Consider making this a "trim cel image" dialog
        -- with a "ALPHA" and a "CANVAS" mode.

        local activeSprite = app.activeSprite
        if activeSprite then
            local cels = activeSprite.cels
            local celsLen = #cels
            local trimImage = AseUtilities.trimImageAlpha
            for i = 1, celsLen, 1 do
                local cel = cels[i]
                local srcImg = cel.image
                if srcImg then
                    local trgImg, x, y = trimImage(srcImg)
                    local srcPos = cel.position
                    cel.position = Point(srcPos.x + x, srcPos.y + y)
                    cel.image = trgImg
                end
            end

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
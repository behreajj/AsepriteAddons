dofile("../support/aseutilities.lua")

local defaults = {
    pullFocus = false
}

local dlg = Dialog { title = "Trim Image Alpha" }

-- dlg:slider {
--     id = "frameStart",
--     label = "Start:",
--     min = 1,
--     max = 128,
--     value = defaults.frameStart,
--     visible = defaults.mode == "FRAMES"
-- }

-- dlg:newrow { always = false }

-- dlg:slider {
--     id = "frameCount",
--     label = "Count:",
--     min = 2,
--     max = 96,
--     value = defaults.frameCount,
--     visible = defaults.mode == "FRAMES"
-- }

-- dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
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
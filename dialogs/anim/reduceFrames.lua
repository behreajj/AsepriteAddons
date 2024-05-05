local defaults <const> = {
    delete = 1,
    skip = 1,
    offset = 0,
    pullFocus = false
}

local dlg <const> = Dialog { title = "Reduce Frames" }

dlg:slider {
    id = "delete",
    label = "Delete:",
    min = 1,
    max = 64,
    value = defaults.delete
}

dlg:newrow { always = false }

dlg:slider {
    id = "skip",
    label = "Skip:",
    min = 1,
    max = 64,
    value = defaults.skip
}

dlg:newrow { always = false }

dlg:slider {
    id = "offset",
    label = "Offset:",
    min = 0,
    max = 64,
    value = defaults.offset
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite <const> = app.site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local args <const> = dlg.data
        local delete = args.delete or defaults.delete --[[@as integer]]
        local skip <const> = args.skip or defaults.skip --[[@as integer]]
        local offset <const> = args.offset or defaults.offset --[[@as integer]]

        local frames <const> = activeSprite.frames
        local lenFrames <const> = #frames

        delete = math.min(delete, lenFrames - 1)
        local all <const> = delete + skip

        app.transaction("Reduce Frames", function()
            local i = lenFrames
            while i > 0 do
                i = i - 1
                if (i + offset) % all < delete then
                    activeSprite:deleteFrame(frames[1 + i])
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

dlg:show {
    autoscrollbars = true,
    wait = false
}
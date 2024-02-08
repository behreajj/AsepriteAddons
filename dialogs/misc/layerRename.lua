local dlg <const> = Dialog { title = "Layer Rename" }

dlg:entry {
    id = "nameEntry",
    label = "Name:",
    focus = true,
    text = "Layer"
}

dlg:newrow { always = false }

dlg:check {
    id = "reverse",
    label = "Order:",
    text = "&Reverse",
    selected = false
}

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local tlHidden <const> = not app.preferences.general.visible_timeline
        if tlHidden then
            app.command.Timeline { open = true }
        end

        local range <const> = app.range
        if range.sprite == sprite then
            local rangeLayers <const> = range.layers
            local lenRangeLayers <const> = #rangeLayers
            if lenRangeLayers > 0 then
                ---@type Layer[]
                local sortedLayers <const> = {}
                local h = 0
                while h < lenRangeLayers do
                    -- Exclude reference or background?
                    h = h + 1
                    sortedLayers[h] = rangeLayers[h]
                end

                -- TODO: Exclude empty name entry?
                local args <const> = dlg.data
                local nameEntry <const> = args.nameEntry --[[@as string]]
                local reverse <const> = args.reverse --[[@as boolean]]

                local lenSortedLayers <const> = #sortedLayers
                if lenSortedLayers == 1 then
                    app.transaction("Rename Layer", function()
                        sortedLayers[1].name = nameEntry
                    end)
                else
                    table.sort(sortedLayers, function(a, b)
                        local apid <const> = a.parent.id
                        local bpid <const> = b.parent.id
                        if apid == bpid then
                            return a.stackIndex < b.stackIndex
                        end
                        return apid < bpid
                    end)

                    local format <const> = "%s %d"
                    local strfmt <const> = string.format

                    app.transaction("Rename Layers", function()
                        local i = 0
                        while i < lenSortedLayers do
                            i = i + 1
                            local layer <const> = sortedLayers[i]
                            local n <const> = reverse
                                and lenSortedLayers + 1 - i
                                or i
                            layer.name = strfmt(format, nameEntry, n)
                        end
                    end)
                end
            end
        end

        if tlHidden then
            app.command.Timeline { close = true }
        end

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
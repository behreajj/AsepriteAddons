-- TODO: Refine this to be able to get a square of w, h from a top
-- left corner x, y given the number of columns in a palette to make
-- it form a square. Perhaps consider toggle from 1D to 2D.
local dlg = Dialog { title = "Palette Subset" }

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = "ACTIVE",
    options = { "ACTIVE", "FILE", "PRESET" },
    onchange = function()
        local state = dlg.data.palType

        dlg:modify {
            id = "palFile",
            visible = state == "FILE"
        }

        dlg:modify {
            id = "palPreset",
            visible = state == "PRESET"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = { "gpl", "pal" },
    open = true,
    visible = false
}

dlg:newrow { always = false }

dlg:entry {
    id = "palPreset",
    text = "",
    focus = false,
    visible = false
}

dlg:newrow { always = false }

dlg:slider {
    id = "startIdx",
    label = "Scaled Index:",
    min = 0,
    max = 32,
    value = 0
}

dlg:newrow { always = false }

dlg:slider {
    id = "stride",
    label = "Stride:",
    min = 2,
    max = 32,
    value = 8
}

dlg:newrow { always = false }

dlg:slider {
    id = "cycle",
    label = "Cycle:",
    min = 0,
    max = 32,
    value = 0
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "OK",
    focus = false,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = app.activeSprite
            if sprite then

                local oldMode = sprite.colorMode
                app.command.ChangePixelFormat { format = "rgb" }

                local srcPal = nil
                local palType = args.palType
                if palType == "FILE" then
                    local fp =  args.palFile
                    if fp and #fp > 0 then
                        srcPal = Palette { fromFile = fp }
                    end
                elseif palType == "PRESET" then
                    local pr = args.palPreset
                    if pr and #pr > 0 then
                        srcPal = Palette { fromResource = pr }
                    end
                else
                    srcPal = sprite.palettes[1]
                end

                if srcPal then

                    local origin = args.startIdx
                    local stride = args.stride
                    local cycle = args.cycle
                    local sclOrig = stride * origin
                    local trgPal = Palette(stride)
                    local srcLen = #srcPal
                    for i = 0, stride - 1, 1 do
                        local j = (cycle + i) % stride
                        local k = (sclOrig + j) % srcLen
                        trgPal:setColor(i, srcPal:getColor(k))
                    end

                    sprite:setPalette(trgPal)
                else
                    app.alert("The source palette could not be found.")
                end

                if oldMode == ColorMode.INDEXED then
                    app.command.ChangePixelFormat { format = "indexed" }
                elseif oldMode == ColorMode.GRAY then
                    app.command.ChangePixelFormat { format = "gray" }
                end

                app.refresh()

            else
                app.alert("There is no active sprite.")
            end
        else
            app.alert("Dialog arguments are invalid.")
        end
    end
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
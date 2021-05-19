local function quantize(x, levels)
    return math.max(0.0, math.min(1.0,
       (math.ceil(x * levels) - 1.0)
       / (levels - 1.0)))

    -- return math.floor(0.5 + x * levels) / levels
end

local dlg = Dialog { title = "Palette Quantize" }

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
    id = "quantization",
    label = "Quantize:",
    min = 1,
    max = 128,
    value = 16
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
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
                    local ql = math.min(255, math.max(1, args.quantization))
                    local dictionary = {}
                    local idx = 0
                    local srcLen = #srcPal
                    for i = 1, srcLen, 1 do
                        local srcClr = srcPal:getColor(i - 1)

                        local ai = srcClr.alpha
                        local bi = srcClr.blue
                        local gi = srcClr.green
                        local ri = srcClr.red

                        local af = ai * 0.00392156862745098
                        local bf = bi * 0.00392156862745098
                        local gf = gi * 0.00392156862745098
                        local rf = ri * 0.00392156862745098

                        local aq = quantize(af, ql)
                        local bq = quantize(bf, ql)
                        local gq = quantize(gf, ql)
                        local rq = quantize(rf, ql)

                        local hq = math.tointeger(aq * 0xff + 0.5) << 0x18
                                 | math.tointeger(bq * 0xff + 0.5) << 0x10
                                 | math.tointeger(gq * 0xff + 0.5) << 0x08
                                 | math.tointeger(rq * 0xff + 0.5)

                        if not dictionary[hq] then
                            if aq > 0 then
                                idx = idx + 1
                                dictionary[hq] = idx
                            end
                        end

                    end

                    if idx > 0 then
                        local palette = Palette(idx)
                        for k, m in pairs(dictionary) do
                            local hex = k
                            palette:setColor(m - 1, hex)
                        end

                        sprite:setPalette(palette)
                    end

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
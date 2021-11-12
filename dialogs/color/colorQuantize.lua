dofile("../../support/clr.lua")

local dlg = Dialog { title = "Quantize Color" }

dlg:slider {
    id = "levels",
    label = "Levels:",
    min = 2,
    max = 96,
    value = 16
}

dlg:newrow { always = false }

dlg:check {
    id = "copyToLayer",
    label = "Copy To New Layer:",
    selected = true
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = false,
    onclick = function()
        local args = dlg.data
        local sprite = app.activeSprite
        if sprite then
            -- TODO: Update to use defaults table.
            local srcCel = app.activeCel
            if srcCel then
                local srcImg = srcCel.image
                if srcImg ~= nil then
                    local srcpxitr = srcImg:pixels()

                    -- Gather unique colors in image.
                    local srcDict = {}
                    for elm in srcpxitr do
                        srcDict[elm()] = true
                    end

                    -- Cache methods to local.
                    local fromHex = Clr.fromHex
                    local toHex = Clr.toHexUnchecked
                    local quantize = Clr.quantizeInternal

                    -- Find levels and 1.0 / levels.
                    local levels = args.levels
                    local delta = 1.0 / levels

                    -- Quantize colors, place in dictionary.
                    local trgDict = {}
                    for k, _ in pairs(srcDict) do
                        local srcClr = fromHex(k)
                        local qtzClr = quantize(srcClr, levels, delta)
                        trgDict[k] = toHex(qtzClr)
                    end

                    -- Clone image, replace color with quantized.
                    local trgImg = srcImg:clone()
                    local trgpxitr = trgImg:pixels()
                    for elm in trgpxitr do
                        elm(trgDict[elm()])
                    end

                    local copyToLayer = args.copyToLayer
                    if copyToLayer then
                        app.transaction(function()
                            local srcLayer = srcCel.layer
                            local trgLayer = sprite:newLayer()
                            trgLayer.name = srcLayer.name .. ".Quantized." .. levels
                            trgLayer.opacity = srcLayer.opacity
                            local srcFrame = srcCel.frame or sprite.frames[1]
                            local trgCel = sprite:newCel(
                                trgLayer, srcFrame,
                                trgImg, srcCel.position)
                            trgCel.opacity = srcCel.opacity
                        end)
                    else
                        srcCel.image = trgImg
                    end

                    app.refresh()
                else
                    app.alert("The cel has no image.")
                end
            else
                app.alert("There is no active cel.")
            end
        else
            app.alert("There is no active sprite.")
        end
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
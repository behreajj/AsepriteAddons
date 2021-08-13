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
            local srcCel = app.activeCel
            if srcCel then
                local srcImg = srcCel.image
                if srcImg ~= nil then
                    local srcpxitr = srcImg:pixels()

                    -- Gather unique colors in image.
                    local srcHexDict = {}
                    for elm in srcpxitr do
                        srcHexDict[elm()] = true
                    end

                    -- Cache methods to local.
                    local fromHex = Clr.fromHex
                    local toHex = Clr.toHexUnchecked
                    local quantize = Clr.quantizeInternal

                    -- Find levels and 1.0 / levels.
                    local levels = args.levels
                    local delta = 1.0 / levels

                    -- Quantize colors, place in dictionary.
                    local quantizedDict = {}
                    for k, _ in pairs(srcHexDict) do
                        local srcClr = fromHex(k)
                        local qtzClr = quantize(srcClr, levels, delta)
                        quantizedDict[k] = toHex(qtzClr)
                    end

                    -- Clone image, replace color with quantized.
                    local trgImg = srcImg:clone()
                    local trgpxitr = trgImg:pixels()
                    for elm in trgpxitr do
                        elm(quantizedDict[elm()])
                    end

                    local copyToLayer = args.copyToLayer
                    if copyToLayer then
                        local trgLayer = sprite:newLayer()
                        trgLayer.name = srcCel.layer.name .. ".Quantized." .. levels
                        local frame = app.activeFrame or 1
                        local trgCel = sprite:newCel(trgLayer, frame)
                        trgCel.image = trgImg
                        trgCel.position = srcCel.position
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
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
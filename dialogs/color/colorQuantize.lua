dofile("../../support/clr.lua")

local dlg = Dialog { title = "Quantize Color" }

dlg:slider {
    id = "levels",
    label = "Levels:",
    min = 2,
    max = 128,
    value = 32
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
    text = "OK",
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

                    local srcHexDict = {}
                    for elm in srcpxitr do
                        srcHexDict[elm()] = true
                    end

                    local levels = args.levels
                    local quantizedDict = {}
                    for k, _ in pairs(srcHexDict) do
                        local srcClr = Clr.fromHex(k)
                        local qtzClr = Clr.quantize(srcClr, levels)
                        quantizedDict[k] = Clr.toHex(qtzClr)
                    end

                    local trgImg = srcImg:clone()
                    local trgpxitr = trgImg:pixels()
                    for elm in trgpxitr do
                        elm(quantizedDict[elm()])
                    end

                    local copyToLayer = args.copyToLayer
                    if copyToLayer then
                        local trgLayer = sprite:newLayer()
                        trgLayer.name = srcCel.layer.name .. ".Quantized"
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
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
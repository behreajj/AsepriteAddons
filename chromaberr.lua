local dlg = Dialog { title="Chromatic Aberration" }

dlg:number {
    id = "xRed",
    label = "Red Shift X: ",
    text = string.format("%.1f", 0.0),
    decimals = 5
}

dlg:number {
    id = "yRed",
    label = "Red Shift Y: ",
    text = string.format("%.1f", 0.0),
    decimals = 5
}

dlg:number {
    id = "xGreen",
    label = "Green Shift X: ",
    text = string.format("%.1f", 0.0),
    decimals = 5
}

dlg:number {
    id = "yGreen",
    label = "Green Shift Y: ",
    text = string.format("%.1f", 0.0),
    decimals = 5
}

dlg:number {
    id = "xBlue",
    label = "Blue Shift X: ",
    text = string.format("%.1f", 0.0),
    decimals = 5
}

dlg:number {
    id = "yBlue",
    label = "Blue Shift Y: ",
    text = string.format("%.1f", 0.0),
    decimals = 5
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = app.activeSprite
            if sprite then
                local layer = app.activeLayer
                if layer and not layer.isGroup then
                    local cel = app.activeCel
                    if cel then

                        -- Create new layers.
                        local bkgLayer = sprite:newLayer()
                        local redLayer = sprite:newLayer()
                        local greenLayer = sprite:newLayer()
                        local blueLayer = sprite:newLayer()

                        -- Name layers.
                        bkgLayer.name = "Background"
                        redLayer.name = "Red"
                        greenLayer.name = "Green"
                        blueLayer.name = "Blue"

                        -- Color code layers.
                        bkgLayer.color = Color(0xff303030)
                        redLayer.color = Color(0xff0000ff)
                        greenLayer.color = Color(0xff00ff00)
                        blueLayer.color = Color(0xffff0000)

                        -- Set BlendMode to add.
                        redLayer.blendMode = BlendMode.ADDITION
                        greenLayer.blendMode = BlendMode.ADDITION
                        blueLayer.blendMode = BlendMode.ADDITION

                        -- Create cels.
                        local redCel = sprite:newCel(redLayer, cel.frame)
                        local greenCel = sprite:newCel(greenLayer, cel.frame)
                        local blueCel = sprite:newCel(blueLayer, cel.frame)

                        -- Acquire images.
                        local redImg = redCel.image
                        local greenImg = greenCel.image
                        local blueImg = blueCel.image

                        -- Fill background.
                        local bkgCel = sprite:newCel(bkgLayer, cel.frame)
                        local bkgImg = bkgCel.image
                        for elm in bkgImg:pixels() do
                            elm(0xff000000)
                        end

                        -- Cache source pixels.
                        local srcImg = cel.image
                        local srcItr = srcImg:pixels()
                        local i = 1
                        local px = {}
                        for srcClr in srcItr do
                            px[i] = srcClr()
                            i = i + 1
                        end

                        -- Red.
                        local i = 1
                        for elm in redImg:pixels() do
                            elm(0xff0000ff & px[i])
                            i = i + 1
                        end

                        -- Green.
                        local i = 1
                        for elm in greenImg:pixels() do
                            elm(0xff00ff00 & px[i])
                            i = i + 1
                        end

                        -- Blue.
                        local i = 1
                        for elm in blueImg:pixels() do
                            elm(0xffff0000 & px[i])
                            i = i + 1
                        end

                        -- Shift cels.
                        redCel.position = redCel.position
                            + Point(args.xRed, args.yRed)
                        greenCel.position = greenCel.position
                            + Point(args.xGreen, args.yGreen)
                        blueCel.position = blueCel.position
                            + Point(args.xBlue, args.yBlue)
                    end
                end
            end
        end
    end
}

dlg:show { wait = false }
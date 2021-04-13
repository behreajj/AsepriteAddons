local dlg = Dialog { title = "Chromatic Aberration" }

dlg:number {
    id = "xRed",
    label = "Red Shift:",
    text = string.format("%.1f", 0.0),
    decimals = 5
}

dlg:number {
    id = "yRed",
    text = string.format("%.1f", 0.0),
    decimals = 5
}

dlg:newrow { always = false }

dlg:number {
    id = "xGreen",
    label = "Green Shift:",
    text = string.format("%.1f", 0.0),
    decimals = 5
}

dlg:number {
    id = "yGreen",
    text = string.format("%.1f", 0.0),
    decimals = 5
}

dlg:newrow { always = false }

dlg:number {
    id = "xBlue",
    label = "Blue Shift:",
    text = string.format("%.1f", 0.0),
    decimals = 5
}

dlg:number {
    id = "yBlue",
    text = string.format("%.1f", 0.0),
    decimals = 5
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
                local srcLyr = app.activeLayer
                if srcLyr and not srcLyr.isGroup then
                    local srcCel = app.activeCel
                    if srcCel then
                        local srcImg = srcCel.image
                        local srcFrame = srcCel.frame
                        local srcPos = srcCel.position

                        local bkgLyr = sprite:newLayer()
                        bkgLyr.name = "Black"
                        bkgLyr.color = Color(48, 48, 48, 255)
                        local bkgCel = sprite:newCel(bkgLyr, srcFrame)
                        local bkgImg = bkgCel.image
                        local bkgItr = bkgImg:pixels()
                        local bkgClr = 0xff000000
                        for elm in bkgItr do elm(bkgClr) end

                        local redLyr = sprite:newLayer()
                        local greenLyr = sprite:newLayer()
                        local blueLyr = sprite:newLayer()

                        redLyr.name = "Red"
                        greenLyr.name = "Green"
                        blueLyr.name = "Blue"

                        redLyr.color = Color(192, 0, 0, 255)
                        greenLyr.color = Color(0, 192, 0, 255)
                        blueLyr.color = Color(0, 0, 192, 255)

                        -- Can these be composited together manually
                        -- in a new layer with normal blend mode?
                        redLyr.blendMode = BlendMode.ADDITION
                        greenLyr.blendMode = BlendMode.ADDITION
                        blueLyr.blendMode = BlendMode.ADDITION

                        local redCel = sprite:newCel(redLyr, srcFrame)
                        local greenCel = sprite:newCel(greenLyr, srcFrame)
                        local blueCel = sprite:newCel(blueLyr, srcFrame)

                        local redShift = Point(args.xRed, args.yRed)
                        local greenShift = Point(args.xGreen, args.yGreen)
                        local blueShift = Point(args.xBlue, args.yBlue)

                        redCel.position = srcPos + redShift
                        greenCel.position = srcPos + greenShift
                        blueCel.position = srcPos + blueShift

                        redCel.image = srcImg:clone()
                        greenCel.image = srcImg:clone()
                        blueCel.image = srcImg:clone()

                        local redImg = redCel.image
                        local greenImg = greenCel.image
                        local blueImg = blueCel.image

                        local rdItr = redImg:pixels()
                        local grItr = greenImg:pixels()
                        local blItr = blueImg:pixels()

                        local rdMsk = 0xff0000ff
                        local grMsk = 0xff00ff00
                        local blMsk = 0xffff0000

                        for elm in rdItr do elm(elm() & rdMsk) end
                        for elm in grItr do elm(elm() & grMsk) end
                        for elm in blItr do elm(elm() & blMsk) end

                        app.activeLayer = srcLyr
                        app.activeCel = srcCel
                        app.refresh()
                    else
                        app.alert("There is no active cel.")
                    end
                else
                    app.alert("There is no active layer.")
                end
            else
                app.alert("There is no active sprite.")
            end
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
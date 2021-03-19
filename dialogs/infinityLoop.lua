dofile("../support/mat3.lua")
dofile("../support/curve2.lua")
dofile("../support/utilities.lua")
dofile("../support/aseutilities.lua")

local defaults = {
    resolution = 32,
    frames = 1,
    dots = 1,
    dotOff = 15,
    angle = 0,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = Color(32, 32, 32, 255),
    fillClr = Color(255, 245, 215, 255),
    handles = 0
}

local dlg = Dialog { title = "Infinity Loop" }

dlg:slider {
    id = "resolution",
    label = "Resolution:",
    min = 1,
    max = 64,
    value = defaults.resolution
}

dlg:slider {
    id = "handles",
    label = "Handles:",
    min = 0,
    max = 255,
    value = defaults.handles
}

dlg:slider {
    id = "frames",
    label = "Frames:",
    min = 1,
    max = 64,
    value = defaults.frames
}

dlg:slider {
    id = "dots",
    label = "Dots:",
    min = 1,
    max = 16,
    value = defaults.frames
}

dlg:slider {
    id = "dotOff",
    label = "Dot Offset:",
    min = 0,
    max = 100,
    value = defaults.dotOff
}

dlg:slider {
    id = "angle",
    label = "Angle:",
    min = 0,
    max = 360,
    value = defaults.angle
}

dlg:number {
    id = "scale",
    label = "Scale:",
    text = string.format("%.1f", defaults.scale),
    decimals = 5
}

dlg:number {
    id = "xOrigin",
    label = "Origin X:",
    text = string.format("%.1f", defaults.xOrigin),
    decimals = 5
}

dlg:number {
    id = "yOrigin",
    label = "Origin Y:",
    text = string.format("%.1f", defaults.yOrigin),
    decimals = 5
}

dlg:check {
    id = "useStroke",
    label = "Use Stroke:",
    selected = defaults.useStroke
}

dlg:slider {
    id = "strokeWeight",
    label = "Stroke Weight:",
    min = 1,
    max = 64,
    value = defaults.strokeWeight
}

dlg:color {
    id = "strokeClr",
    label = "Stroke Color:",
    color = defaults.strokeClr
}

dlg:color {
    id = "fillClr",
    label = "Dot Color:",
    color = defaults.fillClr
}

-- Because ENTER is the key to start an animation loop,
-- dialog focus is set to false here.
dlg:button {
    id = "ok",
    text = "OK",
    focus = false,
    onclick = function()

        local args = dlg.data
        if args.ok then
            local curve = Curve2.infinity()

            local t = Mat3.fromTranslation(
                args.xOrigin,
                args.yOrigin)
            local r = Mat3.fromRotZ(math.rad(args.angle))
            local sclval = args.scale
            if sclval < 2.0 then sclval = 2.0 end
            local s = Mat3.fromScale(sclval, -sclval)
            local mat = t * r * s
            Utilities.mulMat3Curve2(mat, curve)

            local sprite = app.activeSprite
            if sprite == nil then
                sprite = Sprite(64, 64)
                app.activeSprite = sprite
            end

            local layer = sprite:newLayer()
            layer.name = curve.name
            local cel = sprite:newCel(layer, 1)

            AseUtilities.drawCurve2(
                curve,
                args.resolution,
                false,
                args.fillClr,
                args.useStroke,
                args.strokeClr,
                Brush(args.strokeWeight),
                cel,
                layer)

            if args.handles > 0 then
                local hlLyr = sprite:newLayer()
                hlLyr.name = curve.name .. ".Handles"
                hlLyr.opacity = args.handles
                AseUtilities.drawHandles2(
                    curve,
                    sprite:newCel(hlLyr, 1),
                    hlLyr)
            end

            local frames = args.frames
            if frames > 1 then
                app.transaction(function()

                    -- Allocate new frames.
                    local oldLen = #sprite.frames
                    local needed = math.max(0, frames - oldLen)
                    for i = 1, needed, 1 do
                        sprite:newEmptyFrame()
                    end

                    local animLyr = sprite:newLayer()
                    animLyr.name = curve.name .. ".Loop"

                    local frameToFac = 1.0 / frames
                    local dotCount = args.dots
                    local dotToFac = 1.0 / (dotCount - 1.0)
                    local offset = 0.01 * args.dotOff

                    -- Create new brushes and colors for contrails.
                    local animBrushes = {}
                    local animColors = {}
                    local dtr = args.fillClr.red
                    local dtg = args.fillClr.green
                    local dtb = args.fillClr.blue
                    for j = dotCount, 1, -1 do
                        local jFac = j / dotCount
                        local alpha = math.tointeger(0.5 + jFac * 255.0)
                        local animBrsh = Brush{ size = 3 + j }
                        local animClr = Color(dtr, dtg, dtb, alpha)
                        table.insert(animBrushes, animBrsh)
                        table.insert(animColors, animClr)
                    end

                    for i = 1, #sprite.frames, 1 do
                        local frame = sprite.frames[i]
                        local animCel = sprite:newCel(animLyr, frame)
                        local iFac = (i - 1.0) * frameToFac

                        for j = 1, dotCount, 1 do
                            local jFac = (j - 1.0) * dotToFac
                            local fac = iFac - jFac * offset
                            local place = Curve2.eval(curve, fac)
                            place = Vec2.round(place)
                            local plpt = Point(place.x, place.y)

                            app.useTool {
                                tool = "pencil",
                                color = animColors[j],
                                brush = animBrushes[j],
                                points = { plpt },
                                cel = animCel,
                                layer = animLyr }
                        end
                    end

                    app.activeFrame = sprite.frames[1]
                end)
            end

            app.refresh()
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
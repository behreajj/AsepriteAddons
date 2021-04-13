dofile("../support/aseutilities.lua")
dofile("../support/clr.lua")

local easingModes = { "HSL", "HSV", "RGB" }

local defaults = {
    elements = 12,
    frames = 24,
    frequency = 1,
    amplitude = 50,
    minScale = 8.0,
    maxScale = 16.0,
    aColor = Color(0, 127, 255, 255),
    bColor = Color(255, 0, 127, 255),
    easingMode = "HSL"
}

local dlg = Dialog { title = "Sine Wave" }

dlg:slider {
    id = "elements",
    label = "Elements:",
    min = 2,
    max = 32,
    value = defaults.elements
}

dlg:slider {
    id = "frames",
    label = "Frames:",
    min = 1,
    max = 60,
    value = defaults.frames
}

dlg:slider {
    id = "freq",
    label = "Frequency:",
    min = 1,
    max = 8,
    value = defaults.frequency
}

dlg:slider {
    id = "amp",
    label = "Amplitude:",
    min = 0,
    max = 100,
    value = defaults.amplitude
}

dlg:newrow { always = false }

dlg:number {
    id = "minScale",
    label = "Scale:",
    text = string.format("%.1f", defaults.minScale),
    decimals = 5
}

dlg:number {
    id = "maxScale",
    text = string.format("%.1f", defaults.maxScale),
    decimals = 5
}

dlg:newrow { always = false }

dlg:combobox {
    id = "easingMode",
    label = "Easing Mode:",
    option = defaults.easingMode,
    options = easingModes
}

dlg:newrow { always = false }

dlg:color {
    id = "aColor",
    label = "Colors:",
    color = defaults.aColor
}

dlg:color {
    id = "bColor",
    color = defaults.bColor
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "OK",
    focus = false,
    onclick = function()
        local args = dlg.data
        if args.ok then

            local aClrAse = args.aColor
            local bClrAse = args.bColor

            local sprite = AseUtilities.initCanvas(
                64, 64, "Sine Wave",
                { aClrAse, bClrAse })
            local layer = sprite.layers[#sprite.layers]

            local w = sprite.width
            local h = sprite.height

            -- Add requested number of frames.
            local reqFrames = args.frames
            local oldLen = #sprite.frames
            local needed = math.max(0, reqFrames - oldLen)
            -- app.transaction(function()
            for i = 1, needed, 1 do
                sprite:newEmptyFrame()
            end
            -- end)

            local yCenter = h * 0.5
            local ampx = h * 0.005 * args.amp
            local left = w * 0.15
            local right = w - left

            local elmCount = args.elements
            -- local iToFac = 1.0 / (reqFrames - 1.0)
            local jToFac = 1.0 / (elmCount - 1.0)

            local tau = math.pi * 2.0
            -- local halfPi = math.pi * 0.5
            local iToPeriod = tau / reqFrames
            local jToPeriod = tau / elmCount

            -- Store data.
            local points = {}
            local brushes = {}
            local cels = {}

            local absMinScale = 2.0
            local halfMaxScale = args.maxScale * 0.5

            for i = 0, reqFrames - 1, 1 do
                local frame = sprite.frames[1 + i]
                local cel = sprite:newCel(layer, frame)
                table.insert(cels, cel)

                -- local ifac = i * iToFac
                local theta = args.freq * i * iToPeriod
                local ptsInFrame = {}
                local brushesInFrame = {}
                local scalePulse = 0.5 + 0.5 * math.cos(theta + math.pi)
                local minScaleAtFrame = (1.0 - scalePulse) * absMinScale
                                             + scalePulse * args.minScale
                local maxScaleAtFrame = (1.0 - scalePulse) * halfMaxScale
                                             + scalePulse * args.maxScale

                for j = 0, elmCount - 1, 1 do
                    local jfac = j * jToFac
                    local phi = j * jToPeriod
                    local x = (1.0 - jfac) * left + jfac * right
                    local y = yCenter + ampx * math.cos(theta + phi)

                    local pt = Point(x, y)
                    table.insert(ptsInFrame, pt)

                    local scaleFac = 0.5 + 0.5 * math.cos(phi + math.pi)
                    local scale = (1.0 - scaleFac) * minScaleAtFrame
                                        + scaleFac * maxScaleAtFrame
                    local brush = Brush {
                        type = BrushType.CIRCLE,
                        size = scale
                    }
                    table.insert(brushesInFrame, brush)
                end
                table.insert(points, ptsInFrame)
                table.insert(brushes, brushesInFrame)
            end

            local aClr = AseUtilities.aseColorToClr(aClrAse)
            local bClr = AseUtilities.aseColorToClr(bClrAse)

            local easingFunc = Clr.mixRgba
            if args.easingMode == "HSV" then
                easingFunc = Clr.mixHsva
            elseif args.easingMode == "HSL" then
                easingFunc = Clr.mixHsla
            end

            local aseClrs = {}
            for j = 0, elmCount - 1, 1 do
                local jfac = j * jToFac
                local clr = easingFunc(aClr, bClr, jfac)
                local aseClr = AseUtilities.clrToAseColor(clr)
                table.insert(aseClrs, aseClr)
            end

            -- Draw.
            app.transaction(function()
                app.activeFrame = 1
                for i = 1, reqFrames, 1 do
                    local cel = cels[i]
                    local ptsInFrame = points[i]
                    local brushesInFrame = brushes[i]
                        for j = 1, elmCount, 1 do
                            app.useTool {
                                tool = "pencil",
                                color = aseClrs[j],
                                brush = brushesInFrame[j],
                                points = { ptsInFrame[j] },
                                cel = cel,
                                layer = layer
                            }
                        end
                end
            end)
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
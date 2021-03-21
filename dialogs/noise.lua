dofile("../support/clr.lua")
dofile("../support/simplex.lua")

local easingModes = { "RGB", "HSL", "HSV" }

local dlg = Dialog { title = "Noise" }

dlg:check {
    id = "useSeed",
    label = "Use Seed:",
    selected = false
}

dlg:number {
    id = "seed",
    label = "Seed:",
    text = string.format("%d", os.time()),
    decimals = 0
}

dlg:number {
    id = "scale",
    label = "Scale:",
    text = string.format("%.5f", 2.0),
    decimals = 5
}

dlg:number {
    id = "xOrigin",
    label = "Origin X:",
    text = string.format("%.1f", 0.0),
    decimals = 5
}

dlg:number {
    id = "yOrigin",
    label = "Origin Y:",
    text = string.format("%.1f", 0.0),
    decimals = 5
}

dlg:slider {
    id = "octaves",
    label = "Octaves:",
    min = 1,
    max = 32,
    value = 8
}

dlg:number {
    id = "lacunarity",
    label = "Lacunarity:",
    text = string.format("%.5f", 1.75),
    decimals = 5
}

dlg:number {
    id = "gain",
    label = "Gain:",
    text = string.format("%.5f", 0.5),
    decimals = 5
}

dlg:slider {
    id = "quantization",
    label = "Quantize:",
    min = 0,
    max = 32,
    value = 0
}

dlg:color {
    id = "aColor",
    label = "Color A:",
    color = Color(32, 32, 32, 255)
}

dlg:color {
    id = "bColor",
    label = "Color B:",
    color = Color(255, 245, 215, 255)
}

dlg:combobox {
    id = "easingMode",
    label = "Easing Mode:",
    option = "HSL",
    options = easingModes
}

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then

            local sprite = app.activeSprite
            local layer = nil
            if sprite == nil then
                sprite = Sprite(64, 64)
                app.activeSprite = sprite
                layer = sprite.layers[1]
            else
                layer = sprite:newLayer()
            end

            layer.name = "Noise"
            local cel = sprite:newCel(layer, 1)
            local img = cel.image

            local w = sprite.width
            local h = sprite.height

            -- TODO: Aspect correctio needed.
            local wInv = 1.0 / w
            local hInv = 1.0 / h

            local seed = 0
            if args.useSeed then
                seed = math.tointeger(args.seed)
            else
                seed = os.time()
            end

            local oct = args.octaves
            local lac = args.lacunarity
            local gain = args.gain
            local scl = 1.0
            if args.scale ~= 0.0 then
                scl = args.scale
            end
            local ox = args.xOrigin
            local oy = args.yOrigin

            local useQuantize = args.quantization > 0.0
            local delta = 1.0
            local levels = 1.0
            if useQuantize then
                levels = args.quantization
                delta = 1.0 / levels   
            end

            local aClrAse = args.aColor
            local aClr = Clr.new(
                0.00392156862745098 * aClrAse.red,
                0.00392156862745098 * aClrAse.green,
                0.00392156862745098 * aClrAse.blue,
                0.00392156862745098 * aClrAse.alpha)

            local bClrAse = args.bColor
            local bClr = Clr.new(
                0.00392156862745098 * bClrAse.red,
                0.00392156862745098 * bClrAse.green,
                0.00392156862745098 * bClrAse.blue,
                0.00392156862745098 * bClrAse.alpha)

            local easingFunc = Clr.mixRgba
            if args.easingMode == "HSV" then
                easingFunc = Clr.mixHsva
            elseif args.easingMode == "HSL" then
                easingFunc = Clr.mixHsla
            end

            local iterator = img:pixels()
            local i = 0

            for elm in iterator do
                local xPx = i % w
                local yPx = i // w

                local xNrm = xPx * wInv
                local yNrm = yPx * hInv

                local vx = ox + scl * xNrm
                local vy = oy + scl * yNrm

                local facSgned = Simplex.fbm2(
                    vx, vy, seed,
                    oct, lac, gain)
                if useQuantize then
                    facSgned = delta * math.floor(
                        0.5 + facSgned * levels)
                end
                local fac = math.max(0.0, math.min(1.0,
                    facSgned * 0.5 + 0.5))

                local clr = easingFunc(aClr, bClr, fac)
                local clrInt = Clr.toHex(clr)
                elm(clrInt)

                i = i + 1
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
dofile("../support/complex.lua")

local dlg = Dialog { title = "Julia Set" }

dlg:slider {
    id = "res",
    label = "Resolution:",
    min = 1,
    max = 64,
    value = 16
}

dlg:slider {
    id = "rSeed",
    label = "Seed R:",
    min = 1,
    max = 100,
    value = 80
}

dlg:slider {
    id = "phiSeed",
    label = "Seed Phi:",
    min = 0,
    max = 360,
    value = 90
}

dlg:slider {
    id = "power",
    label = "Power:",
    min = 1,
    max = 16,
    value = 2
}

dlg:color {
    id = "aColor",
    label = "Color A:",
    color = Color(0, 0, 0, 255)
}

dlg:color {
    id = "bColor",
    label = "Color B:",
    color = Color(255, 255, 255, 255)
}

dlg:check {
    id = "useSmooth",
    label = "Smooth Gradient:",
    selected = false
}

local function lerpRGB(
    ar, ag, ab, aa,
    br, bg, bb, ba, t)
    local u = 1.0 - t
    -- TODO: Refer to AseUtilities instead.
    return app.pixelColor.rgba(
        math.tointeger(u * ar + t * br),
        math.tointeger(u * ag + t * bg),
        math.tointeger(u * ab + t * bb),
        math.tointeger(u * aa + t * ba))
end

local function julia(seed, z, power, res)
    if z.real == 0.0 and z.imag == 0.0 then return 0.0 end

    local i = 0
    local zn = Complex.new(z.real, z.imag)
    while i < res and Complex.absSq(zn) <= 4.0 do
        zn = Complex.powNumber(zn, power)
        zn = Complex.add(seed, zn)
        i = i + 1
    end

    if i >= res then
        return 0.0
    else
        return math.max(0.0, math.min(1.0, i / res))
    end
end

local function juliaSmooth(seed, z, power, res)
    -- https://stackoverflow.com/questions/369438/
    -- smooth-spectrum-for-mandelbrot-set-rendering/
    -- 1243788#1243788

    if z.real == 0.0 and z.imag == 0.0 then return 0.0 end

    local i = 0
    local zn = Complex.new(z.real, z.imag)
    local ab = Complex.abs(zn)
    local fac = math.exp(-ab)
    while i < res and ab <= 2.0 do
        zn = Complex.powNumber(zn, power)
        zn = Complex.add(seed, zn)
        ab = Complex.abs(zn)
        fac = fac + math.exp(-ab)
        i = i + 1
    end

    if i >= res then
        return 0.0
    else
        return math.max(0.0, math.min(1.0, fac / (res - 1.0)))
    end
end

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = app.activeSprite
            if sprite == nil then
                sprite = Sprite(64, 64)
                app.activeSprite = sprite
            end

            local layer = sprite:newLayer()
            layer.name = "Julia Set"
            local cel = sprite:newCel(layer, 1)
            local image = cel.image

            -- TODO: Account for aspect ratio?
            local w = image.width
            local h = image.height

            local wInv = 1.0 / w
            local hInv = 1.0 / h

            local res = args.res
            local rpx = 0.01 * args.rSeed
            local phirad = math.rad(args.phiSeed)
            local seed = Complex.rect(rpx, phirad)
            -- local power = Complex.new(args.power, 0.0)
            local power = args.power

            local aColor = args.aColor
            local bColor = args.bColor

            local a0 = 0
            local a1 = 0
            local a2 = 0
            local a3 = 0

            local b0 = 0
            local b1 = 0
            local b2 = 0
            local b3 = 0

            a0 = aColor.red
            a1 = aColor.green
            a2 = aColor.blue
            a3 = aColor.alpha

            b0 = bColor.red
            b1 = bColor.green
            b2 = bColor.blue
            b3 = bColor.alpha

            local func = julia
            if args.useSmooth then
                func = juliaSmooth
            end

            local i = 0
            local iterator = image:pixels()
            for elm in iterator do
                local x = i % w
                local y = i // w

                local xNorm = x * wInv
                local yNorm = y * hInv

                local xSigned = xNorm + xNorm - 1.0
                local ySigned = 1.0 - (yNorm + yNorm)

                local st = Complex.new(xSigned, ySigned)
                local fac = func(seed, st, power, res)

                local clr = lerpRGB(
                    a0, a1, a2, a3,
                    b0, b1, b2, b3,
                    fac)
                elm(clr)

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
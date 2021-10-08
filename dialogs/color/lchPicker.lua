dofile("../../support/aseutilities.lua")

local harmonies = {
    "ANALOGOUS",
    "COMPLEMENT",
    "SPLIT",
    "SQUARE",
    "TRIADIC"
}

local defaults = {
    base = Color(255, 0, 0, 255),
    shading = {
        Color(165,   0,   0, 255),
        Color(192,   0,  16, 255),
        Color(217,   0,  29, 255),
        Color(241,  22,  37, 255),
        Color(255,  79,  42, 255),
        Color(255, 120,  42, 255),
        Color(255, 160,  43, 255) },
    hexCode = "FF0000",
    lightness = 53,
    chroma = 104,
    hue = 40,
    alpha = 100,
    showHarmonies = false,
    harmonyType = "TRIADIC",
    analogies = {
        Color(255, 0, 102, 255),
        Color(203, 99, 0, 255) },
    complement = { Color(0, 162, 243, 255) },
    splits = {
        Color(0, 161, 156, 255),
        Color(0, 154, 255, 255) },
    squares = {
        Color(0, 151, 0, 255),
        Color(0, 162, 243, 255),
        Color(157, 82, 255, 255) },
    triads = {
        Color(0, 131, 255, 255),
        Color(0, 158, 59, 255) },

    shadingCount = 7,
    shadowLight = 0.1,
    dayLight = 0.9,
    hYel = 0.3,
    minChroma = 4.0,
    lgtDesatFac = 0.75,
    shdDesatFac = 0.75,
    srcLightWeight = 0.3333333333333333,
    greenHue = 0.37778,
    minGreenOffset = 0.4,
    maxGreenOffset = 0.75
}

local function zigZag(t)
    local a = t * 0.5
    local b = a - math.floor(a)
    return 1.0 - math.abs(b + b - 1.0)
end

local function assignToFore(aseColor)
    if aseColor.alpha < 1 then
        app.fgColor = Color(0, 0, 0, 0)
    else
        app.fgColor = AseUtilities.aseColorCopy(aseColor)
    end
end

local function updateHarmonies(dialog, l, c, h, a)
    -- Hue wrapping is taken care of by lchTosRgba.
    -- Clamping is taken care of by clToAseColor.
    -- 360 / 3 = 120 degrees; 360 / 12 = 30 degrees.
    -- Split hues are 150 and 210 degrees.
    local oneThird = 0.3333333333333333
    local oneTwelve = 0.08333333333333333
    local splHue0 = 0.4166666666666667
    local splHue1 = 0.5833333333333334

    local ana0 = Clr.lchTosRgba(l, c, h - oneTwelve, a)
    local ana1 = Clr.lchTosRgba(l, c, h + oneTwelve, a)

    local tri0 = Clr.lchTosRgba(l, c, h - oneThird, a)
    local tri1 = Clr.lchTosRgba(l, c, h + oneThird, a)

    local split0 = Clr.lchTosRgba(l, c, h + splHue0, a)
    local split1 = Clr.lchTosRgba(l, c, h + splHue1, a)

    local square0 = Clr.lchTosRgba(l, c, h + 0.25, a)
    local square1 = Clr.lchTosRgba(l, c, h + 0.5, a)
    local square2 = Clr.lchTosRgba(l, c, h + 0.75, a)

    local tris = {
        AseUtilities.clrToAseColor(tri0),
        AseUtilities.clrToAseColor(tri1)
    }

    local analogues = {
        AseUtilities.clrToAseColor(ana0),
        AseUtilities.clrToAseColor(ana1)
    }

    local splits = {
        AseUtilities.clrToAseColor(split0),
        AseUtilities.clrToAseColor(split1)
    }

    local squares = {
        AseUtilities.clrToAseColor(square0),
        AseUtilities.clrToAseColor(square1),
        AseUtilities.clrToAseColor(square2)
    }

    local compl = { squares[2] }

    dialog:modify { id = "complement", colors = compl }
    dialog:modify { id = "triadic", colors = tris }
    dialog:modify { id = "analogous", colors = analogues }
    dialog:modify { id = "split", colors = splits }
    dialog:modify { id = "square", colors = squares }
end

local function updateShading(dialog, l, c, h, a)
    -- Cache methods used in for loop.
    local lerpNear = Utilities.lerpAngleNear
    local lchToRgb = Clr.lchTosRgba
    local clrToAse = AseUtilities.clrToAseColor
    local max = math.max

    -- Decide on clockwise or counter-clockwise based
    -- on color's warmth or coolness.
    -- The LCh hue for yellow is 103 degrees.
    local hYel = defaults.hYel
    local hBlu = hYel + 0.5
    local lerpFunc = nil
    if h < hYel or h >= hBlu then
        lerpFunc = Utilities.lerpAngleCcw
    else
        lerpFunc = Utilities.lerpAngleCw
    end

    -- Minimum and maximum light based on place in loop.
    local shadowLight = defaults.shadowLight
    local dayLight = defaults.dayLight
    local lSrc = l * 0.01

    -- Yellows are very saturated at high light;
    -- Desaturate them to get a better shade.
    -- Conversely, blues easily fall out of gamut
    -- so the shade factor is separate.
    local lgtDesatFac = defaults.lgtDesatFac
    local shdDesatFac = defaults.shdDesatFac
    local minChroma = defaults.minChroma
    local cVal = max(minChroma, c)
    local desatChromaLgt = cVal * lgtDesatFac
    local desatChromaShd = cVal * shdDesatFac

    -- Amount to mix between base light and loop light.
    local srcLightWeight = defaults.srcLightWeight
    local cmpLightWeight = 1.0 - srcLightWeight

    -- The warm-cool dichotomy works poorly for greens.
    -- For that reason, the closer a hue is to green,
    -- the more it uses absolute hue shifting.
    -- Green is approximately at hue 140.
    local offsetMix = Utilities.distAngleUnsigned(h, defaults.greenHue, 1.0)
    local offsetScale = (1.0 - offsetMix) * defaults.maxGreenOffset
                              + offsetMix * defaults.minGreenOffset
    -- print(string.format(
    --     "offsetMix: %.6f, offsetScale: %.6f",
    --     offsetMix, offsetScale))

    -- Absolute hues for shadow and light.
    -- This could also be combined with the origin hue +/-
    -- a shift which is then mixed with the absolute hue.
    local shadowHue = Clr.LCH_HUE_SHADOW
    local dayHue = Clr.LCH_HUE_LIGHT

    local shades = {}
    local shadingCount = defaults.shadingCount
    local toFac = 1.0 / (shadingCount - 1.0)
    for i = 1, shadingCount, 1 do
        local iFac = (i - 1) * toFac
        local lItr = (1.0 - iFac) * shadowLight
                           + iFac * dayLight

        -- Idealized hue from violet shadow to
        -- off-yellow daylight.
        local hAbs = lerpFunc(shadowHue, dayHue, lItr, 1.0)

        -- The middle sample should be closest to base color.
        -- The fac needs to be 0.0. That's why zigzag is
        -- used to convert to an oscillation.
        local lMixed = srcLightWeight * lSrc
                     + cmpLightWeight * lItr
        local lZig = zigZag(lMixed)
        local fac = offsetScale * lZig
        local hMixed = lerpNear(h, hAbs, fac, 1.0)

        -- Desaturate brights and darks.
        -- Min chroma gives even grays a slight chroma.
        local chromaTarget = desatChromaLgt
        if lMixed < 0.5 then chromaTarget = desatChromaShd end
        local cMixed = (1.0 - lZig) * cVal + lZig * chromaTarget
        cMixed = max(minChroma, cMixed)
        -- print(string.format(
        --     "lZig: %.6f, chroma: %.6f",
        --     lZig, chroma))

        local clr = lchToRgb(lMixed * 100.0, cMixed, hMixed, a)
        local aseColor = clrToAse(clr)
        shades[i] = aseColor
    end

    dialog:modify { id = "shading", colors = shades }
end

local function updateHexCode(dialog, clrArr)
    local len = #clrArr
    local strArr = {}
    for i = 1, len, 1 do
        strArr[i] = Clr.toHexWeb(clrArr[i])
    end

    dialog:modify {
        id = "hexCode",
        text = table.concat(strArr, ",")
    }
end

local function updateWarning(dialog, clr)
    -- Tolerance is based on blue being deemed
    -- out of gamut, as it has the highest possible
    -- chroma: L 32, C 134, H 306 .
    if Clr.rgbIsInGamut(clr, 0.115) then
        dialog:modify { id = "warning0", visible = false }
        dialog:modify { id = "warning1", visible = false }
    else
        dialog:modify { id = "warning0", visible = true }
        dialog:modify { id = "warning1", visible = true }
    end
end

local function setFromAse(dialog, aseClr)
    local clr = AseUtilities.aseColorToClr(aseClr)
    local lch = Clr.sRgbaToLch(clr)
    local trunc = math.tointeger
    local chroma = trunc(0.5 + lch.c)

    dialog:modify {
        id = "alpha",
        value = trunc(0.5 + lch.a * 100.0)
    }

    dialog:modify {
        id = "lightness",
        value = trunc(0.5 + lch.l)
    }

    dialog:modify {
        id = "chroma",
        value = chroma
    }

    -- Preserve hue unchanged for gray colors
    -- where hue would be invalid.
    if chroma > 0 then
        dialog:modify {
            id = "hue",
            value = trunc(0.5 + lch.h * 360.0)
        }
    end

    dialog:modify {
        id = "clr",
        colors = { AseUtilities.aseColorCopy(aseClr) }
    }

    updateWarning(dialog, clr)
    updateHexCode(dialog, { clr })
    updateHarmonies(dialog, lch.l, lch.c, lch.h, lch.a)
    updateShading(dialog, lch.l, lch.c, lch.h, lch.a)
end

local function updateClrs(dialog)
    local args = dialog.data
    local l = args.lightness
    local c = args.chroma
    local h = args.hue / 360.0
    local a = args.alpha * 0.01
    local clr = Clr.lchTosRgba(l, c, h, a)

    -- For thoughts on why clipping is preferred, see
    -- https://github.com/LeaVerou/css.land/issues/10
    dialog:modify {
        id = "clr",
        colors = { AseUtilities.clrToAseColor(clr) }
    }

    updateWarning(dialog, clr)
    updateHexCode(dialog, { clr })
    updateHarmonies(dialog, l, c, h, a)
    updateShading(dialog, l, c, h, a)
end

local dlg = Dialog { title = "LCh Color Picker" }

dlg:button {
    id = "fgGet",
    label = "Get:",
    text = "F&ORE",
    focus = false,
    onclick = function()
       setFromAse(dlg, app.fgColor)
    end
}

dlg:button {
    id = "bgGet",
    text = "B&ACK",
    focus = false,
    onclick = function()
       app.command.SwitchColors()
       setFromAse(dlg, app.fgColor)
       app.command.SwitchColors()
    end
}

dlg:newrow { always = false }

dlg: entry {
    id = "hexCode",
    label = "Hex: #",
    text = defaults.hexCode,
    focus = false
}

dlg:newrow { always = false }

dlg:shades {
    id = "clr",
    label = "Color:",
    mode = "sort",
    colors = { defaults.base },
    visible = true
}

dlg:newrow { always = false }

dlg:shades {
    id = "shading",
    label = "Shades:",
    mode = "pick",
    colors = defaults.shading,
    visible = true,
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            setFromAse(dlg, ev.color)
        elseif ev.button == MouseButton.RIGHT then
            assignToFore(ev.color)
        end
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "lightness",
    label = "Lightness:",
    min = 0,
    max = 100,
    value = defaults.lightness,
    onchange = function()
        updateClrs(dlg)
    end
}

dlg:slider {
    id = "chroma",
    label = "Chroma:",
    min = 0,
    max = 135,
    value = defaults.chroma,
    onchange = function()
        updateClrs(dlg)
    end
}

dlg:slider {
    id = "hue",
    label = "Hue:",
    min = 0,
    max = 360,
    value = defaults.hue,
    onchange = function()
        updateClrs(dlg)
    end
}

dlg:slider {
    id = "alpha",
    label = "Alpha:",
    min = 0,
    max = 100,
    value = defaults.alpha,
    onchange = function()
        updateClrs(dlg)
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "warning0",
    label = "Warning:",
    text = "Clipped to sRGB.",
    visible = false
}

dlg:newrow { always = false }

dlg:label {
    id = "warning1",
    text = "Hue may shift.",
    visible = false
}

dlg:newrow { always = false }

dlg:button {
    id = "fgSet",
    label = "Set:",
    text = "&FORE",
    focus = false,
    visible = true,
    onclick = function()
        local args = dlg.data
        if #args.clr > 0 then
            assignToFore(args.clr[1])
        end
    end
}

dlg:button {
    id = "bgSet",
    text = "&BACK",
    focus = false,
    visible = true,
    onclick = function()
        local args = dlg.data
        if #args.clr > 0 then
            -- Bug where assigning to app.bgColor
            -- leads to unlocked palette colors
            -- being assigned instead.
            app.command.SwitchColors()
            assignToFore(args.clr[1])
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "showHarmonies",
    label = "Harmonies:",
    text = "Show",
    selected = defaults.showHarmonies,
    onclick = function()
        local args = dlg.data
        local show = args.showHarmonies
        dlg:modify { id = "harmonyType", visible = show }

        if show then
            local md = args.harmonyType
            dlg:modify { id = "complement", visible = md == "COMPLEMENT" }
            dlg:modify { id = "triadic", visible = md == "TRIADIC" }
            dlg:modify { id = "analogous", visible = md == "ANALOGOUS" }
            dlg:modify { id = "split", visible = md == "SPLIT" }
            dlg:modify { id = "square", visible = md == "SQUARE" }
        else
            dlg:modify { id = "complement", visible = false }
            dlg:modify { id = "triadic", visible = false }
            dlg:modify { id = "analogous", visible = false }
            dlg:modify { id = "split", visible = false }
            dlg:modify { id = "square", visible = false }
        end
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "harmonyType",
    label = "Harmony:",
    option = defaults.harmonyType,
    options = harmonies,
    visible = defaults.showHarmonies,
    onchange = function()
        local md = dlg.data.harmonyType
        dlg:modify { id = "complement", visible = md == "COMPLEMENT" }
        dlg:modify { id = "triadic", visible = md == "TRIADIC" }
        dlg:modify { id = "analogous", visible = md == "ANALOGOUS" }
        dlg:modify { id = "split", visible = md == "SPLIT" }
        dlg:modify { id = "square", visible = md == "SQUARE" }
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "analogous",
    label = "Analogous:",
    mode = "pick",
    colors = defaults.analogies,
    visible = defaults.showHarmonies
        and defaults.harmonyType == "ANALOGOUS",
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            setFromAse(dlg, ev.color)
        elseif ev.button == MouseButton.RIGHT then
            assignToFore(ev.color)
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "complement",
    label = "Complement:",
    mode = "pick",
    colors = defaults.complement,
    visible = defaults.showHarmonies
        and defaults.harmonyType == "COMPLEMENT",
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            setFromAse(dlg, ev.color)
        elseif ev.button == MouseButton.RIGHT then
            assignToFore(ev.color)
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "split",
    label = "Split:",
    mode = "pick",
    colors = defaults.splits,
    visible = defaults.showHarmonies
        and defaults.harmonyType == "SPLIT",
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            setFromAse(dlg, ev.color)
        elseif ev.button == MouseButton.RIGHT then
            assignToFore(ev.color)
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "square",
    label = "Square:",
    mode = "pick",
    colors = defaults.squares,
    visible = defaults.showHarmonies
        and defaults.harmonyType == "SQUARE",
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            setFromAse(dlg, ev.color)
        elseif ev.button == MouseButton.RIGHT then
            assignToFore(ev.color)
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "triadic",
    label = "Triadic:",
    mode = "pick",
    colors = defaults.triads,
    visible = defaults.showHarmonies
        and defaults.harmonyType == "TRIADIC",
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            setFromAse(dlg, ev.color)
        elseif ev.button == MouseButton.RIGHT then
            assignToFore(ev.color)
        end
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }

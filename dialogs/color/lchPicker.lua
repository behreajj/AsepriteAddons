dofile("../../support/knot3.lua")
dofile("../../support/curve3.lua")
dofile("../../support/aseutilities.lua")

local harmonies = {
    "ANALOGOUS",
    "COMPLEMENT",
    "NONE",
    "SHADING",
    "SPLIT",
    "SQUARE",
    "TRIADIC"
}

local defaults = {
    base = Color(255, 0, 0, 255),
    hexCode = "FF0000",
    lightness = 53,
    chroma = 104,
    hue = 40,
    alpha = 255,
    harmonyType = "NONE",
    analogies = {
        Color(255, 0, 102, 255),
        Color(203, 99, 0, 255)
    },
    complement = { Color(0, 143, 224, 255) },
    splits = {
        Color(0, 161, 156, 255),
        Color(0, 154, 255, 255)
    },
    squares = {
        Color(0, 151, 0, 255),
        Color(0, 162, 243, 255),
        Color(157, 82, 255, 255)
    },
    triads = {
        Color(0, 131, 255, 255),
        Color(0, 158, 59, 255)
    },

    shading = {
        Color(145, 0, 51, 255),
        Color(193, 0, 42, 255),
        Color(226, 0, 33, 255),
        Color(253, 13, 26, 255),
        Color(255, 78, 28, 255),
        Color(255, 127, 45, 255),
        Color(255, 186, 76, 255)
    },
    shadeCount = 7
}

local function assignToFore(aseColor)
    if aseColor.alpha < 1 then
        app.fgColor = Color(0, 0, 0, 0)
    else
        app.fgColor = AseUtilities.aseColorCopy(aseColor, "")
    end
end

local function updateHarmonies(dialog, l, c, h, a)
    -- Hue wrapping is taken care of by lchTosRgba.
    -- Clamping is taken care of by clToAseColor.
    -- 360 / 3 = 120 degrees; 360 / 12 = 30 degrees.
    -- Split hues are 150 and 210 degrees.
    local oneThird = 0.33333333333333
    local oneTwelve = 0.08333333333333
    local splHue0 = 0.41666666666667
    local splHue1 = 0.58333333333333

    local ana0 = Clr.cieLchTosRgb(l, c, h - oneTwelve, a, 0.5)
    local ana1 = Clr.cieLchTosRgb(l, c, h + oneTwelve, a, 0.5)

    local cmp0 = Clr.cieLchTosRgb(100.0 - l, c, h + 0.5, a, 0.5)

    local tri0 = Clr.cieLchTosRgb(l, c, h - oneThird, a, 0.5)
    local tri1 = Clr.cieLchTosRgb(l, c, h + oneThird, a, 0.5)

    local split0 = Clr.cieLchTosRgb(l, c, h + splHue0, a, 0.5)
    local split1 = Clr.cieLchTosRgb(l, c, h + splHue1, a, 0.5)

    local square0 = Clr.cieLchTosRgb(l, c, h + 0.25, a, 0.5)
    local square1 = Clr.cieLchTosRgb(l, c, h + 0.5, a, 0.5)
    local square2 = Clr.cieLchTosRgb(l, c, h + 0.75, a, 0.5)

    local analogues = {
        AseUtilities.clrToAseColor(ana0),
        AseUtilities.clrToAseColor(ana1)
    }

    local compl = { AseUtilities.clrToAseColor(cmp0) }

    local splits = {
        AseUtilities.clrToAseColor(split0),
        AseUtilities.clrToAseColor(split1)
    }

    local squares = {
        AseUtilities.clrToAseColor(square0),
        AseUtilities.clrToAseColor(square1),
        AseUtilities.clrToAseColor(square2)
    }

    local tris = {
        AseUtilities.clrToAseColor(tri0),
        AseUtilities.clrToAseColor(tri1)
    }

    dialog:modify { id = "complement", colors = compl }
    dialog:modify { id = "triadic", colors = tris }
    dialog:modify { id = "analogous", colors = analogues }
    dialog:modify { id = "split", colors = splits }
    dialog:modify { id = "square", colors = squares }
end

local function updateShades(dialog, l, c, h, a)
    local args = dialog.data
    local shadeCount = args.shadeCount or defaults.shadeCount

    local hueSpreadShd = 0.66666666666667
    local hueSpreadLgt = 0.33333333333333
    local lightSpread = 37.5
    local chromaSpreadShd = 5.0
    local chromaSpreadLgt = 15.0

    local hYellow = 0.28570825759858
    local hViolet = hYellow + 0.5
    local minLight = math.max(0.0, l - lightSpread)
    local maxLight = math.min(100.0, l + lightSpread)
    local minChromaShd = math.max(0.0, c - chromaSpreadShd)
    local minChromaLgt = math.max(0.0, c - chromaSpreadLgt)

    local toShdFac = math.abs(50.0 - minLight) * 0.02
    local toLgtFac = math.abs(50.0 - maxLight) * 0.02

    local shdHue = Utilities.lerpAngleNear(h, hViolet, hueSpreadShd * toShdFac, 1.0)
    local lgtHue = Utilities.lerpAngleNear(h, hYellow, hueSpreadLgt * toLgtFac, 1.0)

    local shdCrm = (1.0 - toShdFac) * c + minChromaShd * toShdFac
    local lgtCrm = (1.0 - toLgtFac) * c + minChromaLgt * toLgtFac

    local labShd = Clr.cieLchToCieLab(minLight, shdCrm, shdHue, 1.0, 0.5)
    local labKey = Clr.cieLchToCieLab(l, c, h, 1.0, 0.5)
    local labLgt = Clr.cieLchToCieLab(maxLight, lgtCrm, lgtHue, 1.0, 0.5)

    local pt0 = Vec3.new(labShd.a, labShd.b, labShd.l)
    local pt1 = Vec3.new(labKey.a, labKey.b, labKey.l)
    local pt2 = Vec3.new(labLgt.a, labLgt.b, labLgt.l)

    local kn0 = Knot3.new(
        pt0, pt1, Vec3.new(0.0, 0.0, 0.0))
    local kn1 = Knot3.new(
        pt2, Vec3.new(0.0, 0.0, 0.0), pt1)
    kn0:mirrorHandlesForward()
    kn1:mirrorHandlesBackward()

    local curve = Curve3.new(
        false, { kn0, kn1 }, "Shading")

    local toFac = 1.0 / (shadeCount - 1.0)
    local aseColors = {}
    local i = 0
    while i < shadeCount do
        local v = Curve3.eval(curve, i * toFac)
        i = i + 1
        aseColors[i] = AseUtilities.clrToAseColor(
            Clr.cieLabTosRgb(v.z, v.x, v.y, a))
    end

    dialog:modify { id = "shading", colors = aseColors }
end

local function updateHexCode(dialog, clrArr)
    -- This handles multiple colors, just in case
    -- you want to make a fore and back color, or
    -- a cycling color history.
    local len = #clrArr
    local strArr = {}
    local i = 0
    while i < len do i = i + 1
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

local function setLch(dialog, lch, clr)
    local round = Utilities.round
    local chroma = round(lch.c)

    dialog:modify {
        id = "alpha",
        value = round(lch.a * 255.0)
    }

    dialog:modify {
        id = "lightness",
        value = round(lch.l)
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
            value = round(lch.h * 360.0)
        }
    end

    updateWarning(dialog, clr)
    updateHarmonies(dialog, lch.l, lch.c, lch.h, lch.a)
    updateShades(dialog, lch.l, lch.c, lch.h, lch.a)
end

local function setFromAse(dialog, aseClr)
    local clr = AseUtilities.aseColorToClr(aseClr)
    local lch = Clr.sRgbToCieLch(clr, 0.007072)
    setLch(dialog, lch, clr)
    dialog:modify {
        id = "clr",
        colors = { AseUtilities.aseColorCopy(aseClr, "") }
    }
    updateHexCode(dialog, { clr })
end

local function setFromSelect(dialog, sprite, frame)
    if not sprite then return end
    if not frame then return end

    local sel = AseUtilities.getSelection(sprite)
    local selBounds = sel.bounds

    local xSel = selBounds.x
    local ySel = selBounds.y

    local sprSpec = sprite.spec
    local colorMode = sprSpec.colorMode
    local selSpec = ImageSpec {
        width = math.max(1, selBounds.width),
        height = math.max(1, selBounds.height),
        colorMode = colorMode,
        transparentColor = sprSpec.transparentColor
    }
    selSpec.colorSpace = sprSpec.colorSpace
    local flatImage = Image(selSpec)

    -- This will ignore a reference image,
    -- meaning you can't sample it for color.
    flatImage:drawSprite(
        sprite, frame, Point(-xSel, -ySel))
    local px = flatImage:pixels()

    -- The key is the color in hex; the value is a
    -- number of pixels with that color in the
    -- selection. This tally is for the average.
    local hexDict = {}
    local eval = nil
    if colorMode == ColorMode.RGB then
        eval = function(h, d)
            if (h & 0xff000000) ~= 0 then
                local q = d[h]
                if q then d[h] = q + 1 else d[h] = 1 end
            end
        end
    elseif colorMode == ColorMode.GRAY then
        eval = function(gray, d)
            local a = (gray >> 0x08) & 0xff
            if a > 0 then
                local v = gray & 0xff
                local h = a << 0x18 | v << 0x10 | v << 0x08 | v
                local q = d[h]
                if q then d[h] = q + 1 else d[h] = 1 end
            end
        end
    elseif colorMode == ColorMode.INDEXED then
        eval = function(idx, d, pal)
            if idx > -1 and idx < #pal then
                local aseColor = pal:getColor(idx)
                local a = aseColor.alpha
                if a > 0 then
                    local h = aseColor.rgbaPixel
                    local q = d[h]
                    if q then d[h] = q + 1 else d[h] = 1 end
                end
            end
        end
    else
        -- Tile maps have a color mode of 4 in 1.3 beta.
        return
    end

    local palette = AseUtilities.getPalette(
        app.activeFrame, sprite.palettes)
    for elm in px do
        local x = elm.x + xSel
        local y = elm.y + ySel
        if sel:contains(x, y) then
            eval(elm(), hexDict, palette)
        end
    end

    local lSum = 0.0
    local aSum = 0.0
    local bSum = 0.0
    local alphaSum = 0.0
    local count = 0

    for k, v in pairs(hexDict) do
        local srgb = Clr.fromHex(k)
        local lab = Clr.sRgbToCieLab(srgb)
        lSum = lSum + lab.l * v
        aSum = aSum + lab.a * v
        bSum = bSum + lab.b * v
        alphaSum = alphaSum + lab.alpha * v
        count = count + v
    end

    if alphaSum > 0 and count > 0 then
        local countInv = 1.0 / count
        local alphaAvg = alphaSum * countInv
        local lAvg = lSum * countInv
        local aAvg = aSum * countInv
        local bAvg = bSum * countInv
        local lch = Clr.cieLabToCieLch(lAvg, aAvg, bAvg, alphaAvg)
        local clr = Clr.cieLabTosRgb(lAvg, aAvg, bAvg, alphaAvg)
        setLch(dialog, lch, clr)
        dialog:modify {
            id = "clr",
            colors = { AseUtilities.clrToAseColor(clr) }
        }
        updateHexCode(dialog, { clr })
    end
    app.refresh()
end

local function setFromHexStr(dialog)
    local args = dialog.data
    local hexStr = args.hexCode
    if #hexStr > 5 then
        local hexRgb = tonumber(hexStr, 16)
        if hexRgb then
            local r255 = hexRgb >> 0x10 & 0xff
            local g255 = hexRgb >> 0x08 & 0xff
            local b255 = hexRgb & 0xff
            local clr = Clr.new(
                r255 * 0.003921568627451,
                g255 * 0.003921568627451,
                b255 * 0.003921568627451, 1.0)
            local lch = Clr.sRgbToCieLch(clr, 0.007072)
            setLch(dialog, lch, clr)
            dialog:modify {
                id = "clr",
                colors = { Color(r255, g255, b255, 255) }
            }
        end
    end
end

local function updateClrs(dialog)
    local args = dialog.data
    local l = args.lightness
    local c = args.chroma
    local h = args.hue * 0.0027777777777778
    local a = args.alpha * 0.003921568627451
    local clr = Clr.cieLchTosRgb(l, c, h, a, 0.5)

    -- For thoughts on why clipping to gamut is preferred,
    -- see https://github.com/LeaVerou/css.land/issues/10
    dialog:modify {
        id = "clr",
        colors = { AseUtilities.clrToAseColor(clr) }
    }

    updateWarning(dialog, clr)
    updateHexCode(dialog, { clr })
    updateHarmonies(dialog, l, c, h, a)
    updateShades(dialog, l, c, h, a)
end

-- This constructor can accept a function for the
-- parameter "onclose." This function could be used
-- to disconnect event listeners, such as "fgcolorchange".
local dlg = Dialog { title = "LCh Color Picker" }

dlg:button {
    id = "fgGet",
    label = "Get:",
    text = "F&ORE",
    focus = false,
    onclick = function()
        if app.activeSprite then
            setFromAse(dlg, app.fgColor)
        end
    end
}

dlg:button {
    id = "bgGet",
    text = "B&ACK",
    focus = false,
    onclick = function()
        if app.activeSprite then
            app.command.SwitchColors()
            setFromAse(dlg, app.fgColor)
            app.command.SwitchColors()
        end
    end
}

dlg:button {
    id = "selGet",
    text = "&SELECT",
    focus = false,
    onclick = function()
        setFromSelect(dlg,
            app.activeSprite,
            app.activeFrame)
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "hexCode",
    label = "Hex: #",
    text = defaults.hexCode,
    focus = false,
    onchange = function()
        setFromHexStr(dlg)
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "clr",
    label = "Color:",
    mode = "sort",
    colors = { defaults.base }
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
    max = 255,
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
        if app.activeSprite and #args.clr > 0 then
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
        if app.activeSprite and #args.clr > 0 then
            -- Bug where assigning to app.bgColor leads
            -- to unlocked palette colors changing.
            app.command.SwitchColors()
            assignToFore(args.clr[1])
            app.command.SwitchColors()
        end
    end
}

dlg:button {
    id = "selSet",
    text = "S&ELECT",
    focus = false,
    onclick = function()
        --Early returns.
        local args = dlg.data
        local clrs = args.clr
        if #clrs < 1 then return end
        local clr = clrs[1]
        if clr.alpha < 1 then return end
        local sprite = app.activeSprite
        if not sprite then return end

        local sprSpec = sprite.spec
        local colorMode = sprSpec.colorMode
        local hex = AseUtilities.aseColorToHex(clr, colorMode)

        local sel = AseUtilities.getSelection(sprite)
        local selBounds = sel.bounds
        local xSel = selBounds.x
        local ySel = selBounds.y

        local selSpec = ImageSpec {
            width = math.max(1, selBounds.width),
            height = math.max(1, selBounds.height),
            colorMode = colorMode,
            transparentColor = sprSpec.transparentColor
        }
        selSpec.colorSpace = sprSpec.colorSpace
        local selImage = Image(selSpec)
        local px = selImage:pixels()

        for elm in px do
            local x = elm.x + xSel
            local y = elm.y + ySel
            if sel:contains(x, y) then elm(hex) end
        end

        app.transaction(function()
            -- This is an extra precaution because creating
            -- a new layer wipes out a range.
            local frameIdcs = AseUtilities.parseRange(app.range)
            local lenFrames = #frameIdcs
            local sprFrames = sprite.frames
            local layer = sprite:newLayer()
            layer.name = "Selection"
            local i = 0
            while i < lenFrames do i = i + 1
                local frameIdx = frameIdcs[i]
                local frameObj = sprFrames[frameIdx]
                sprite:newCel(
                    layer, frameObj,
                    selImage, Point(xSel, ySel))
            end
        end)
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "harmonyType",
    label = "Harmony:",
    option = defaults.harmonyType,
    options = harmonies,
    onchange = function()
        local md = dlg.data.harmonyType
        local isNone = md == "NONE"
        if isNone then
            dlg:modify { id = "complement", visible = false }
            dlg:modify { id = "triadic", visible = false }
            dlg:modify { id = "analogous", visible = false }
            dlg:modify { id = "split", visible = false }
            dlg:modify { id = "square", visible = false }

            dlg:modify { id = "shading", visible = false }
            -- dlg:modify { id = "shadeCount", visible = false }
        else
            dlg:modify { id = "complement", visible = md == "COMPLEMENT" }
            dlg:modify { id = "triadic", visible = md == "TRIADIC" }
            dlg:modify { id = "analogous", visible = md == "ANALOGOUS" }
            dlg:modify { id = "split", visible = md == "SPLIT" }
            dlg:modify { id = "square", visible = md == "SQUARE" }

            local isShading = md == "SHADING"
            dlg:modify { id = "shading", visible = isShading }
            -- dlg:modify { id = "shadeCount", visible = isShading }
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "shading",
    label = "Shading:",
    mode = "pick",
    colors = defaults.shading,
    visible = defaults.harmonyType == "SHADING",
    onclick = function(ev)
        local button = ev.button
        if button == MouseButton.LEFT then
            setFromAse(dlg, ev.color)
        elseif button == MouseButton.RIGHT then
            assignToFore(ev.color)
        end
    end
}

dlg:newrow { always = false }

-- dlg:slider {
--     id = "shadeCount",
--     label = "Count:",
--     min = 3,
--     max = 15,
--     value = defaults.shadeCount,
--     visible = defaults.harmonyType == "SHADING",
--     onchange = function()
--         local args = dlg.data
--         local l = args.lightness
--         local c = args.chroma
--         local h = args.hue * 0.0027777777777778
--         local a = args.alpha * 0.003921568627451
--         updateShades(dlg, l, c, h, a)
--     end
-- }

-- dlg:newrow { always = false }

dlg:shades {
    id = "analogous",
    label = "Analogous:",
    mode = "pick",
    colors = defaults.analogies,
    visible = defaults.harmonyType == "ANALOGOUS",
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
    visible = defaults.harmonyType == "COMPLEMENT",
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
    visible = defaults.harmonyType == "SPLIT",
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
    visible = defaults.harmonyType == "SQUARE",
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
    visible = defaults.harmonyType == "TRIADIC",
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
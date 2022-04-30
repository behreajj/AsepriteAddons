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
    -- TODO: Possibility for auto color set
    -- with event listeners?
    base = Color(255, 0, 0, 255),
    shading = {
        Color(147,   0,  27, 255),
        Color(183,   0,  29, 255),
        Color(218,   0,  30, 255),
        Color(251,  23,  34, 255),
        Color(255,  93,  42, 255),
        Color(255, 141,  58, 255),
        Color(255, 186,  81, 255) },
    hexCode = "FF0000",
    lightness = 53,
    chroma = 104,
    hue = 40,
    alpha = 255,
    harmonyType = "NONE",
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
        Color(0, 158, 59, 255) }
}

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
    local oneThird =  0.33333333333333
    local oneTwelve = 0.08333333333333
    local splHue0 =   0.41666666666667
    local splHue1 =   0.58333333333333

    local ana0 = Clr.lchTosRgba(l, c, h - oneTwelve, a, 0.5)
    local ana1 = Clr.lchTosRgba(l, c, h + oneTwelve, a, 0.5)

    local tri0 = Clr.lchTosRgba(l, c, h - oneThird, a, 0.5)
    local tri1 = Clr.lchTosRgba(l, c, h + oneThird, a, 0.5)

    local split0 = Clr.lchTosRgba(l, c, h + splHue0, a, 0.5)
    local split1 = Clr.lchTosRgba(l, c, h + splHue1, a, 0.5)

    local square0 = Clr.lchTosRgba(l, c, h + 0.25, a, 0.5)
    local square1 = Clr.lchTosRgba(l, c, h + 0.5, a, 0.5)
    local square2 = Clr.lchTosRgba(l, c, h + 0.75, a, 0.5)

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
    local shadingCount = 7
    local hueSpreadShd = 0.4
    local hueSpreadLgt = 0.325
    local lightSpread = 37.5
    local chromaSpread = 17.5
    local hYellow = 0.28570825759858
    local hViolet = (hYellow + 0.5) % 1.0
    local minLight = math.max(2.0, l - lightSpread)
    local maxLight = math.min(98.0, l + lightSpread)
    local minChromaShd = math.max(0.0, c - chromaSpread * 0.25)
    local minChromaLgt = math.max(0.0, c - chromaSpread)

    local toShdFac = math.abs(50.0 - minLight) * 0.02
    local toLgtFac = math.abs(50.0 - maxLight) * 0.02

    local shdHue = Utilities.lerpAngleNear(h, hViolet, hueSpreadShd * toShdFac, 1.0)
    local shdCrm = (1.0 - toShdFac) * c + minChromaShd * toShdFac
    local lgtHue = Utilities.lerpAngleNear(h, hYellow, hueSpreadLgt * toLgtFac, 1.0)
    local lgtCrm = (1.0 - toLgtFac) * c + minChromaLgt * toLgtFac

    local labShd = Clr.lchToLab(minLight, shdCrm, shdHue, 1.0, 0.5)
    local labKey = Clr.lchToLab(l, c, h, 1.0, 0.5)
    local labLgt = Clr.lchToLab(maxLight, lgtCrm, lgtHue, 1.0, 0.5)

    local pt0 = Vec3.new(labShd.a, labShd.b, labShd.l)
    local pt1 = Vec3.new(labKey.a, labKey.b, labKey.l)
    local pt2 = Vec3.new(labLgt.a, labLgt.b, labLgt.l)

    local kn0 = Knot3.new(
        pt0,
        Vec3.new(0.0, 0.0, 0.0),
        Vec3.new(0.0, 0.0, 0.0))
    local kn1 = Knot3.new(
        pt2,
        Vec3.new(0.0, 0.0, 0.0),
        Vec3.new(0.0, 0.0, 0.0))
    Knot3.fromSegQuadratic(pt1, pt2, kn0, kn1)
    kn0:mirrorHandlesForward()
    kn1:mirrorHandlesBackward()

    local curve = Curve3.new(
        false, { kn0, kn1 }, "Shading")

    local toFac = 1.0 / (shadingCount - 1.0)
    local aseColors = {}
    for i = 1, shadingCount, 1 do
        local v = Curve3.eval(curve, (i - 1.0) * toFac)
        aseColors[i] = AseUtilities.clrToAseColor(
            Clr.labTosRgba(v.z, v.x, v.y, a))
    end

    dialog:modify { id = "shading", colors = aseColors }
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

local function setLch(dialog, lch, clr)
    local trunc = math.tointeger
    local chroma = trunc(0.5 + lch.c)

    dialog:modify {
        id = "alpha",
        value = trunc(0.5 + lch.a * 255.0)
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

    updateWarning(dialog, clr)
    updateHarmonies(dialog, lch.l, lch.c, lch.h, lch.a)
    updateShading(dialog, lch.l, lch.c, lch.h, lch.a)
end

local function setFromAse(dialog, aseClr)
    local clr = AseUtilities.aseColorToClr(aseClr)
    local lch = Clr.sRgbaToLch(clr)
    setLch(dialog, lch, clr)
    dialog:modify {
        id = "clr",
        colors = { AseUtilities.aseColorCopy(aseClr) }
    }
    updateHexCode(dialog, { clr })
end

local function setFromSelect(dialog, sprite, frame)
    if sprite and frame then
        local selection = sprite.selection
        if selection and (not selection.isEmpty) then
            -- Problem with selections that extend
            -- into negative values?
            -- selection:intersect(Selection(sprite.bounds))
            local selBounds = selection.bounds
            local xSel = selBounds.x
            local ySel = selBounds.y

            local colorMode = sprite.colorMode

            -- This will ignore a reference image,
            -- meaning you can't sample it for color.
            local flatImage = Image(
                selBounds.width,
                selBounds.height,
                colorMode)
            flatImage:drawSprite(
                sprite, frame, Point(-xSel, -ySel))
            local px = flatImage:pixels()

            local hexDict = {}

            -- In Aseprite 1.3, it's possible for images in
            -- tile map layers to have a colorMode of 4.
            if colorMode == ColorMode.RGB then
                for elm in px do
                    local x = elm.x + xSel
                    local y = elm.y + ySel
                    if selection:contains(x, y) then
                        local hex = elm()
                        local a = hex >> 0x18 & 0xff
                        if a > 0 then
                            local query = hexDict[hex]
                            if query then
                                hexDict[hex] = query + 1
                            else
                                hexDict[hex] = 1
                            end
                        end
                    end
                end
            elseif colorMode == ColorMode.GRAY then
                for elm in px do
                    local x = elm.x + xSel
                    local y = elm.y + ySel
                    if selection:contains(x, y) then
                        local hex = elm()
                        local a = (hex >> 0x08) & 0xff
                        if a > 0 then
                            local v = hex & 0xff
                            local hexRgb = a << 0x18 | v << 0x10 | v << 0x08 | v
                            local query = hexDict[hexRgb]
                            if query then
                                hexDict[hexRgb] = query + 1
                            else
                                hexDict[hexRgb] = 1
                            end
                        end
                    end
                end
            elseif colorMode == ColorMode.INDEXED then
                local palette = sprite.palettes[1]
                local palLen = #palette
                for elm in px do
                    local x = elm.x + xSel
                    local y = elm.y + ySel
                    if selection:contains(x, y) then
                        local idx = elm()
                        if idx > -1 and idx < palLen then
                            local aseColor = palette:getColor(idx)
                            local a = aseColor.alpha
                            if a > 0 then
                                local hexRgb = aseColor.rgbaPixel
                                local query = hexDict[hexRgb]
                                if query then
                                    hexDict[hexRgb] = query + 1
                                else
                                    hexDict[hexRgb] = 1
                                end
                            end
                        end
                    end
                end
            end

            local lSum = 0.0
            local aSum = 0.0
            local bSum = 0.0
            local alphaSum = 0.0
            local count = 0

            for k, v in pairs(hexDict) do
                local srgb = Clr.fromHex(k)
                local lab = Clr.sRgbaToLab(srgb)
                lSum = lSum + lab.l * v
                aSum = aSum + lab.a * v
                bSum = bSum + lab.b * v
                alphaSum = alphaSum + lab.alpha * v
                count = count + v
            end

            if count > 0 then
                local countInv = 1.0 / count
                local lAvg = lSum * countInv
                local aAvg = aSum * countInv
                local bAvg = bSum * countInv
                local alphaAvg = alphaSum * countInv
                local lch = Clr.labToLch(lAvg, aAvg, bAvg, alphaAvg)
                local clr = Clr.labTosRgba(lAvg, aAvg, bAvg, alphaAvg)
                setLch(dialog, lch, clr)
                dialog:modify {
                    id = "clr",
                    colors = { AseUtilities.clrToAseColor(clr) }
                }
                updateHexCode(dialog, { clr })
            end
        end
    end
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
            local lch = Clr.sRgbaToLch(clr)
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
    local h = args.hue * 0.002777777777777778
    local a = args.alpha * 0.003921568627451
    local clr = Clr.lchTosRgba(l, c, h, a)

    -- For thoughts on why clipping to gamut is preferred,
    -- see https://github.com/LeaVerou/css.land/issues/10
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

dlg:button {
    id = "selGet",
    text = "&SELECTION",
    focus = false,
    onclick = function()
        setFromSelect(dlg,
            app.activeSprite,
            app.activeFrame)
    end
}

dlg:newrow { always = false }

dlg: entry {
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
            dlg:modify { id = "shading", visible = false }
            dlg:modify { id = "split", visible = false }
            dlg:modify { id = "square", visible = false }
        else
            dlg:modify { id = "complement", visible = md == "COMPLEMENT" }
            dlg:modify { id = "triadic", visible = md == "TRIADIC" }
            dlg:modify { id = "analogous", visible = md == "ANALOGOUS" }
            dlg:modify { id = "shading", visible = md == "SHADING" }
            dlg:modify { id = "split", visible = md == "SPLIT" }
            dlg:modify { id = "square", visible = md == "SQUARE" }
        end
    end
}

dlg:newrow { always = false }

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

dofile("../../support/aseutilities.lua")

local uiModes <const> = { "COLOR", "CRITERIA" }
local selModes <const> = { "REPLACE", "ADD", "SUBTRACT", "INTERSECT" }
local sampleModes <const> = { "ACTIVE", "COMPOSITE" }

local defaults <const> = {
    uiMode = "COLOR",
    sampleMode = "ACTIVE",
    tolerance = 0,
    useLight = true,
    minLight = 33,
    maxLight = 67,
    usec = false,
    minc = 10,
    maxc = 120,
    useh = false,
    minh = 0,
    maxh = 360,
    useAlpha = false,
    minAlpha = 1,
    maxAlpha = 255,
    pullFocus = true
}

---@param lab { l: number, a: number, b: number, alpha: number }
---@param mint01 number
---@param maxt01 number
---@param useLight boolean
---@param minLight number
---@param maxLight number
---@param usea boolean
---@param mina number
---@param maxa number
---@param useb boolean
---@param minb number
---@param maxb number
---@param usePolar boolean
---@param usec boolean
---@param mincsq number
---@param maxcsq number
---@param useh boolean
---@param minhrd number
---@param maxhrd number
---@return boolean
local function eval(
    lab, mint01, maxt01,
    useLight, minLight, maxLight,
    usea, mina, maxa,
    useb, minb, maxb,
    usePolar,
    usec, mincsq, maxcsq,
    useh, minhrd, maxhrd)
    local l <const> = lab.l
    local a <const> = lab.a
    local b <const> = lab.b
    local t <const> = lab.alpha

    local include = t >= mint01 and t <= maxt01
    if useLight and (l < minLight or l > maxLight) then
        include = false
    end
    if usea and (a < mina or a > maxa) then
        include = false
    end
    if useb and (b < minb or b > maxb) then
        include = false
    end

    if usePolar then
        local csq <const> = a * a + b * b
        if useh then
            if csq > 0.00005 then
                local h <const> = math.atan(b, a) % 6.2831853071796
                if h < minhrd or h > maxhrd then
                    include = false
                end
            else
                include = false
            end
        end
        if usec and (csq < mincsq or csq > maxcsq) then
            include = false
        end
    end

    return include
end

local dlg <const> = Dialog { title = "Select Color" }

dlg:combobox {
    id = "selMode",
    label = "Select:",
    -- option = selModes[1 + app.preferences.selection.mode],
    option = "REPLACE",
    options = selModes
}

dlg:newrow { always = false }

dlg:combobox {
    id = "sampleMode",
    label = "Refer To:",
    option = defaults.sampleMode,
    options = sampleModes
}

dlg:newrow { always = false }

dlg:combobox {
    id = "uiMode",
    label = "Mode:",
    option = defaults.uiMode,
    options = uiModes,
    onchange = function()
        local args <const> = dlg.data
        local uiMode <const> = args.uiMode --[[@as string]]
        local useLight <const> = args.useLight --[[@as boolean]]
        local usec <const> = args.usec --[[@as boolean]]
        local useh <const> = args.useh --[[@as boolean]]
        local useAlpha <const> = args.useAlpha --[[@as boolean]]

        local isCriteria <const> = uiMode == "CRITERIA"
        local isColor <const> = uiMode == "COLOR"

        dlg:modify { id = "useLight", visible = isCriteria }
        dlg:modify { id = "minLight", visible = isCriteria and useLight }
        dlg:modify { id = "maxLight", visible = isCriteria and useLight }

        dlg:modify { id = "usec", visible = isCriteria }
        dlg:modify { id = "minc", visible = isCriteria and usec }
        dlg:modify { id = "maxc", visible = isCriteria and usec }

        dlg:modify { id = "useh", visible = isCriteria }
        dlg:modify { id = "minh", visible = isCriteria and useh }
        dlg:modify { id = "maxh", visible = isCriteria and useh }

        dlg:modify { id = "useAlpha", visible = isCriteria }
        dlg:modify { id = "minAlpha", visible = isCriteria and useAlpha }
        dlg:modify { id = "maxAlpha", visible = isCriteria and useAlpha }

        dlg:modify { id = "refColor", visible = isColor }
        dlg:modify { id = "refColor", color = app.preferences.color_bar.fg_color }
        dlg:modify { id = "tolerance", visible = isColor }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "refColor",
    label = "Color:",
    -- color = app.preferences.color_bar.fg_color,
    color = Color { r = 0, g = 0, b = 0, a = 0 },
    visible = defaults.uiMode == "COLOR"
}

dlg:newrow { always = false }

dlg:slider {
    id = "tolerance",
    label = "Tolerance:",
    min = 0,
    max = 255,
    value = defaults.tolerance,
    visible = defaults.uiMode == "COLOR"
}

dlg:newrow { always = false }

dlg:check {
    id = "useLight",
    label = "Criteria:",
    text = "L",
    selected = defaults.useLight,
    visible = defaults.uiMode == "CRITERIA",
    onclick = function()
        local args <const> = dlg.data
        local state <const> = args.useLight --[[@as boolean]]
        dlg:modify { id = "minLight", visible = state }
        dlg:modify { id = "maxLight", visible = state }
    end
}

dlg:check {
    id = "usec",
    text = "C",
    selected = defaults.usec,
    visible = defaults.uiMode == "CRITERIA",
    onclick = function()
        local args <const> = dlg.data
        local state <const> = args.usec --[[@as boolean]]
        dlg:modify { id = "minc", visible = state }
        dlg:modify { id = "maxc", visible = state }
    end
}

dlg:check {
    id = "useh",
    text = "H",
    selected = defaults.useh,
    visible = defaults.uiMode == "CRITERIA",
    onclick = function()
        local args <const> = dlg.data
        local state <const> = args.useh --[[@as boolean]]
        dlg:modify { id = "minh", visible = state }
        dlg:modify { id = "maxh", visible = state }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "useAlpha",
    text = "Alpha",
    selected = defaults.useAlpha,
    visible = defaults.uiMode == "CRITERIA",
    onclick = function()
        local args <const> = dlg.data
        local state <const> = args.useAlpha --[[@as boolean]]
        dlg:modify { id = "minAlpha", visible = state }
        dlg:modify { id = "maxAlpha", visible = state }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "minLight",
    label = "Light:",
    min = 0,
    max = 100,
    value = defaults.minLight,
    visible = defaults.uiMode == "CRITERIA"
        and defaults.useLight
}

dlg:slider {
    id = "maxLight",
    min = 0,
    max = 100,
    value = defaults.maxLight,
    visible = defaults.uiMode == "CRITERIA"
        and defaults.useLight
}

dlg:newrow { always = false }

dlg:slider {
    id = "minc",
    label = "Chroma:",
    min = 0,
    max = 120,
    value = defaults.minc,
    visible = defaults.uiMode == "CRITERIA"
        and defaults.usec
}

dlg:slider {
    id = "maxc",
    min = 0,
    max = 120,
    value = defaults.maxc,
    visible = defaults.uiMode == "CRITERIA"
        and defaults.usec
}

dlg:newrow { always = false }

dlg:slider {
    id = "minh",
    label = "Hue:",
    min = 0,
    max = 360,
    value = defaults.minh,
    visible = defaults.uiMode == "CRITERIA"
        and defaults.useh
}

dlg:slider {
    id = "maxh",
    min = 0,
    max = 360,
    value = defaults.maxh,
    visible = defaults.uiMode == "CRITERIA"
        and defaults.useh
}

dlg:newrow { always = false }

dlg:slider {
    id = "minAlpha",
    label = "Alpha:",
    min = 0,
    max = 255,
    value = defaults.minAlpha,
    visible = defaults.uiMode == "CRITERIA"
        and defaults.useAlpha
}

dlg:slider {
    id = "maxAlpha",
    min = 0,
    max = 255,
    value = defaults.maxAlpha,
    visible = defaults.uiMode == "CRITERIA"
        and defaults.useAlpha
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local activeLayer <const> = site.layer
        if not activeLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
            }
            return
        end

        if activeLayer.isReference then
            app.alert {
                title = "Error",
                text = "Reference layers are not supported."
            }
            return
        end

        local activeFrame <const> = site.frame
        if not activeFrame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
            }
            return
        end

        local args <const> = dlg.data
        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]
        local sampleMode <const> = args.sampleMode
            or defaults.sampleMode --[[@as string]]
        local uiMode <const> = args.uiMode
            or defaults.uiMode --[[@as string]]
        local refColor <const> = args.refColor --[[@as Color]]

        local useLight = false
        local usea = false
        local useb = false
        local usec = false
        local useh = false
        local useAlpha = false

        local minLight = 0.0
        local mina = -111.0
        local minb = -111.0
        local minc = 0.0
        local minh = 0.0
        local minAlpha = 1.0

        local maxLight = 100.0
        local maxa = 111.0
        local maxb = 111.0
        local maxc = 135.0
        local maxh = 360.0
        local maxAlpha = 255.0

        -- Cache global methods.
        local fromHex <const> = Clr.fromHex
        local sRgbaToLab <const> = Clr.sRgbToSrLab2
        local aseColorToClr <const> = AseUtilities.aseColorToClr
        local aseColorToHex <const> = AseUtilities.aseColorToHex

        local colorMode <const> = activeSprite.colorMode
        local exactSearch = false

        local refClr <const> = aseColorToClr(refColor)
        local refLab <const> = sRgbaToLab(refClr)
        local refInt <const> = aseColorToHex(refColor, colorMode)

        if uiMode == "COLOR" then
            local tolerance <const> = args.tolerance
                or defaults.tolerance --[[@as integer]]
            exactSearch = tolerance == 0

            if not exactSearch then
                useLight = true
                usea = true
                useb = true
                useAlpha = true

                local tol100 <const> = math.max(0.000001,
                    tolerance * 0.5)
                minLight = refLab.l - tol100
                maxLight = refLab.l + tol100

                local tol111 <const> = math.max(0.000001,
                    tolerance * (50.0 / 111.0))
                mina = refLab.a - tol111
                maxa = refLab.a + tol111

                minb = refLab.b - tol111
                maxb = refLab.b + tol111

                local tol255 <const> = math.max(0.000001,
                    tolerance * (50.0 / 255.0))
                minAlpha = refColor.alpha - tol255
                maxAlpha = refColor.alpha + tol255
            end
        else
            useLight = args.useLight --[[@as boolean]]
            usec = args.usec --[[@as boolean]]
            useh = args.useh --[[@as boolean]]
            useAlpha = args.useAlpha --[[@as boolean]]

            minLight = args.minLight --[[@as number]]
            minc = args.minc --[[@as number]]
            minh = args.minh --[[@as number]]

            maxLight = args.maxLight --[[@as number]]
            maxc = args.maxc --[[@as number]]
            maxh = args.maxh --[[@as number]]

            minAlpha = 1.0
            maxAlpha = 255.0
            if useAlpha then
                minAlpha = args.minAlpha --[[@as number]]
                maxAlpha = args.maxAlpha --[[@as number]]
            end

            -- Disable criteria if minimum is equal to maximum.
            if minLight == maxLight then useLight = false end
            if minc == maxc then usec = false end
            if minh == maxh then useh = false end
            if minAlpha == maxAlpha then useAlpha = false end

            -- Swap minimum and maximum if invalid.
            if minLight > maxLight then
                minLight, maxLight = maxLight, minLight
            end
            if minc > maxc then
                minc, maxc = maxc, minc
            end
            if minh > maxh then
                minh, maxh = maxh, minh
            end
            if minAlpha > maxAlpha then
                minAlpha, maxAlpha = maxAlpha, minAlpha
            end

            if not (useLight or usec or useh or useAlpha) then
                app.alert {
                    title = "Error",
                    text = {
                        "There are no active criteria",
                        "with valid minimum and maximum."
                    }
                }
                return
            end
        end

        local image = nil
        local xtl = 0
        local ytl = 0
        if sampleMode == "COMPOSITE" then
            image = Image(activeSprite.spec)
            image:drawSprite(activeSprite, activeFrame)
        elseif activeLayer.isGroup then
            local spriteSpec <const> = activeSprite.spec
            local flat <const>, rect <const> = AseUtilities.flattenGroup(
                activeLayer, activeFrame, colorMode,
                spriteSpec.colorSpace, spriteSpec.transparentColor,
                true, true, true, true)

            image = flat
            xtl = rect.x
            ytl = rect.y
        else
            local activeCel <const> = activeLayer:cel(activeFrame)
            if not activeCel then
                app.alert {
                    title = "Error",
                    text = "There is no active cel."
                }
                return
            end

            image = activeCel.image
            if activeLayer.isTilemap then
                image = AseUtilities.tilesToImage(
                    image, activeLayer.tileset, colorMode)
            end
            local celPos <const> = activeCel.position
            xtl = celPos.x
            ytl = celPos.y
        end

        local pxItr <const> = image:pixels()
        local trgSel <const> = Selection()
        local pxRect <const> = Rectangle(0, 0, 1, 1)

        if exactSearch then
            for pixel in pxItr do
                if pixel() == refInt then
                    pxRect.x = xtl + pixel.x
                    pxRect.y = ytl + pixel.y
                    trgSel:add(pxRect)
                end
            end
        else
            -- Alpha is listed in [0, 255] but compared in [0.0, 1.0].
            -- Chroma is compared in magnitude squared.
            -- Hue is listed in [0, 360] but compared in [0, tau].
            local usePolar <const> = usec or useh
            local mint01 <const> = minAlpha * 0.003921568627451
            local maxt01 <const> = maxAlpha * 0.003921568627451
            local mincsq <const> = minc * minc
            local maxcsq <const> = maxc * maxc
            local minhrd <const> = minh * 0.017453292519943
            local maxhrd <const> = maxh * 0.017453292519943

            -- When a color mode convert to to RGB is attempted,
            -- there's either a crash or nothing is selected.
            if colorMode == ColorMode.INDEXED then
                local palette <const> = AseUtilities.getPalette(
                    activeFrame, activeSprite.palettes)
                local lenPalette <const> = #palette
                ---@type boolean[]
                local includes <const> = {}
                local j = 0
                while j < lenPalette do
                    local aseColor <const> = palette:getColor(j)
                    local clr <const> = aseColorToClr(aseColor)
                    local lab <const> = sRgbaToLab(clr)

                    j = j + 1
                    includes[j] = eval(
                        lab, mint01, maxt01,
                        useLight, minLight, maxLight,
                        usea, mina, maxa,
                        useb, minb, maxb,
                        usePolar,
                        usec, mincsq, maxcsq,
                        useh, minhrd, maxhrd)
                end

                for pixel in pxItr do
                    local idx <const> = pixel()
                    if includes[1 + idx] then
                        pxRect.x = xtl + pixel.x
                        pxRect.y = ytl + pixel.y
                        trgSel:add(pxRect)
                    end
                end
            else
                local parseHex = nil
                if colorMode == ColorMode.GRAY then
                    parseHex = function(x)
                        local a = (x >> 0x08) & 0xff
                        local v = x & 0xff
                        return a << 0x18 | v << 0x10 | v << 0x08 | v
                    end
                else
                    -- Default to RGB
                    parseHex = function(x) return x end
                end

                ---@type table<integer, boolean>
                local visited <const> = {}
                ---@type table<integer, boolean>
                local filtered <const> = {}
                for pixel in pxItr do
                    local hex <const> = parseHex(pixel())
                    local include = false
                    if visited[hex] then
                        include = filtered[hex]
                    else
                        local lab <const> = sRgbaToLab(fromHex(hex))
                        include = eval(
                            lab, mint01, maxt01,
                            useLight, minLight, maxLight,
                            usea, mina, maxa,
                            useb, minb, maxb,
                            usePolar,
                            usec, mincsq, maxcsq,
                            useh, minhrd, maxhrd)
                        visited[hex] = true
                        filtered[hex] = include
                    end

                    if include then
                        pxRect.x = xtl + pixel.x
                        pxRect.y = ytl + pixel.y
                        trgSel:add(pxRect)
                    end
                end
            end
        end

        if selMode ~= "REPLACE" then
            local activeSel <const>, selIsValid <const> = AseUtilities.getSelection(activeSprite)
            if selMode == "INTERSECT" then
                activeSel:intersect(trgSel)
                activeSprite.selection = activeSel
            elseif selMode == "SUBTRACT" then
                activeSel:subtract(trgSel)
                activeSprite.selection = activeSel
            else
                -- Additive selection.
                -- See https://github.com/aseprite/aseprite/issues/4045 .
                if selIsValid then
                    activeSel:add(trgSel)
                    activeSprite.selection = activeSel
                else
                    activeSprite.selection = trgSel
                end
            end
        else
            activeSprite.selection = trgSel
        end

        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
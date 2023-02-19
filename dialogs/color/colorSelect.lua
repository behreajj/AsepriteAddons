dofile("../../support/aseutilities.lua")

local uiModes = { "COLOR", "CRITERIA" }
local selModes = { "REPLACE", "ADD", "SUBTRACT", "INTERSECT" }

local defaults = {
    target = "ACTIVE",
    uiMode = "COLOR",
    selMode = "REPLACE",
    tolerance = 0,
    useLight = true,
    minLight = 33,
    maxLight = 67,
    usec = false,
    minc = 10,
    maxc = 135,
    useh = false,
    minh = 0,
    maxh = 360,
    useAlpha = false,
    minAlpha = 1,
    maxAlpha = 255,
    pullFocus = false
}

local dlg = Dialog { title = "Select Color" }

dlg:combobox {
    id = "selMode",
    label = "Select:",
    option = defaults.selMode,
    options = selModes
}

dlg:newrow { always = false }

dlg:combobox {
    id = "uiMode",
    label = "Mode:",
    option = defaults.uiMode,
    options = uiModes,
    onchange = function()
        local args = dlg.data
        local uiMode = args.uiMode

        local isCriteria = uiMode == "CRITERIA"
        local useLight = args.useLight
        local usec = args.usec
        local useh = args.useh
        local useAlpha = args.useAlpha

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

        local isColor = uiMode == "COLOR"
        dlg:modify { id = "refColor", visible = isColor }
        dlg:modify { id = "refColor", color = app.preferences.color_bar.fg_color }
        dlg:modify { id = "tolerance", visible = isColor }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "refColor",
    label = "Color:",
    color = app.preferences.color_bar.fg_color,
    visible = defaults.uiMode == "COLOR"
}

dlg:newrow { always = false }

dlg:slider {
    id = "tolerance",
    label = "Tolerance:",
    min = 0,
    max = 100,
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
        local args = dlg.data
        local state = args.useLight
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
        local args = dlg.data
        local state = args.usec
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
        local args = dlg.data
        local state = args.useh
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
        local args = dlg.data
        local state = args.useAlpha
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
    max = 135,
    value = defaults.minc,
    visible = defaults.uiMode == "CRITERIA"
        and defaults.usec
}

dlg:slider {
    id = "maxc",
    min = 0,
    max = 135,
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
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local activeLayer = app.activeLayer
        if not activeLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
            }
            return
        end

        -- TODO: Improve support for tilemaps?
        if AseUtilities.tilesSupport() then
            if activeLayer.isTilemap then
                app.alert {
                    title = "Error",
                    text = "Tile maps are not supported."
                }
            end
            return
        end

        if activeLayer.isGroup then
            app.alert {
                title = "Error",
                text = "Group layers are not supported."
            }
            return
        end

        local activeFrame = app.activeFrame
        if not activeFrame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
            }
            return
        end

        local activeCel = activeLayer:cel(activeFrame)
        if not activeCel then
            app.alert {
                title = "Error",
                text = "There is no active cel."
            }
            return
        end

        local args = dlg.data
        local uiMode = args.uiMode or defaults.uiMode --[[@as string]]
        local selMode = args.selMode or defaults.selMode --[[@as string]]

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

        local colorMode = activeSprite.colorMode
        local exactSearch = false
        local refHex = 0x0

        -- Cache global methods.
        local atan2 = math.atan
        local fromHex = Clr.fromHex
        local sRgbaToLab = Clr.sRgbToSrLab2

        if uiMode == "COLOR" then
            local refColor = args.refColor --[[@as Color]]
            local tolerance = args.tolerance --[[@as integer]]

            exactSearch = tolerance == 0
            if exactSearch then
                refHex = AseUtilities.aseColorToHex(refColor, colorMode)
            else
                useLight = true
                usea = true
                useb = true
                useAlpha = true

                local refClr = AseUtilities.aseColorToClr(refColor)
                local refLab = sRgbaToLab(refClr)

                local tol100 = math.max(0.000001,
                    tolerance * 0.5)
                minLight = refLab.l - tol100
                maxLight = refLab.l + tol100

                local tol111 = math.max(0.000001,
                    tolerance * (50.0 / 111.0))
                mina = refLab.a - tol111
                maxa = refLab.a + tol111

                minb = refLab.b - tol111
                maxb = refLab.b + tol111

                local tol255 = math.max(0.000001,
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

        local image = activeCel.image
        local pxItr = image:pixels()

        local trgSel = Selection()
        local pxRect = Rectangle(0, 0, 1, 1)

        local celBounds = activeCel.bounds
        local xCel = celBounds.x
        local yCel = celBounds.y

        if exactSearch then
            for pixel in pxItr do
                if pixel() == refHex then
                    pxRect.x = pixel.x
                    pxRect.y = pixel.y
                    trgSel:add(pxRect)
                end
            end
        else
            if colorMode ~= ColorMode.RGB then
                app.alert {
                    title = "Error",
                    text = "Only RGB color mode is supported."
                }
                return
            end

            -- Alpha is listed in [0, 255] but compared in [0.0, 1.0].
            -- Chroma is compared in magnitude squared.
            -- Hue is listed in [0, 360] but compared in [0, tau].
            local usePolar = usec or useh
            local mint01 = minAlpha * 0.003921568627451
            local maxt01 = maxAlpha * 0.003921568627451
            local mincsq = minc * minc
            local maxcsq = maxc * maxc
            local minhrd = minh * 0.017453292519943
            local maxhrd = maxh * 0.017453292519943

            local visited = {}
            local filtered = {}
            for pixel in pxItr do
                local hex = pixel()
                local include = false

                if visited[hex] then
                    include = filtered[hex]
                else
                    local lab = sRgbaToLab(fromHex(hex))
                    local l = lab.l
                    local a = lab.a
                    local b = lab.b
                    local t = lab.alpha

                    include = t >= mint01 and t <= maxt01
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
                        local csq = a * a + b * b
                        if useh then
                            if csq > 0.00005 then
                                local h = atan2(b, a) % 6.2831853071796
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

                    visited[hex] = true
                    filtered[hex] = include
                end

                if include then
                    pxRect.x = xCel + pixel.x
                    pxRect.y = yCel + pixel.y
                    trgSel:add(pxRect)
                end
            end
        end

        if selMode ~= "REPLACE" then
            local activeSel = AseUtilities.getSelection(activeSprite)
            if selMode == "INTERSECT" then
                activeSel:intersect(trgSel)
            elseif selMode == "SUBTRACT" then
                activeSel:subtract(trgSel)
            else
                -- Additive selection can be confusing when no prior
                -- selection is made and getSelection returns cel bounds.
                activeSel:add(trgSel)
            end
            activeSprite.selection = activeSel
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
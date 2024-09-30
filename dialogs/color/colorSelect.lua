dofile("../../support/aseutilities.lua")

local uiModes <const> = { "COLOR", "COORD", "CRITERIA", "CURSOR" }
local selModes <const> = { "REPLACE", "ADD", "SUBTRACT", "INTERSECT" }
local sampleModes <const> = { "ACTIVE", "COMPOSITE" }
local connections <const> = { "DIAMOND", "SQUARE" }

local defaults <const> = {
    -- Original colorSelect script:
    -- 894bd701787526bae1786364073b8bc263d3a032

    uiMode = "COLOR",
    selMode = "INTERSECT",
    sampleMode = "ACTIVE",
    tolerance = 0,
    ignoreAlpha = false,
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
    xCoord = 0,
    yCoord = 0,
    connection = "DIAMOND"
}

---@param lab { l: number, a: number, b: number, alpha: number }
---@param mint01 number
---@param maxt01 number
---@param useLight boolean
---@param minLight number
---@param maxLight number
---@param usePolar boolean
---@param usec boolean
---@param mincsq number
---@param maxcsq number
---@param useh boolean
---@param minhrd number
---@param maxhrd number
---@return boolean
local function critEval(
    lab, mint01, maxt01,
    useLight, minLight, maxLight,
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

---@param a { l: number, a: number, b: number, alpha: number }
---@param b { l: number, a: number, b: number, alpha: number }
---@param alphaScale number
---@return number
local function distSqInclAlpha(a, b, alphaScale)
    -- Scale alpha to be at least somewhat
    -- proportional to other channels.
    local dt <const> = alphaScale * (b.alpha - a.alpha)
    local dl <const> = b.l - a.l
    local da <const> = b.a - a.a
    local db <const> = b.b - a.b
    return dt * dt + dl * dl + da * da + db * db
end

---@param a { l: number, a: number, b: number, alpha: number }
---@param b { l: number, a: number, b: number, alpha: number }
---@return number
local function distSqNoAlpha(a, b)
    local dl <const> = b.l - a.l
    local da <const> = b.a - a.a
    local db <const> = b.b - a.b
    return dl * dl + da * da + db * db
end

local dlg <const> = Dialog { title = "Select Color" }

dlg:combobox {
    id = "selMode",
    label = "Logic:",
    option = defaults.selMode,
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
        local tolerance <const> = args.tolerance --[[@as integer]]

        local isCriteria <const> = uiMode == "CRITERIA"
        local isColor <const> = uiMode == "COLOR"
        local isCursor <const> = uiMode == "CURSOR"
        local isCoord <const> = uiMode == "COORD"

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
        dlg:modify { id = "tolerance", visible = isColor or isCursor or isCoord }
        dlg:modify { id = "ignoreAlpha", visible = (isColor or isCursor or isCoord) and tolerance > 0 }

        dlg:modify { id = "connection", visible = isCursor or isCoord }

        dlg:modify { id = "xCoord", visible = isCoord }
        dlg:modify { id = "yCoord", visible = isCoord }

        -- This needs to be copied by value, not by reference, to avoid
        -- intereference from color mode.
        local appPrefs <const> = app.preferences
        if appPrefs then
            local colorBarPrefs <const> = appPrefs.color_bar
            if colorBarPrefs then
                local fgColor <const> = colorBarPrefs.fg_color --[[@as Color]]
                if fgColor then
                    dlg:modify { id = "refColor", color = Color {
                        r = fgColor.red,
                        g = fgColor.green,
                        b = fgColor.blue,
                        a = fgColor.alpha
                    } }
                end
            end
        end
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "xCoord",
    label = "Coord:",
    text = string.format("%d", defaults.xCoord),
    decimals = 0,
    visible = defaults.uiMode == "COORD",
    focus = false
}

dlg:number {
    id = "yCoord",
    text = string.format("%d", defaults.yCoord),
    decimals = 0,
    visible = defaults.uiMode == "COORD",
    focus = false
}

dlg:newrow { always = false }

dlg:color {
    id = "refColor",
    label = "Color:",
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
        or defaults.uiMode == "CURSOR"
        or defaults.uiMode == "COORD",
    onchange = function()
        local args <const> = dlg.data
        local tolerance <const> = args.tolerance --[[@as integer]]
        dlg:modify { id = "ignoreAlpha", visible = tolerance > 0 }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "ignoreAlpha",
    label = "Ignore:",
    text = "&Alpha",
    selected = defaults.ignoreAlpha,
    visible = (defaults.uiMode == "COLOR"
            or defaults.uiMode == "CURSOR"
            or defaults.uiMode == "COORD")
        and defaults.tolerance > 0
}

dlg:newrow { always = false }

dlg:combobox {
    id = "connection",
    label = "Matrix:",
    option = defaults.connection,
    options = connections,
    visible = defaults.uiMode == "CURSOR"
        or defaults.uiMode == "COORD"
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
    focus = true,
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

        local activeFrame <const> = site.frame
        if not activeFrame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
            }
            return
        end

        -- Get the current selection.
        local activeSel <const>, selIsValid = AseUtilities.getSelection(activeSprite)
        local selBounds <const> = activeSel.bounds

        -- Unpack sprite spec.
        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        local colorSpace <const> = spriteSpec.colorSpace
        local alphaIndex <const> = spriteSpec.transparentColor
        local wSprite <const> = spriteSpec.width
        local hSprite <const> = spriteSpec.height

        local args <const> = dlg.data

        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]
        local selIsInter <const> = selMode == "INTERSECT"
        local selIsSub <const> = selMode == "SUBTRACT"
        local selIsReplace <const> = selMode == "REPLACE"

        -- Minimize pointless searches outside the current selection.
        -- See https://community.aseprite.org/t/selecting-pixels-on-a-large-canvas/ .
        local blitIntersect <const> = selIsValid and (selIsInter or selIsSub)

        local image = nil
        local xtl = 0
        local ytl = 0
        local wImage = wSprite
        local hImage = hSprite

        local sampleMode <const> = args.sampleMode
            or defaults.sampleMode --[[@as string]]
        if sampleMode == "COMPOSITE" then
            if blitIntersect then
                xtl = selBounds.x
                ytl = selBounds.y
                wImage = selBounds.width
                hImage = selBounds.height

                local selSpec <const> = AseUtilities.createSpec(
                    wImage, hImage, colorMode, colorSpace, alphaIndex)
                image = Image(selSpec)
                image:drawSprite(activeSprite, activeFrame, Point(-xtl, -ytl))
            else
                image = Image(spriteSpec)
                image:drawSprite(activeSprite, activeFrame)
            end
        else
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

            if activeLayer.isGroup then
                local flat <const>, rect <const> = AseUtilities.flattenGroup(
                    activeLayer, activeFrame, colorMode, colorSpace, alphaIndex,
                    true, true, true, true)

                image = flat
                xtl = rect.x
                ytl = rect.y
                wImage = rect.width
                hImage = rect.height
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
                    image = AseUtilities.tileMapToImage(
                        image, activeLayer.tileset, colorMode)
                end
                local celPos <const> = activeCel.position
                xtl = celPos.x
                ytl = celPos.y
                wImage = image.width
                hImage = image.height
            end

            if blitIntersect then
                local xtlMax <const> = math.max(xtl, selBounds.x)
                local ytlMax <const> = math.max(ytl, selBounds.y)
                local xbrMin <const> = math.min(
                    xtl + image.width - 1,
                    selBounds.x + selBounds.width - 1)
                local ybrMin <const> = math.min(
                    ytl + image.height - 1,
                    selBounds.y + selBounds.height - 1)
                local wInter <const> = 1 + xbrMin - xtlMax
                local hInter <const> = 1 + ybrMin - ytlMax

                -- How to handle cases where width or height is <= 0 and no
                -- pixels would be selected except for case where mask is
                -- equal to alpha index? Could return early?
                if wInter > 0 or hInter > 0 then
                    local interSpec <const> = AseUtilities.createSpec(
                        wInter, hInter, colorMode, colorSpace, alphaIndex)
                    local interImg <const> = Image(interSpec)
                    interImg:drawImage(image, Point(xtl - xtlMax, ytl - ytlMax))

                    image = interImg
                    xtl = xtlMax
                    ytl = ytlMax
                    wImage = image.width
                    hImage = image.height
                end
            end
        end

        local uiMode <const> = args.uiMode
            or defaults.uiMode --[[@as string]]
        local uiIsCursor <const> = uiMode == "CURSOR"
        local uiIsCriteria <const> = uiMode == "CRITERIA"
        local isMagicWand <const> = uiIsCursor or uiMode == "COORD"

        local cmIsIdx <const> = colorMode == ColorMode.INDEXED
        local cmIsGry <const> = colorMode == ColorMode.GRAY

        -- Cache global methods.
        local fromHex32 <const> = Clr.fromHexAbgr32
        local fromHex16 <const> = Clr.fromHexAv16
        local sRgbaToLab <const> = Clr.sRgbToSrLab2
        local aseColorToClr <const> = AseUtilities.aseColorToClr
        local aseColorToHex <const> = AseUtilities.aseColorToHex
        local strunpack <const> = string.unpack
        local strsub <const> = string.sub

        local palette <const> = AseUtilities.getPalette(
            activeFrame, activeSprite.palettes)
        local lenPalette <const> = #palette

        local trgSel <const> = isMagicWand
            and Selection()
            or Selection(Rectangle(xtl, ytl, wImage, hImage))
        local pxRect <const> = Rectangle(0, 0, 1, 1)
        local srcBpp <const> = image.bytesPerPixel
        local packFmt <const> = "<I" .. srcBpp
        local srcBytes <const> = image.bytes

        if uiIsCriteria then
            local useLight = args.useLight --[[@as boolean]]
            local usec = args.usec --[[@as boolean]]
            local useh = args.useh --[[@as boolean]]
            local useAlpha = args.useAlpha --[[@as boolean]]

            local minLight = args.minLight
                or defaults.minLight --[[@as number]]
            local minc = args.minc
                or defaults.minc --[[@as number]]
            local minh = args.minh
                or defaults.minh --[[@as number]]

            local maxLight = args.maxLight
                or defaults.maxLight --[[@as number]]
            local maxc = args.maxc
                or defaults.maxc --[[@as number]]
            local maxh = args.maxh
                or defaults.maxh --[[@as number]]

            local minAlpha = 1.0
            local maxAlpha = 255.0
            if useAlpha then
                minAlpha = args.minAlpha
                    or defaults.minAlpha --[[@as number]]
                maxAlpha = args.maxAlpha
                    or defaults.maxAlpha --[[@as number]]
            end

            -- Disable criteria if minimum is equal to maximum.
            if minLight == maxLight then useLight = false end
            if minc == maxc then usec = false end
            if minh == maxh then useh = false end
            if minAlpha == maxAlpha then useAlpha = false end

            -- Disable criteria if grayscale.
            if cmIsGry then usec = false end
            if cmIsGry then useh = false end

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

            ---@type table<integer, boolean>
            local evaluated <const> = {}
            local areaImage <const> = wImage * hImage
            local i = 0
            while i < areaImage do
                local lookup <const> = srcBpp * i
                local c <const> = strunpack(packFmt, strsub(
                    srcBytes, 1 + lookup, srcBpp + lookup))

                local include = evaluated[c]
                if include == nil then
                    local srgb = nil
                    if cmIsIdx then
                        if c >= 0 and c < lenPalette then
                            local aseColor <const> = palette:getColor(c)
                            srgb = aseColorToClr(aseColor)
                        else
                            srgb = Clr.new(0, 0, 0, 0)
                        end
                    elseif cmIsGry then
                        srgb = fromHex16(c)
                    else
                        srgb = fromHex32(c)
                    end
                    local lab <const> = sRgbaToLab(srgb)
                    include = critEval(
                        lab, mint01, maxt01,
                        useLight, minLight, maxLight,
                        usePolar,
                        usec, mincsq, maxcsq,
                        useh, minhrd, maxhrd)
                    evaluated[c] = include
                end

                if include == false then
                    pxRect.x = xtl + i % wImage
                    pxRect.y = ytl + i // wImage
                    trgSel:subtract(pxRect)
                end

                i = i + 1
            end
        else
            -- Default to search by Euclidean distance.

            local refColor <const> = args.refColor --[[@as Color]]
            local tolerance <const> = args.tolerance
                or defaults.tolerance --[[@as integer]]
            local ignoreAlpha <const> = args.ignoreAlpha --[[@as boolean]]

            local xMouse = args.xCoord
                or defaults.xCoord --[[@as integer]]
            local yMouse = args.yCoord
                or defaults.yCoord --[[@as integer]]
            if uiIsCursor then
                xMouse, yMouse = AseUtilities.getMouse()
            end

            -- print(string.format(
            --     "xMouse: %d, yMouse: %d",
            --     xMouse, yMouse))

            local refClr = aseColorToClr(refColor)
            local refInt = aseColorToHex(refColor, colorMode)

            if isMagicWand then
                local xLocal <const> = xMouse - xtl
                local yLocal <const> = yMouse - ytl
                if xLocal >= 0 and xLocal < wImage
                    and yLocal >= 0 and yLocal < hImage then
                    local lookup <const> = srcBpp * (yLocal * wImage + xLocal)
                    local c <const> = strunpack(packFmt, strsub(
                        srcBytes, 1 + lookup, srcBpp + lookup))
                    if cmIsIdx then
                        refInt = c
                        if c >= 0 and c < lenPalette then
                            local aseColor <const> = palette:getColor(c)
                            refClr = aseColorToClr(aseColor)
                        else
                            refClr = Clr.new(0, 0, 0, 0)
                        end
                    elseif cmIsGry then
                        refInt = c
                        refClr = fromHex16(c)
                    else
                        refInt = c
                        refClr = fromHex32(c)
                    end
                else
                    -- You could set the reference to alpha index, but it seems
                    -- simpler just to return early.
                    return
                end
            end

            local distSq <const> = ignoreAlpha
                and distSqNoAlpha
                or distSqInclAlpha

            local eval = function(c) return c == refInt end

            local useExactSearch <const> = (not uiIsCriteria)
                and tolerance == 0
            if not useExactSearch then
                local refLab <const> = sRgbaToLab(refClr)
                local tScl <const> = 100.0
                local tolsq <const> = tolerance * tolerance

                if colorMode == ColorMode.INDEXED then
                    eval = function(c8)
                        if c8 >= 0 and c8 < lenPalette then
                            local aseColor <const> = palette:getColor(c8)
                            local srgb <const> = aseColorToClr(aseColor)
                            local lab <const> = sRgbaToLab(srgb)
                            return distSq(lab, refLab, tScl) <= tolsq
                        end
                        return false
                    end
                elseif colorMode == ColorMode.GRAY then
                    eval = function(c16)
                        local lab <const> = sRgbaToLab(fromHex16(c16))
                        return distSq(lab, refLab, tScl) <= tolsq
                    end
                else
                    -- Default to RGB color mode.
                    eval = function(c32)
                        local lab <const> = sRgbaToLab(fromHex32(c32))
                        return distSq(lab, refLab, tScl) <= tolsq
                    end
                end
            end

            if isMagicWand then
                local connection <const> = args.connection
                    or defaults.connection --[[@as string]]
                local useConnect8 <const> = connection == "SQUARE"

                ---@type table<integer, boolean>
                local visited <const> = {}
                ---@type integer[]
                local neighbors <const> = { yMouse * wSprite + xMouse }
                local lenNeighbors = 1

                while lenNeighbors > 0 do
                    -- Removing from the back may be slightly faster than from
                    -- the front.
                    local coord <const> = neighbors[lenNeighbors]
                    neighbors[lenNeighbors] = nil
                    lenNeighbors = lenNeighbors - 1

                    if not visited[coord] then
                        visited[coord] = true

                        local xNgbr <const> = coord % wSprite
                        local yNgbr <const> = coord // wSprite
                        local xLocal <const> = xNgbr - xtl
                        local yLocal <const> = yNgbr - ytl

                        -- TODO: Is there a more efficient implementation?
                        -- http://www.adammil.net/blog/v126_A_More_Efficient_Flood_Fill.html
                        -- https://www.codeproject.com/Articles/6017/QuickFill-An-Efficient-Flood-Fill-Algorithm
                        if yLocal >= 0 and yLocal < hImage
                            and xLocal >= 0 and xLocal < wImage then
                            local lookup <const> = srcBpp * (yLocal * wImage + xLocal)
                            local cNgbr <const> = strunpack(packFmt, strsub(
                                srcBytes, 1 + lookup, srcBpp + lookup))

                            if eval(cNgbr) then
                                pxRect.x = xNgbr
                                pxRect.y = yNgbr
                                trgSel:add(pxRect)

                                local ywSprite <const> = yNgbr * wSprite
                                local yn1wSprite <const> = ywSprite - wSprite
                                local yp1wSprite <const> = ywSprite + wSprite

                                if useConnect8 then
                                    neighbors[1 + lenNeighbors] = yn1wSprite + xNgbr - 1
                                    neighbors[2 + lenNeighbors] = yn1wSprite + xNgbr
                                    neighbors[3 + lenNeighbors] = yn1wSprite + xNgbr + 1
                                    neighbors[4 + lenNeighbors] = ywSprite + xNgbr - 1
                                    neighbors[5 + lenNeighbors] = ywSprite + xNgbr + 1
                                    neighbors[6 + lenNeighbors] = yp1wSprite + xNgbr - 1
                                    neighbors[7 + lenNeighbors] = yp1wSprite + xNgbr
                                    neighbors[8 + lenNeighbors] = yp1wSprite + xNgbr + 1
                                    lenNeighbors = lenNeighbors + 8
                                else
                                    neighbors[1 + lenNeighbors] = yn1wSprite + xNgbr
                                    neighbors[2 + lenNeighbors] = ywSprite + xNgbr - 1
                                    neighbors[3 + lenNeighbors] = ywSprite + xNgbr + 1
                                    neighbors[4 + lenNeighbors] = yp1wSprite + xNgbr
                                    lenNeighbors = lenNeighbors + 4
                                end -- Connect 8 check.
                            end     -- Exact equality check.
                        end         -- In bounds check.
                    end             -- Not visited check.
                end                 -- Neighbor loop.
            else
                -- Default to searching the entire image.

                ---@type table<integer, boolean>
                local evaluated <const> = {}
                local areaImage <const> = wImage * hImage
                local i = 0
                while i < areaImage do
                    local lookup <const> = srcBpp * i
                    local c <const> = strunpack(packFmt, strsub(
                        srcBytes, 1 + lookup, srcBpp + lookup))

                    local include = evaluated[c]
                    if include == nil then
                        include = eval(c)
                        evaluated[c] = include
                    end

                    if include == false then
                        pxRect.x = xtl + i % wImage
                        pxRect.y = ytl + i // wImage
                        trgSel:subtract(pxRect)
                    end
                    i = i + 1
                end
            end
        end

        app.transaction("Select Colors", function()
            -- TODO: Generalize this to an AseUtilities method to keep
            -- consistency with transformTile and maskPresets? Problem is
            -- that this does not create an active selection, it has already
            -- been created.
            if not selIsReplace then
                if selIsValid then
                    if selIsInter then
                        activeSel:intersect(trgSel)
                    elseif selIsSub then
                        activeSel:subtract(trgSel)
                    else
                        activeSel:add(trgSel)
                    end
                    activeSprite.selection = activeSel
                else
                    activeSprite.selection = trgSel
                end
            else
                activeSprite.selection = trgSel
            end
        end)

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

dlg:show {
    autoscrollbars = true,
    wait = false
}
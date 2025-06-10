dofile("../../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local channels <const> = { "LIGHT", "A", "B", "CHROMA", "HUE", "DIST" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults <const> = {
    target = "ACTIVE",
    delSrc = "NONE",
    channel = "LIGHT",
    useSrcClr = false,
    trimCels = true,

    lShadows = true,
    lMidtones = true,
    lHighlights = true,

    aGreens = true,
    aMagentas = true,

    bBlues = true,
    bYellows = true,

    cGray = true,
    cMiddle = true,
    cVivid = true,

    trgHue = 0,
    respFocus = 67,

    -- Because a and b need to be centered about 0.0,
    -- the range is based on the greater number.
    -- aAbsMin = -82.709187739605,
    -- aAbsMax = 104.18850360397,
    -- aAbsRange = 186.89769134357,
    -- bAbsMin = -110.47816964815,
    -- bAbsMax = 94.903461003717,
    -- bAbsRange = 205.38163065187
    aAbsMin = -104.18850360397,
    aAbsRange = 208.37700720794,
    bAbsMin = -110.47816964815,
    bAbsRange = 220.9563392963,
    maxChroma = 119.07602046756,

    -- Based on a color with l and alpha zero,
    -- plus the non-centered a and b minima above,
    -- distance calculation to a color with l and
    -- alpha max plus the non-centered a and b max.
    -- normDist = 1.0 / 295.14803275438,
    normDist = 0.01,
    useInvert = false,
}

---@param x number
---@return number
local function fullResponse(x)
    if x <= 0.0 then return 0.0 end
    if x >= 1.0 then return 1.0 end
    return x * x * (3.0 - (x + x))
end

---@param x number
---@return number
local function highHalfResponse(x)
    return fullResponse(1.3333333333333 * x
        - 0.33333333333333)
end

---@param x number
---@return number
local function highThirdResponse(x)
    return fullResponse(x + x - 1.0)
end

---@param x number
---@return number
local function lowHalfResponse(x)
    return fullResponse(1.0 - 1.3333333333333 * x)
end

---@param x number
---@return number
local function lowThirdResponse(x)
    return fullResponse(1.0 - (x + x))
end

---@param x number
---@return number
local function midResponse(x)
    return 1.0 - fullResponse(math.abs(x + x - 1.0))
end

---@param x number
---@return number
local function splitResponse(x)
    return fullResponse(math.abs(1.0 - (x + x)))
end

local dlg <const> = Dialog { title = "Separate LAB" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "delSrc",
    label = "Source:",
    option = defaults.delSrc,
    options = delOptions
}

dlg:newrow { always = false }

dlg:combobox {
    id = "channel",
    label = "Criterion:",
    options = channels,
    option = defaults.channel,
    onchange = function()
        local args <const> = dlg.data
        local channel <const> = args.channel --[[@as string]]

        local isl <const> = channel == "LIGHT"
        local isa <const> = channel == "A"
        local isb <const> = channel == "B"
        local isc <const> = channel == "CHROMA"
        local ish <const> = channel == "HUE"
        local isDist <const> = channel == "DIST"

        dlg:modify { id = "lShadows", visible = isl }
        dlg:modify { id = "lMidtones", visible = isl }
        dlg:modify { id = "lHighlights", visible = isl }

        dlg:modify { id = "aGreens", visible = isa }
        dlg:modify { id = "aMagentas", visible = isa }

        dlg:modify { id = "bBlues", visible = isb }
        dlg:modify { id = "bYellows", visible = isb }

        dlg:modify { id = "cGray", visible = isc }
        dlg:modify { id = "cMiddle", visible = isc }
        dlg:modify { id = "cVivid", visible = isc }

        dlg:modify { id = "trgHue", visible = ish }
        dlg:modify { id = "respFocus", visible = ish or isDist }
        dlg:modify { id = "getHue", visible = ish }

        dlg:modify { id = "refColor", visible = isDist }
        dlg:modify { id = "useInvert", visible = isDist }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "lShadows",
    label = "Bias:",
    text = "&Shadows",
    selected = defaults.lShadows,
    visible = defaults.channel == "LIGHT",
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "lMidtones",
    text = "&Midtones",
    selected = defaults.lMidtones,
    visible = defaults.channel == "LIGHT",
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "lHighlights",
    text = "&Highlights",
    selected = defaults.lHighlights,
    visible = defaults.channel == "LIGHT",
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "aGreens",
    label = "Bias:",
    text = "&Greens",
    selected = defaults.aGreens,
    visible = defaults.channel == "A",
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "aMagentas",
    text = "&Reds",
    selected = defaults.aMagentas,
    visible = defaults.channel == "A",
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "bBlues",
    label = "Bias:",
    text = "&Blues",
    selected = defaults.bBlues,
    visible = defaults.channel == "B",
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "bYellows",
    text = "&Yellows",
    selected = defaults.bYellows,
    visible = defaults.channel == "B",
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "cGray",
    text = "G&ray",
    selected = defaults.cGray,
    visible = defaults.channel == "CHROMA",
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "cMiddle",
    text = "Mi&ddle",
    selected = defaults.cMiddle,
    visible = defaults.channel == "CHROMA",
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "cVivid",
    text = "&Vivid",
    selected = defaults.cVivid,
    visible = defaults.channel == "CHROMA",
    hexpand = false,
}

dlg:newrow { always = false }

dlg:slider {
    id = "respFocus",
    label = "Focus:",
    min = 0,
    max = 100,
    value = defaults.respFocus,
    visible = defaults.channel == "HUE"
        or defaults.channel == "DIST"
}

dlg:newrow { always = false }

dlg:slider {
    id = "trgHue",
    label = "Hue:",
    min = 0,
    max = 360,
    value = defaults.trgHue,
    visible = defaults.channel == "HUE"
}

dlg:newrow { always = false }

dlg:button {
    id = "getHue",
    label = "Get:",
    text = "C&ANVAS",
    visible = defaults.channel == "HUE",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local sprite <const> = site.sprite
        if not sprite then return end
        local frObj <const> = site.frame
        if not frObj then return end

        local lab <const> = AseUtilities.averageColor(
            sprite, frObj.frameNumber)
        if lab.alpha > 0.0 then
            local lch <const> = Lab.toLch(lab)
            if lch.c > 0.000001 then
                local deg <const> = Utilities.round(lch.h * 360.0)
                dlg:modify { id = "trgHue", value = deg }
            end
        end
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "refColor",
    label = "To:",
    color = Color { r = 0, g = 0, b = 0, a = 255 },
    visible = defaults.channel == "DIST"
}

dlg:newrow { always = false }

dlg:check {
    id = "useInvert",
    label = "Invert:",
    text = "&Factor",
    selected = defaults.useInvert,
    visible = defaults.channel == "DIST",
    focus = false,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "useSrcClr",
    label = "Color:",
    text = "Source",
    selected = defaults.useSrcClr,
    focus = true,
    hexpand = false,
    onclick = function()
        local args <const> = dlg.data
        local useSrcClr <const> = args.useSrcClr --[[@as boolean]]
        dlg:modify { id = "maskColor", visible = not useSrcClr }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "maskColor",
    color = Color { r = 255, g = 255, b = 255, a = 255 },
    visible = not defaults.useSrcClr
}

dlg:newrow { always = false }

dlg:check {
    id = "trimCels",
    label = "Trim:",
    text = "Layer Ed&ges",
    selected = defaults.trimCels,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
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

        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local srcLayer <const> = site.layer
        if not srcLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
            }
            return
        end

        if srcLayer.isReference then
            app.alert {
                title = "Error",
                text = "Reference layers are not supported."
            }
            return
        end

        if srcLayer.isGroup then
            app.alert {
                title = "Error",
                text = "Group layers are not supported."
            }
            return
        end

        -- Check for tile maps.
        local isTilemap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset
        end

        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local delSrcStr <const> = args.delSrc
            or defaults.delSrc --[[@as string]]
        local channel <const> = args.channel
            or defaults.channel --[[@as string]]
        local useSrcClr <const> = args.useSrcClr --[[@as boolean]]
        local maskColor <const> = args.maskColor --[[@as Color]]
        local trimCels <const> = args.trimCels --[[@as boolean]]

        local alphaIndex <const> = spriteSpec.transparentColor
        local maskBgr24 <const> = maskColor.blue << 0x10
            | maskColor.green << 0x08
            | maskColor.red
        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        ---@type fun(x: number): number
        local responseFunc = function(x) return 0.0 end
        ---@type fun(lab: Lab): number
        local toFac = function(lab) return 0.0 end
        local biasLabel = ""
        if channel == "A" then
            toFac = function(lab)
                return (lab.a - defaults.aAbsMin) / defaults.aAbsRange
            end

            local aGreens <const> = args.aGreens --[[@as boolean]]
            local aMagentas <const> = args.aMagentas --[[@as boolean]]

            if aGreens and aMagentas then
                responseFunc = splitResponse
                biasLabel = " A Extrema"
            elseif aGreens then
                responseFunc = lowHalfResponse
                biasLabel = " Greens"
            elseif aMagentas then
                responseFunc = highHalfResponse
                biasLabel = " Reds"
            else
                responseFunc = midResponse
                biasLabel = " A Central"
            end
        elseif channel == "B" then
            toFac = function(lab)
                return (lab.b - defaults.bAbsMin) / defaults.bAbsRange
            end

            local bBlues <const> = args.bBlues --[[@as boolean]]
            local bYellows <const> = args.bYellows --[[@as boolean]]

            if bBlues and bYellows then
                responseFunc = splitResponse
                biasLabel = " B Extrema"
            elseif bBlues then
                responseFunc = lowHalfResponse
                biasLabel = " Blues"
            elseif bYellows then
                responseFunc = highHalfResponse
                biasLabel = " Yellows"
            else
                responseFunc = midResponse
                biasLabel = " B Central"
            end
        elseif channel == "CHROMA" then
            toFac = function(lab)
                return math.sqrt(lab.a * lab.a + lab.b * lab.b)
                    / defaults.maxChroma
            end

            local cGray <const> = args.cGray --[[@as boolean]]
            local cMiddle <const> = args.cMiddle --[[@as boolean]]
            local cVivid <const> = args.cVivid --[[@as boolean]]

            biasLabel = " C"
            if cGray and cMiddle and cVivid then
                responseFunc = fullResponse
            elseif cGray and cVivid then
                responseFunc = splitResponse
            elseif cGray and cMiddle then
                responseFunc = lowHalfResponse
            elseif cMiddle and cVivid then
                responseFunc = highHalfResponse
            elseif cGray then
                responseFunc = lowThirdResponse
                biasLabel = " Gray"
            elseif cMiddle then
                responseFunc = midResponse
            elseif cVivid then
                responseFunc = highThirdResponse
                biasLabel = " Vivid"
            else
                app.alert {
                    title = "Error",
                    text = "No biases selected."
                }
                return
            end
        elseif channel == "HUE" then
            local trgHueDeg <const> = args.trgHue
                or defaults.trgHue --[[@as integer]]
            local respFocus100 <const> = args.respFocus
                or defaults.respFocus --[[@as integer]]

            biasLabel = string.format(
                " H %03d F %02d",
                trgHueDeg, respFocus100)

            local respFocus01 <const> = math.min(respFocus100 * 0.01, 0.999999)
            responseFunc = function(x)
                local y <const> = (x - respFocus01) / (1.0 - respFocus01)
                if y <= 0.0 then return 0.0 end
                if y >= 1.0 then return 1.0 end
                return y * y * (3.0 - (y + y))
            end

            local trgHueRad <const> = 0.017453292519943 * trgHueDeg
            local oa <const> = math.cos(trgHueRad)
            local ob <const> = math.sin(trgHueRad)

            toFac = function(lab)
                local da <const> = lab.a
                local db <const> = lab.b
                local dSqChroma <const> = da * da + db * db
                if dSqChroma < 0.000001 then return 0.0 end

                -- Mitigate discontinuities between gray and saturated colors
                -- by creating a knee at 0.1.
                local dChroma <const> = math.sqrt(dSqChroma)
                local chromaNorm <const> = dChroma / defaults.maxChroma
                local c = 1.0
                if chromaNorm < 0.1 then
                    c = chromaNorm * 10.0
                    c = c * c * (3.0 - (c + c))
                end

                -- angDist = acos(dot(o, d) / (mag(o) * mag(d)))
                -- Normalization of dot product can be simplified because
                -- oChroma is already known to be one.
                local dotNorm <const> = (oa * da + ob * db) / dChroma

                -- acos returns a value within [0, pi].
                local acosNorm <const> = math.acos(dotNorm) * 0.31830988618379
                return c * (1.0 - acosNorm)
            end
        elseif channel == "DIST" then
            local refColor <const> = args.refColor --[[@as Color]]
            local refSrgb <const> = AseUtilities.aseColorToRgb(refColor)
            local refLab <const> = ColorUtilities.sRgbToSrLab2(refSrgb)
            local normDist <const> = defaults.normDist
            local useInvert <const> = args.useInvert --[[@as boolean]]
            toFac = function(lab)
                local dl <const> = refLab.l - lab.l
                local da <const> = refLab.a - lab.a
                local db <const> = refLab.b - lab.b
                local x <const> = normDist * math.sqrt(
                    dl * dl + da * da + db * db)
                return useInvert and x or 1.0 - x
            end

            local respFocus100 <const> = args.respFocus
                or defaults.respFocus --[[@as integer]]
            local respFocus01 <const> = math.min(respFocus100 * 0.01, 0.999999)
            responseFunc = function(x)
                local y <const> = (x - respFocus01) / (1.0 - respFocus01)
                if y <= 0.0 then return 0.0 end
                if y >= 1.0 then return 1.0 end
                return y * y * (3.0 - (y + y))
            end

            biasLabel = string.format(
                " Dist %s F %02d",
                Rgb.toHexWeb(refSrgb),
                respFocus100)
        else
            -- Default to lightness.
            toFac = function(lab) return lab.l * 0.01 end

            local lShadows <const> = args.lShadows --[[@as boolean]]
            local lMidtones <const> = args.lMidtones --[[@as boolean]]
            local lHighlights <const> = args.lHighlights --[[@as boolean]]

            if lShadows and lMidtones and lHighlights then
                responseFunc = fullResponse
                biasLabel = " L"
            elseif lShadows and lHighlights then
                responseFunc = splitResponse
                biasLabel = " SH"
            elseif lShadows and lMidtones then
                responseFunc = lowHalfResponse
                biasLabel = " SM"
            elseif lMidtones and lHighlights then
                responseFunc = highHalfResponse
                biasLabel = " MH"
            elseif lShadows then
                responseFunc = lowThirdResponse
                biasLabel = " Shadows"
            elseif lMidtones then
                responseFunc = midResponse
                biasLabel = " Midtones"
            elseif lHighlights then
                responseFunc = highThirdResponse
                biasLabel = " Highlights"
            else
                app.alert {
                    title = "Error",
                    text = "No biases selected."
                }
                return
            end
        end

        local trgLayer <const> = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            trgLayer.parent = AseUtilities.getTopVisibleParent(srcLayer)
            trgLayer.name = string.format(
                "%s Mask%s",
                srcLayer.name, biasLabel)
        end)

        -- Cache functions used in loop.
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local trimAlpha <const> = AseUtilities.trimImageAlpha
        local fromHex <const> = Rgb.fromHexAbgr32
        local sRgbToLab <const> = ColorUtilities.sRgbToSrLab2Internal
        local floor <const> = math.floor
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local strunpack <const> = string.unpack
        local tconcat <const> = table.concat

        local lenFrames <const> = #frames
        app.transaction("Separate LAB", function()
            local i = 0
            while i < lenFrames do
                i = i + 1
                local srcFrame <const> = frames[i]

                local xSrcPos = 0
                local ySrcPos = 0
                local srcImg = nil
                local srcCel <const> = srcLayer:cel(srcFrame)
                if srcCel then
                    srcImg = srcCel.image
                    if isTilemap then
                        srcImg = tilesToImage(srcImg, tileSet, colorMode)
                    end
                    local srcPos <const> = srcCel.position
                    xSrcPos = srcPos.x
                    ySrcPos = srcPos.y
                end

                if srcImg then
                    local srcBytes <const> = srcImg.bytes
                    local srcSpec <const> = srcImg.spec
                    local lenSrc <const> = srcSpec.width * srcSpec.height

                    ---@type table<integer, integer>
                    local srcToTrg <const> = {}
                    ---@type string[]
                    local trgBytesArr <const> = {}

                    local j = 0
                    while j < lenSrc do
                        local j4 <const> = j * 4
                        local srcAbgr32 <const> = strunpack("<I4", strsub(
                            srcBytes, 1 + j4, 4 + j4))

                        local trgAbgr32 = 0x00000000
                        if srcToTrg[srcAbgr32] then
                            trgAbgr32 = srcToTrg[srcAbgr32]
                        else
                            if (srcAbgr32 & 0xff000000) ~= 0 then
                                local clr <const> = fromHex(srcAbgr32)
                                local lab <const> = sRgbToLab(clr)
                                local fac <const> = toFac(lab)

                                -- Multiply results with source alpha even when
                                -- source color is not chosen.
                                local facw = lab.alpha * responseFunc(fac)
                                local a8Trg <const> = floor(facw * 255.0 + 0.5)

                                local trgRgb <const> = useSrcClr
                                    and (srcAbgr32 & 0x00ffffff)
                                    or maskBgr24
                                trgAbgr32 = (a8Trg << 0x18) | trgRgb
                            end

                            srcToTrg[srcAbgr32] = trgAbgr32
                        end

                        j = j + 1
                        trgBytesArr[j] = strpack("<I4", trgAbgr32)
                    end

                    local trgImg = Image(srcSpec)
                    trgImg.bytes = tconcat(trgBytesArr)

                    local xoff = 0
                    local yoff = 0
                    if trimCels then
                        trgImg, xoff, yoff = trimAlpha(trgImg, 0, alphaIndex)
                    end

                    activeSprite:newCel(
                        trgLayer, srcFrame, trgImg,
                        Point(xSrcPos + xoff, ySrcPos + yoff))
                end
            end
        end)

        -- Active layer assignment triggers a timeline update.
        AseUtilities.hideSource(activeSprite, srcLayer, frames, delSrcStr)
        app.layer = trgLayer
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
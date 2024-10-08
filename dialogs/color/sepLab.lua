dofile("../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local channels <const> = { "L", "A", "B" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults <const> = {
    target = "ACTIVE",
    delSrc = "NONE",
    channel = "L",
    useSrcClr = false,
    trimCels = true,

    lShadows = true,
    lMidtones = true,
    lHighlights = true,

    aGreens = true,
    aMagentas = true,

    bBlues = true,
    bYellows = true,

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
    bAbsRange = 220.9563392963
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
local function highHalfResponse(x)
    return fullResponse(1.3333333333333 * x
        - 0.33333333333333)
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
    label = "Channel:",
    options = channels,
    option = defaults.channel,
    onchange = function()
        local args <const> = dlg.data
        local channel <const> = args.channel --[[@as string]]

        local isl <const> = channel == "L"
        local isa <const> = channel == "A"
        local isb <const> = channel == "B"

        dlg:modify { id = "lShadows", visible = isl }
        dlg:modify { id = "lMidtones", visible = isl }
        dlg:modify { id = "lHighlights", visible = isl }

        dlg:modify { id = "aGreens", visible = isa }
        dlg:modify { id = "aMagentas", visible = isa }

        dlg:modify { id = "bBlues", visible = isb }
        dlg:modify { id = "bYellows", visible = isb }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "lShadows",
    label = "Bias:",
    text = "&Shadows",
    selected = defaults.lShadows,
    visible = defaults.channel == "L"
}

dlg:newrow { always = false }

dlg:check {
    id = "lMidtones",
    text = "&Midtones",
    selected = defaults.lMidtones,
    visible = defaults.channel == "L"
}

dlg:newrow { always = false }

dlg:check {
    id = "lHighlights",
    text = "&Highlights",
    selected = defaults.lHighlights,
    visible = defaults.channel == "L"
}

dlg:newrow { always = false }

dlg:check {
    id = "aGreens",
    label = "Bias:",
    text = "&Greens",
    selected = defaults.aGreens,
    visible = defaults.channel == "A"
}

dlg:newrow { always = false }

dlg:check {
    id = "aMagentas",
    text = "&Reds",
    selected = defaults.aMagentas,
    visible = defaults.channel == "A"
}

dlg:newrow { always = false }

dlg:check {
    id = "bBlues",
    label = "Bias:",
    text = "&Blues",
    selected = defaults.bBlues,
    visible = defaults.channel == "B"
}

dlg:newrow { always = false }

dlg:check {
    id = "bYellows",
    text = "&Yellows",
    selected = defaults.bYellows,
    visible = defaults.channel == "B"
}

dlg:newrow { always = false }

dlg:check {
    id = "useSrcClr",
    label = "Color:",
    text = "Source",
    selected = defaults.useSrcClr,
    onclick = function()
        local args <const> = dlg.data
        local useSrcClr <const> = args.useSrcClr --[[@as boolean]]
        dlg:modify { id = "maskColor", visible = not useSrcClr }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "maskColor",
    color = Color { r = 255, g = 255, b = 255 },
    visible = not defaults.useSrcClr
}

dlg:newrow { always = false }

dlg:check {
    id = "trimCels",
    label = "Trim:",
    text = "Layer Ed&ges",
    selected = defaults.trimCels
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
        ---@type fun(lab: {l: number, a: number, b: number, alpha: number}): number
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
        local fromHex <const> = Clr.fromHexAbgr32
        local sRgbaToLab <const> = Clr.sRgbToSrLab2
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
                local srcFrame = frames[i]

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
                                local lab <const> = sRgbaToLab(clr)
                                local fac <const> = toFac(lab)
                                local facw <const> = responseFunc(fac)

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
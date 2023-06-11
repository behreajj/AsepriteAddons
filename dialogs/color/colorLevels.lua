dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }
local channels = { "L", "A", "B", "Alpha" }
local idPrefixes = { "l", "a", "b", "t" }
local idPostfixes = { "LbIn", "UbIn", "LbOut", "UbOut", "Gamma" }
local idSliders = { "LbIn", "UbIn", "LbOut", "UbOut" }
local labelSliders = { "Inputs (X):", "Outputs (Y):" }
local lenIdPrefixes = #idPrefixes
local lenIdPostfixes = #idPostfixes
local lenIdSliders = #idSliders

local defaults = {
    target = "ACTIVE",
    channel = "L",
    useRelative = true,
    printElapsed = false,
    aAbsMin = -104.18850360397,
    bAbsMin = -110.47816964815
}

local dlg = Dialog { title = "Color Levels" }

---@param x number
---@param lbIn number
---@param ubIn number
---@param lbOut number
---@param ubOut number
---@param f fun(x: number): number
---@return number
local function remapChannel(x, lbIn, ubIn, lbOut, ubOut, f)
    local xrm = x - lbIn
    local rangeIn = ubIn - lbIn
    if rangeIn ~= 0.0 then xrm = xrm / rangeIn end
    local xClamped = math.min(math.max(xrm, 0.0), 1.0)
    local y = f(xClamped)
    if ubOut >= lbOut then
        return lbOut + y * (ubOut - lbOut)
    elseif ubOut < lbOut then
        return lbOut - y * (lbOut - ubOut)
    end
    return y
end

---@param srcImg Image
---@return table<integer, { l: number, a: number, b: number, alpha: number }> hexToLabDict
---@return number aMin
---@return number aMax
---@return number bMin
---@return number bMax
local function auditImage(srcImg)
    local fromHex = Clr.fromHex
    local sRgbToLab = Clr.sRgbToSrLab2

    ---@type table<integer, {l: number, a: number, b: number, alpha: number}>
    local hexToLabDict = {}
    local aMin = 2147483647
    local bMin = 2147483647
    local aMax = -2147483648
    local bMax = -2147483648

    -- Since a and b are unbounded, gather the relative
    -- bounds for this image.
    local srcItr = srcImg:pixels()
    for srcPixel in srcItr do
        local srcHex = srcPixel()
        if not hexToLabDict[srcHex] then
            local srcClr = fromHex(srcHex)
            local srcLab = sRgbToLab(srcClr)

            local aSrc = srcLab.a
            local bSrc = srcLab.b

            if aSrc < aMin then aMin = aSrc end
            if aSrc > aMax then aMax = aSrc end
            if bSrc < bMin then bMin = bSrc end
            if bSrc > bMax then bMax = bSrc end

            hexToLabDict[srcHex] = srcLab
        end
    end

    return hexToLabDict, aMin, aMax, bMin, bMax
end

---@param idPostfix string
local function setInputFromColor(idPostfix)
    local site = app.site
    local sprite = site.sprite
    if not sprite then return end
    local frame = site.frame
    if not frame then return end

    local lab = AseUtilities.averageColor(sprite, frame)

    local args = dlg.data
    local channel = args.channel --[[@as string]]

    local idPrefix = ""
    local val = 0.0
    if channel == "L" then
        idPrefix = idPrefixes[1]
        val = math.floor(lab.l * 2.55 + 0.5)
    elseif channel == "A" then
        idPrefix = idPrefixes[2]
        local aNorm = (lab.a - defaults.aAbsMin) / defaults.aAbsRange
        val = math.floor(aNorm * 255.0 + 0.5)
    elseif channel == "B" then
        idPrefix = idPrefixes[3]
        local bNorm = (lab.b - defaults.bAbsMin) / defaults.bAbsRange
        val = math.floor(bNorm * 255.0 + 0.5)
    elseif channel == "Alpha" then
        idPrefix = idPrefixes[4]
        val = math.floor(lab.alpha * 255.0 + 0.5)
    end

    local id = idPrefix .. idPostfix
    dlg:modify { id = id, value = val }
end

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "channel",
    label = "Channel:",
    options = channels,
    option = defaults.channel,
    onchange = function()
        local args = dlg.data
        local channel = args.channel --[[@as string]]
        local bools = {
            channel == "L",
            channel == "A",
            channel == "B",
            channel == "Alpha"
        }

        local i = 0
        while i < lenIdPrefixes do
            i = i + 1
            local idPrefix = idPrefixes[i]
            local bool = bools[i]

            local j = 0
            while j < lenIdPostfixes do
                j = j + 1
                local idPostfix = idPostfixes[j]
                dlg:modify {
                    id = idPrefix .. idPostfix,
                    visible = bool
                }
            end
        end

        dlg:modify {
            id = "useRelative",
            visible = bools[2] or bools[3]
        }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "useRelative",
    label = "Bounds:",
    text = "Relative",
    selected = defaults.useRelative,
    visible = defaults.channel == "A"
        or defaults.channel == "B"
}

dlg:newrow { always = false }

dlg:button {
    id = "selGetLbIn",
    label = "Get:",
    text = "BLAC&K",
    focus = false,
    onclick = function()
        setInputFromColor(idPostfixes[1])
    end
}

dlg:button {
    id = "selGetUbIn",
    text = "&WHITE",
    focus = false,
    onclick = function()
        setInputFromColor(idPostfixes[2])
    end
}

dlg:newrow { always = false }

local i = 0
while i < lenIdPrefixes do
    i = i + 1
    local idPrefix = idPrefixes[i]
    local channelPreset = channels[i]
    local isVisible = defaults.channel == channelPreset

    local j = 0
    while j < lenIdSliders do
        local isEven = j % 2 ~= 1
        local label = nil
        local value = 255
        if isEven then
            label = labelSliders[1 + j // 2]
            value = 0
        end

        j = j + 1
        local idSlider = idSliders[j]
        dlg:slider {
            id = idPrefix .. idSlider,
            label = label,
            min = 0,
            max = 255,
            value = value,
            visible = isVisible
        }

        if not isEven then
            dlg:newrow { always = false }
        end
    end

    dlg:number {
        id = idPrefix .. idPostfixes[5],
        label = "Midpoint:",
        text = string.format("%.5f", 1.0),
        decimals = 5,
        visible = isVisible
    }

    dlg:newrow { always = false }
end

dlg:check {
    id = "printElapsed",
    label = "Print:",
    text = "Diagnostic",
    selected = defaults.printElapsed,
    visible = false
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        -- This is consistent with dialogs like gradientMap,
        -- but not with colorAdjust, which has the option
        -- to create a new layer from selection, and which
        -- does auto color mode convert.

        -- Begin timing the function elapsed.
        local args = dlg.data
        local printElapsed = args.printElapsed --[[@as boolean]]
        local startTime = 0
        local endTime = 0
        local elapsed = 0
        if printElapsed then
            startTime = os.clock()
        end

        -- Early returns.
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local activeSpec = activeSprite.spec
        local colorMode = activeSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local srcLayer = site.layer
        if not srcLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
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

        if srcLayer.isReference then
            app.alert {
                title = "Error",
                text = "Reference layers are not supported."
            }
            return
        end

        -- Get frames from target.
        local target = args.target or defaults.target --[[@as string]]
        local frames = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        -- Check for tile maps.
        local isTilemap = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset --[[@as Tileset]]
        end

        -- Create target layer.
        -- Do not copy source layer blend mode.
        local trgLayer = nil
        app.transaction("New Layer", function()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            trgLayer = activeSprite:newLayer()
            trgLayer.parent = srcLayer.parent
            trgLayer.name = string.format(
                "%s.Levels", srcLayerName)
        end)

        -- Cache methods.
        local strfmt = string.format
        local tilesToImage = AseUtilities.tilesToImage
        local transact = app.transaction
        local labTosRgb = Clr.srLab2TosRgb
        local toHex = Clr.toHex

        ---@type number[][]
        local remapParams = { {} }

        local h = 0
        while h < lenIdPrefixes do
            h = h + 1

            ---@type number[]
            local channelParams = {}
            local idPrefix = idPrefixes[h]

            local j = 0
            while j < lenIdPostfixes do
                j = j + 1
                local idPostfix = idPostfixes[j]
                local id = idPrefix .. idPostfix
                local value = args[id] --[[@as number]]
                channelParams[j] = value
            end

            remapParams[h] = channelParams
        end

        local lParams = remapParams[1]
        local aParams = remapParams[2]
        local bParams = remapParams[3]
        local tParams = remapParams[4]

        local lgVrf = 1.0 / math.max(0.000001, math.abs(lParams[5]))
        local agVrf = 1.0 / math.max(0.000001, math.abs(aParams[5]))
        local bgVrf = 1.0 / math.max(0.000001, math.abs(bParams[5]))
        local tgVrf = 1.0 / math.max(0.000001, math.abs(tParams[5]))

        local lGamma = function(x) return x ^ lgVrf end
        local aGamma = function(x) return x ^ agVrf end
        local bGamma = function(x) return x ^ bgVrf end
        local tGamma = function(x) return x ^ tgVrf end

        local useRelative = args.useRelative --[[@as boolean]]
        local aAbsMin = defaults.aAbsMin
        local aAbsMax = -defaults.aAbsMin
        local aAbsRange = aAbsMax - aAbsMin
        local aAbsDenom = 1.0 / aAbsRange

        local bAbsMin = defaults.bAbsMin
        local bAbsMax = -defaults.bAbsMin
        local bAbsRange = bAbsMax - bAbsMin
        local bAbsDenom = 1.0 / bAbsRange

        local lenFrames = #frames
        local k = 0
        while k < lenFrames do
            k = k + 1
            local srcFrame = frames[k]
            local srcCel = srcLayer:cel(srcFrame)
            if srcCel then
                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, colorMode)
                end

                local aMin = aAbsMin
                local aMax = aAbsMax
                local aRange = aAbsRange
                local aViable = true
                local aDenom = aAbsDenom

                local bMin = bAbsMin
                local bMax = bAbsMax
                local bRange = bAbsRange
                local bViable = true
                local bDenom = bAbsDenom

                local hexToLabDict = {}
                if useRelative then
                    hexToLabDict, aMin, aMax, bMin, bMax = auditImage(srcImg)
                    aRange = aMax - aMin
                    aViable = aRange > 0.5
                    aDenom = 0.0
                    if aViable then aDenom = 1.0 / aRange end

                    bRange = bMax - bMin
                    bViable = bRange > 0.5
                    bDenom = 0.0
                    if bViable then bDenom = 1.0 / bRange end
                else
                    hexToLabDict, _, _, _, _ = auditImage(srcImg)
                end

                ---@type table<integer, integer>
                local srcToTrgDict = {}
                for hex, lab in pairs(hexToLabDict) do
                    -- Lightness.
                    local lTrg = lab.l
                    local lx = lab.l * 0.01
                    local ly = remapChannel(lx,
                        lParams[1] / 255.0, lParams[2] / 255.0,
                        lParams[3] / 255.0, lParams[4] / 255.0,
                        lGamma)
                    lTrg = ly * 100.0

                    -- A (green to magenta).
                    local aTrg = lab.a
                    if aViable then
                        local ax = (lab.a - aMin) * aDenom
                        local ay = remapChannel(ax,
                            aParams[1] / 255.0, aParams[2] / 255.0,
                            aParams[3] / 255.0, aParams[4] / 255.0,
                            aGamma)
                        aTrg = ay * aRange + aMin
                    end

                    -- B (blue to yellow).
                    local bTrg = lab.b
                    if bViable then
                        local bx = (lab.b - bMin) * bDenom
                        local by = remapChannel(bx,
                            bParams[1] / 255.0, bParams[2] / 255.0,
                            bParams[3] / 255.0, bParams[4] / 255.0,
                            bGamma)
                        bTrg = by * bRange + bMin
                    end

                    -- Transparency.
                    local tTrg = lab.alpha
                    local tx = lab.alpha
                    local ty = remapChannel(tx,
                        tParams[1] / 255.0, tParams[2] / 255.0,
                        tParams[3] / 255.0, tParams[4] / 255.0,
                        tGamma)
                    tTrg = ty

                    local clrTrg = labTosRgb(lTrg, aTrg, bTrg, tTrg)
                    srcToTrgDict[hex] = toHex(clrTrg)
                end

                local trgImg = srcImg:clone()
                local trgPxItr = trgImg:pixels()
                for trgPixel in trgPxItr do
                    trgPixel(srcToTrgDict[trgPixel()])
                end

                transact(
                    strfmt("Levels Adjust %d", srcFrame),
                    function()
                        local trgCel = activeSprite:newCel(
                            trgLayer, srcFrame, trgImg, srcCel.position)
                        trgCel.opacity = srcCel.opacity
                    end)
            end
        end

        app.refresh()

        if printElapsed then
            endTime = os.clock()
            elapsed = endTime - startTime
            app.alert {
                title = "Diagnostic",
                text = {
                    string.format("Start: %.2f", startTime),
                    string.format("End: %.2f", endTime),
                    string.format("Elapsed: %.6f", elapsed)
                }
            }
        end
    end
}

dlg:button {
    id = "reset",
    text = "&RESET",
    focus = false,
    onclick = function()
        local j = 0
        while j < lenIdPrefixes do
            j = j + 1
            local idPrefix = idPrefixes[j]

            local k = 0
            while k < lenIdSliders do
                local isEven = k % 2 ~= 1
                local value = 255
                if isEven then value = 0 end

                k = k + 1
                local idSlider = idSliders[k]

                dlg:modify {
                    id = idPrefix .. idSlider,
                    value = value
                }
            end

            dlg:modify {
                id = idPrefix .. idPostfixes[5],
                text = string.format("%.5f", 1.0)
            }
        end
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
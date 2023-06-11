dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }
local channels = { "L", "A", "B", "Alpha" }

local idPrefixes = {
    "lCurve",
    "aCurve",
    "bCurve",
    "tCurve"
}
local lenIdPrefixes = #idPrefixes

local coPostfixes = {
    [1] = "ap0x",
    [2] = "ap0y",
    [3] = "cp0x",
    [4] = "cp0y",
    [5] = "cp1x",
    [6] = "cp1y",
    [7] = "ap1x",
    [8] = "ap1y",
}
local lenCoPostfixes = #coPostfixes

local screenScale = app.preferences.general.screen_scale
local curveColor = app.theme.color.text
local gridColor = Color { r = 128, g = 128, b = 128 }

local defaults = {
    target = "ACTIVE",
    channel = "L",
    printElapsed = false,
    alpSampleCount = 256
}

local dlg = Dialog { title = "Color Curves" }

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

---@param coPostfix string
local function setInputFromColor(coPostfix)
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
        val = lab.l * 0.01
    elseif channel == "A" then
        idPrefix = idPrefixes[2]
        val = (lab.a + 111.0) / 222.0
    elseif channel == "B" then
        idPrefix = idPrefixes[3]
        val = (lab.b + 111.0) / 222.0
    elseif channel == "Alpha" then
        idPrefix = idPrefixes[4]
        val = lab.alpha
    end

    local id = idPrefix .. "_" .. coPostfix
    dlg:modify { id = id, text = string.format("%.5f", val) }
    dlg:repaint()
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
            while j < lenCoPostfixes do
                j = j + 1
                local coPostfix = coPostfixes[j]
                local id = idPrefix .. "_" .. coPostfix
                dlg:modify { id = id, visible = bool }
            end

            dlg:modify { id = idPrefix, visible = bool }
            dlg:modify { id = idPrefix .. "_easeFuncs", visible = bool }
            dlg:modify { id = idPrefix .. "_flipv", visible = bool }
            dlg:modify { id = idPrefix .. "_straight", visible = bool }
            dlg:modify { id = idPrefix .. "_parallel", visible = bool }
        end
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "selGetLbIn",
    label = "Get:",
    text = "BLAC&K",
    focus = false,
    onclick = function()
        setInputFromColor(coPostfixes[1])
    end
}

dlg:button {
    id = "selGetUbIn",
    text = "&WHITE",
    focus = false,
    onclick = function()
        setInputFromColor(coPostfixes[7])
    end
}

dlg:newrow { always = false }

dlg:newrow { always = false }

local h = 0
while h < lenIdPrefixes do
    h = h + 1
    local currChannel = channels[h]
    CanvasUtilities.graphBezier(
        dlg,
        idPrefixes[h],
        currChannel .. ":",
        128 // screenScale,
        128 // screenScale,
        defaults.channel == currChannel,
        true, true, true, true,
        5, 0.33333, 0.33333, 0.66667, 0.66667,
        curveColor, gridColor)
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
                "%s.Curves", srcLayerName)
        end)

        ---@type Vec2[][]
        local curveSamples = {}
        local alpSampleCount = defaults.alpSampleCount
        local samplesCompare = function(a, b) return a < b.x end

        local i = 0
        while i < lenIdPrefixes do
            i = i + 1
            local idPrefix = idPrefixes[i]

            ---@type number[]
            local nums = {}
            local j = 0
            while j < lenCoPostfixes do
                j = j + 1
                local coPostfix = coPostfixes[j]
                local id = idPrefix .. "_" .. coPostfix
                local num = args[id] --[[@as number]]
                nums[j] = num
            end

            local co0 = Vec2.new(nums[1], nums[2])
            local fh0 = Vec2.new(nums[3], nums[4])
            local rh0 = Vec2.new(0.0, co0.y)

            local co1 = Vec2.new(nums[7], nums[8])
            local fh1 = Vec2.new(1.0, co1.y)
            local rh1 = Vec2.new(nums[5], nums[6])

            local kn0 = Knot2.new(co0, fh0, rh0)
            local kn1 = Knot2.new(co1, fh1, rh1)
            -- kn0:mirrorHandlesForward()
            -- kn1:mirrorHandlesBackward()

            local curve = Curve2.new(false, { kn0, kn1 }, idPrefix)

            local totalLength, arcLengths = Curve2.arcLength(
                curve, alpSampleCount)
            local paramPoints = Curve2.paramPoints(
                curve, totalLength, arcLengths, alpSampleCount)
            curveSamples[i] = paramPoints

            -- local strs = {}
            -- for n, v in ipairs(paramPoints) do
            --     strs[n] = n .. ": " .. Vec2.toJson(v)
            -- end
            -- print(table.concat(strs, ",\n"))
        end
        -- Cache methods.
        local strfmt = string.format
        local tilesToImage = AseUtilities.tilesToImage
        local transact = app.transaction
        local labTosRgb = Clr.srLab2TosRgb
        local toHex = Clr.toHex
        local bisectRight = Utilities.bisectRight
        local min = math.min
        local max = math.max

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

                local hexToLabDict, aMin, aMax, bMin, bMax = auditImage(srcImg)

                local aRange = aMax - aMin
                local aViable = aRange ~= 0.0
                local aDenom = 0.0
                if aViable then aDenom = 1.0 / aRange end

                local bRange = bMax - bMin
                local bViable = bRange ~= 0.0
                local bDenom = 0.0
                if bViable then bDenom = 1.0 / bRange end

                ---@type table<integer, integer>
                local srcToTrgDict = {}
                for hex, lab in pairs(hexToLabDict) do
                    -- Lightness.
                    local lTrg = lab.l
                    local lx = lab.l * 0.01
                    local lSamples = curveSamples[1]
                    local li = bisectRight(
                        lSamples, lx, samplesCompare)
                    li = min(max(li, 1), alpSampleCount)
                    local ly = lSamples[li].y
                    lTrg = ly * 100.0


                    -- A (green to magenta).
                    local aTrg = lab.a
                    if aViable then
                        local ax = (lab.a - aMin) * aDenom
                        local aSamples = curveSamples[2]
                        local ai = bisectRight(
                            aSamples, ax, samplesCompare)
                        ai = min(max(ai, 1), alpSampleCount)
                        local ay = aSamples[ai].y
                        aTrg = ay * aRange + aMin
                    end

                    -- B (blue to yellow).
                    local bTrg = lab.b
                    if bViable then
                        local bx = (lab.b - bMin) * bDenom
                        local bSamples = curveSamples[3]
                        local bi = bisectRight(
                            bSamples, bx, samplesCompare)
                        bi = min(max(bi, 1), alpSampleCount)
                        local by = bSamples[bi].y
                        bTrg = by * bRange + bMin
                    end

                    -- Transparency.
                    local tTrg = lab.alpha
                    local tx = lab.alpha
                    local tSamples = curveSamples[4]
                    local ti = bisectRight(
                        tSamples, tx, samplesCompare)
                    ti = min(max(ti, 1), alpSampleCount)
                    local ty = tSamples[ti].y
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
        local init = {
            0.0, 0.0,
            0.33333, 0.33333,
            0.66667, 0.66667,
            1.0, 1.0
        }
        local strfmt = string.format

        local i = 0
        while i < lenIdPrefixes do
            i = i + 1
            local idPrefix = idPrefixes[i]

            local j = 0
            while j < lenCoPostfixes do
                j = j + 1
                local coPostfix = coPostfixes[j]
                local id = idPrefix .. "_" .. coPostfix
                dlg:modify { id = id, text = strfmt("%.5f", init[j]) }
            end
        end
        dlg:repaint()
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
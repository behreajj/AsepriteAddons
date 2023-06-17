dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }
local methods = { "SIGNED", "UNSIGNED" }
local units = { "BITS", "INTEGERS" }
local levelsInputs = { "NON_UNIFORM", "UNIFORM" }

local defaults = {
    -- TODO: Option to quantize lightness, maybe LAB.
    minLevels = 2,
    maxLevels = 256,
    minBits = 1,
    maxBits = 8,
    target = "ACTIVE",
    levelsUni = 16,
    rLevels = 16,
    gLevels = 16,
    bLevels = 16,
    aLevels = 256,
    bitsUni = 4,
    rBits = 4,
    gBits = 4,
    bBits = 4,
    aBits = 8,
    unit = "BITS",
    levelsInput = "UNIFORM",
    method = "UNSIGNED",
    pullFocus = false
}

local dlg = Dialog { title = "Quantize RGB" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "method",
    label = "Method:",
    option = defaults.method,
    options = methods
}

dlg:newrow { always = false }

dlg:combobox {
    id = "levelsInput",
    label = "Channels:",
    option = defaults.levelsInput,
    options = levelsInputs,
    onchange = function()
        local args = dlg.data

        local md = args.levelsInput --[[@as string]]
        local isu = md == "UNIFORM"
        local isnu = md == "NON_UNIFORM"

        local unit = args.unitsInput --[[@as string]]
        local isbit = unit == "BITS"
        local isint = unit == "INTEGERS"

        dlg:modify { id = "rBits", visible = isnu and isbit }
        dlg:modify { id = "gBits", visible = isnu and isbit }
        dlg:modify { id = "bBits", visible = isnu and isbit }
        dlg:modify { id = "aBits", visible = isnu and isbit }
        dlg:modify {
            id = "bitsUni",
            visible = isu and isbit
        }

        dlg:modify { id = "rLevels", visible = isnu and isint }
        dlg:modify { id = "gLevels", visible = isnu and isint }
        dlg:modify { id = "bLevels", visible = isnu and isint }
        dlg:modify { id = "aLevels", visible = isnu and isint }
        dlg:modify {
            id = "levelsUni",
            visible = isu and isint
        }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "levelsUni",
    label = "Levels:",
    min = defaults.minLevels,
    max = defaults.maxLevels,
    value = defaults.levelsUni,
    visible = defaults.levelsInput == "UNIFORM"
        and defaults.unit == "INTEGERS",
    onchange = function()
        local args = dlg.data
        local uni = args.levelsUni --[[@as integer]]
        dlg:modify { id = "rLevels", value = uni }
        dlg:modify { id = "gLevels", value = uni }
        dlg:modify { id = "bLevels", value = uni }
        dlg:modify { id = "aLevels", value = uni }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "rLevels",
    label = "Red:",
    min = defaults.minLevels,
    max = defaults.maxLevels,
    value = defaults.rLevels,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "INTEGERS"
}

dlg:slider {
    id = "gLevels",
    label = "Green:",
    min = defaults.minLevels,
    max = defaults.maxLevels,
    value = defaults.gLevels,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "INTEGERS"
}

dlg:slider {
    id = "bLevels",
    label = "Blue:",
    min = defaults.minLevels,
    max = defaults.maxLevels,
    value = defaults.bLevels,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "INTEGERS"
}

dlg:slider {
    id = "aLevels",
    label = "Alpha:",
    min = defaults.minLevels,
    max = defaults.maxLevels,
    value = defaults.aLevels,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "INTEGERS"
}

dlg:newrow { always = false }

dlg:slider {
    id = "bitsUni",
    label = "Bits:",
    min = defaults.minBits,
    max = defaults.maxBits,
    value = defaults.bitsUni,
    visible = defaults.levelsInput == "UNIFORM"
        and defaults.unit == "BITS",
    onchange = function()
        local args = dlg.data
        local bd = args.bitsUni --[[@as integer]]
        dlg:modify { id = "rBits", value = bd }
        dlg:modify { id = "gBits", value = bd }
        dlg:modify { id = "bBits", value = bd }
        dlg:modify { id = "aBits", value = bd }

        local lv = 1 << bd
        dlg:modify { id = "levelsUni", value = lv }
        dlg:modify { id = "rLevels", value = lv }
        dlg:modify { id = "gLevels", value = lv }
        dlg:modify { id = "bLevels", value = lv }
        dlg:modify { id = "aLevels", value = lv }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "rBits",
    label = "Red:",
    min = defaults.minBits,
    max = defaults.maxBits,
    value = defaults.rBits,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "BITS",
    onchange = function()
        local args = dlg.data
        local rBits = args.rBits --[[@as integer]]
        local lv = 1 << rBits
        dlg:modify { id = "rLevels", value = lv }
    end
}

dlg:slider {
    id = "gBits",
    label = "Green:",
    min = defaults.minBits,
    max = defaults.maxBits,
    value = defaults.gBits,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "BITS",
    onchange = function()
        local args = dlg.data
        local gBits = args.gBits --[[@as integer]]
        local lv = 1 << gBits
        dlg:modify { id = "gLevels", value = lv }
    end
}

dlg:slider {
    id = "bBits",
    label = "Blue:",
    min = defaults.minBits,
    max = defaults.maxBits,
    value = defaults.bBits,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "BITS",
    onchange = function()
        local args = dlg.data
        local bBits = args.bBits --[[@as integer]]
        local lv = 1 << bBits
        dlg:modify { id = "bLevels", value = lv }
    end
}

dlg:slider {
    id = "aBits",
    label = "Alpha:",
    min = defaults.minBits,
    max = defaults.maxBits,
    value = defaults.aBits,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "BITS",
    onchange = function()
        local args = dlg.data
        local aBits = args.aBits --[[@as integer]]
        local lv = 1 << aBits
        dlg:modify { id = "aLevels", value = lv }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "unitsInput",
    label = "Units:",
    option = defaults.unit,
    options = units,
    onchange = function()
        local args = dlg.data

        local md = args.levelsInput --[[@as string]]
        local isnu = md == "NON_UNIFORM"
        local isu = md == "UNIFORM"

        local unit = args.unitsInput --[[@as string]]
        local isbit = unit == "BITS"
        local isint = unit == "INTEGERS"

        dlg:modify { id = "rBits", visible = isnu and isbit }
        dlg:modify { id = "gBits", visible = isnu and isbit }
        dlg:modify { id = "bBits", visible = isnu and isbit }
        dlg:modify { id = "aBits", visible = isnu and isbit }
        dlg:modify {
            id = "bitsUni",
            visible = isu and isbit
        }

        dlg:modify { id = "rLevels", visible = isnu and isint }
        dlg:modify { id = "gLevels", visible = isnu and isint }
        dlg:modify { id = "bLevels", visible = isnu and isint }
        dlg:modify { id = "aLevels", visible = isnu and isint }
        dlg:modify {
            id = "levelsUni",
            visible = isu and isint
        }
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
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

        local colorMode = activeSprite.colorMode
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

        -- Check for tile map support.
        local isTilemap = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset --[[@as Tileset]]
        end

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local method = args.method or defaults.method --[[@as string]]
        local rLevels = args.rLevels or defaults.rLevels --[[@as integer]]
        local gLevels = args.gLevels or defaults.gLevels --[[@as integer]]
        local bLevels = args.bLevels or defaults.bLevels --[[@as integer]]
        local aLevels = args.aLevels or defaults.aLevels --[[@as integer]]

        local frames = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        local trgLayer = nil
        app.transaction("New Layer", function()
            trgLayer = activeSprite:newLayer()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            trgLayer.name = string.format(
                "%s.Quantized.R%02d.G%02d.B%02d.A%02d",
                srcLayerName,
                rLevels, gLevels, bLevels, aLevels)
            trgLayer.parent = srcLayer.parent
            trgLayer.opacity = srcLayer.opacity
            trgLayer.blendMode = srcLayer.blendMode
        end)

        local rgbColorMode = ColorMode.RGB
        local floor = math.floor
        local tilesToImage = AseUtilities.tilesToImage
        local transact = app.transaction
        local strfmt = string.format

        local aDelta = 0.0
        local bDelta = 0.0
        local gDelta = 0.0
        local rDelta = 0.0

        local aqFunc = nil
        local bqFunc = nil
        local gqFunc = nil
        local rqFunc = nil

        if method == "UNSIGNED" then
            -- print("UNSIGNED")

            aqFunc = Utilities.quantizeUnsignedInternal
            bqFunc = Utilities.quantizeUnsignedInternal
            gqFunc = Utilities.quantizeUnsignedInternal
            rqFunc = Utilities.quantizeUnsignedInternal

            aDelta = 1.0 / (aLevels - 1.0)
            bDelta = 1.0 / (bLevels - 1.0)
            gDelta = 1.0 / (gLevels - 1.0)
            rDelta = 1.0 / (rLevels - 1.0)
        else
            -- print("SIGNED")

            aqFunc = Utilities.quantizeSignedInternal
            bqFunc = Utilities.quantizeSignedInternal
            gqFunc = Utilities.quantizeSignedInternal
            rqFunc = Utilities.quantizeSignedInternal

            aLevels = aLevels - 1
            bLevels = bLevels - 1
            gLevels = gLevels - 1
            rLevels = rLevels - 1

            aDelta = 1.0 / aLevels
            bDelta = 1.0 / bLevels
            gDelta = 1.0 / gLevels
            rDelta = 1.0 / rLevels
        end

        -- print(string.format(
        --     "aLevels: %d, bLevels: %d, gLevels: %d, rLevels: %d",
        --     aLevels, bLevels, gLevels, rLevels))

        -- print(string.format(
        --     "aDelta: %.3f, bDelta: %.3f, gDelta: %.3f, rDelta: %.3f",
        --     aDelta, bDelta, gDelta, rDelta))

        local i = 0
        local lenFrames = #frames
        while i < lenFrames do
            i = i + 1
            local srcFrame = frames[i]
            local srcCel = srcLayer:cel(srcFrame)
            if srcCel then
                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, rgbColorMode)
                end

                -- Gather unique colors in image.
                ---@type table<integer, boolean>
                local srcDict = {}
                local srcPxItr = srcImg:pixels()
                for pixel in srcPxItr do
                    srcDict[pixel()] = true
                end

                -- Quantize colors, place in dictionary.
                ---@type table<integer, integer>
                local trgDict = {}
                for k, _ in pairs(srcDict) do
                    local a = (k >> 0x18) & 0xff
                    local b = (k >> 0x10) & 0xff
                    local g = (k >> 0x08) & 0xff
                    local r = k & 0xff

                    -- Do not cache the division in a variable
                    -- as 1.0 / 255.0. It leads to precision errors
                    -- which impact alpha during unsigned quantize.
                    local aQtz = aqFunc(a / 255.0, aLevels, aDelta)
                    local bQtz = bqFunc(b / 255.0, bLevels, bDelta)
                    local gQtz = gqFunc(g / 255.0, gLevels, gDelta)
                    local rQtz = rqFunc(r / 255.0, rLevels, rDelta)

                    local a255 = floor(aQtz * 255.0 + 0.5)
                    local b255 = floor(bQtz * 255.0 + 0.5)
                    local g255 = floor(gQtz * 255.0 + 0.5)
                    local r255 = floor(rQtz * 255.0 + 0.5)

                    trgDict[k] = (a255 << 0x18)
                        | (b255 << 0x10)
                        | (g255 << 0x08)
                        |  r255
                end

                -- Clone image, replace color with quantized.
                local trgImg = srcImg:clone()
                local trgPxItr = trgImg:pixels()
                for pixel in trgPxItr do
                    pixel(trgDict[pixel()])
                end

                transact(
                    strfmt("Color Quantize %d", srcFrame),
                    function()
                        local trgCel = activeSprite:newCel(
                            trgLayer, srcFrame,
                            trgImg, srcCel.position)
                        trgCel.opacity = srcCel.opacity
                    end)
            end
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
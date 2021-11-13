dofile("../../support/aseutilities.lua")
dofile("../../support/gradientutilities.lua")

local insetInputs = { "NON_UNIFORM", "UNIFORM" }

local defaults = {
    columns = 8,
    aColor = Color(255, 0, 0, 255),
    bColor = Color(0, 162, 243, 255),
    xPivot = 0,
    yPivot = 0,
    lInset = 0,
    rInset = 0,
    tInset = 0,
    bInset = 0,
    uniInset = 0,
    insetInput = "UNIFORM",
    pullFocus = false
}

local dlg = Dialog { title = "Tileset To Slices" }

dlg:slider {
    id = "columns",
    label = "Columns:",
    min = 1,
    max = 32,
    value = defaults.columns
}

dlg:newrow { always = false }

dlg:color {
    id = "aColor",
    label = "Colors:",
    color = defaults.aColor
}

dlg:color {
    id = "bColor",
    color = defaults.bColor
}

dlg:newrow { always = false }

dlg:slider {
    id = "xPivot",
    label = "Pivot:",
    min = -100,
    max = 100,
    value = defaults.xPivot
}

dlg:slider {
    id = "yPivot",
    min = -100,
    max = 100,
    value = defaults.yPivot
}

dlg:separator {
    id = "insetSeparator",
    text = "Inset"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "insetInput",
    label = "Type:",
    option = defaults.insetInput,
    options = insetInputs,
    onchange = function()
        local md = dlg.data.insetInput
        local isnu = md == "NON_UNIFORM"

        dlg:modify { id = "lInset", visible = isnu }
        dlg:modify { id = "rInset", visible = isnu }
        dlg:modify { id = "bInset", visible = isnu }
        dlg:modify { id = "tInset", visible = isnu }
        dlg:modify {
            id = "uniInset",
            visible = not isnu
        }
    end
}

dlg:slider {
    id = "uniInset",
    label = "Amount:",
    min = 0,
    max = 32,
    value = defaults.uniInset,
    visible = defaults.insetInput == "UNIFORM",
    onchange = function()
        local uni = dlg.data.uniInset
        dlg:modify { id = "lInset", value = uni }
        dlg:modify { id = "rInset", value = uni }
        dlg:modify { id = "bInset", value = uni }
        dlg:modify { id = "tInset", value = uni }
    end
}

dlg:slider {
    id = "lInset",
    label = "Left:",
    min = 0,
    max = 32,
    value = defaults.lInset,
    visible = defaults.insetInput == "NON_UNIFORM"
}

dlg:newrow { always = false }

dlg:slider {
    id = "rInset",
    label = "Right:",
    min = 0,
    max = 32,
    value = defaults.rInset,
    visible = defaults.insetInput == "NON_UNIFORM"
}

dlg:newrow { always = false }

dlg:slider {
    id = "bInset",
    label = "Bottom:",
    min = 0,
    max = 32,
    value = defaults.bInset,
    visible = defaults.insetInput == "NON_UNIFORM"
}

dlg:newrow { always = false }

dlg:slider {
    id = "tInset",
    label = "Top:",
    min = 0,
    max = 32,
    value = defaults.tInset,
    visible = defaults.insetInput == "NON_UNIFORM"
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        -- TODO: Uniform vs. nonuniform inset adjustments.
        -- See rounded rectangle controls.

        local version = app.version
        if version.major < 1 or version.minor < 3 then
            app.alert("Version 1.3 or later is required to use tilemaps.")
            return
        end

        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert("There is no active sprite.")
            return
        end

        -- Unpack arguments.
        local args = dlg.data
        local columns = args.columns or defaults.columns

        local aColor = args.aColor or defaults.aColor
        local bColor = args.bColor or defaults.bColor

        local xPivot = args.xPivot or defaults.xPivot
        local yPivot = args.yPivot or defaults.yPivot

        -- TODO: Possible to switch back from nonuniform to uniform but not update the values.
        local lInset = args.lInset or defaults.lInset
        local rInset = args.rInset or defaults.rInset
        local bInset = args.bInset or defaults.bInset
        local tInset = args.tInset or defaults.tInset

        local insetInput = args.insetType or defaults.insetInput
        if insetInput == "UNIFORM" then
            local uniInset = args.uniInset or defaults.uniInset
            lInset = uniInset
            rInset = uniInset
            bInset = uniInset
            tInset = uniInset
        end

        -- Cache methods.
        local max = math.max
        local min = math.min
        local ceil = math.ceil
        local trunc = math.tointeger
        local strfmt = string.format
        local mixLch = Clr.mixLch
        local clrToAse = AseUtilities.clrToAseColor
        local hueFunc = GradientUtilities.lerpHueCcw

        -- Extract sprite properties.
        local colorMode = activeSprite.colorMode
        local alphaIndex = activeSprite.transparentColor
        local tilesets = activeSprite.tilesets
        local colorSpace = activeSprite.colorSpace
        local palHexes = AseUtilities.asePaletteToHexArr(
            activeSprite.palettes[1])

        local packets = {}
        local maxWidth = 0
        local sumHeight = 0
        local yCursor = 0
        local flatCount = 0
        local tilesetsLen = #tilesets
        if tilesetsLen < 1 then
            app.alert("There are no tile sets in this sprite.")
            return
        end

        for i = 1, tilesetsLen, 1 do
            local tileset = tilesets[i]
            local grid = tileset.grid
            local tileName = tileset.name
            if not tileName or #tileName < 1 then
                tileName = strfmt("Tileset.%03d", i - 1)
            end

            local tileDim = grid.tileSize
            local tileWidth = tileDim.width
            local tileHeight = tileDim.height

            -- Need to remove empty tiles from the set.
            local tileCount = #tileset
            local imgs = {}
            local noGapIdx = 1
            for j = 0, tileCount - 1, 1 do
                local img = tileset:getTile(j)
                if not img:isEmpty() then
                    imgs[noGapIdx] = img
                    noGapIdx = noGapIdx + 1
                end
            end
            tileCount = #imgs

            local rows = max(1, ceil(tileCount / columns))
            local imgWidth = tileWidth * columns
            local imgHeight = tileHeight * rows
            local img = Image(imgWidth, imgHeight, colorMode)
            img.spec.transparentColor = alphaIndex

            local rects = {}
            for k = 0, tileCount - 1, 1 do
                local x = k % columns
                local y = k // columns
                local xScaled = x * tileWidth
                local yScaled = y * tileHeight
                local tile = imgs[1 + k]

                img:drawImage(tile, xScaled, yScaled)
                local rect = Rectangle(
                    xScaled, yScaled + yCursor,
                    tileWidth, tileHeight)
                rects[1 + k] = rect
                flatCount = flatCount + 1
            end

            local pos = Point(0, yCursor)
            local packet = {
                img = img,
                position = pos,
                rects = rects,
                tileName = tileName
            }
            packets[i] = packet

            maxWidth = max(maxWidth, imgWidth)
            sumHeight = sumHeight + imgHeight
            yCursor = yCursor + imgHeight
        end

        local sliceSprite = Sprite(maxWidth, sumHeight, colorMode)
        local sliceFrame = activeSprite.frames[1]

        -- Prepending causes a problem with indexed color mode.
        -- Utilities.prependMask(palHexes)
        sliceSprite:setPalette(
            AseUtilities.hexArrToAsePalette(
                palHexes))
        sliceSprite:assignColorSpace(colorSpace)
        sliceSprite.spec.transparentColor = alphaIndex

        local aClr = AseUtilities.aseColorToClr(aColor)
        local bClr = AseUtilities.aseColorToClr(bColor)
        local xPivFac = (xPivot * 0.01) * 0.5 + 0.5
        local yPivFac = (yPivot * 0.01) * 0.5 + 0.5

        app.transaction(function()
            local flatIdx = 0
            for i = 1, tilesetsLen, 1 do
                local packet = packets[i]
                local img = packet.img
                local pos = packet.position
                local rects = packet.rects
                local tileName = packet.tileName

                local layer = sliceSprite:newLayer()
                local layerName = tileName
                layer.name = layerName
                sliceSprite:newCel(layer, sliceFrame, img, pos)

                local rectsLen = #rects
                local toClrFac = 1.0 / (flatCount - 1.0)

                for j = 1, rectsLen, 1 do
                    local rect = rects[j]
                    local w = rect.width
                    local h = rect.height
                    local xInsetLimit = w // 2 - 1
                    local yInsetLimit = h // 2 - 1
                    local brx = w - 1
                    local bry = h - 1

                    local slice = sliceSprite:newSlice(rect)

                    slice.name = strfmt("%s.%03d", layerName, j - 1)

                    -- Center is the center rectangle of a 9-slice.
                    -- Rectangle is expressed in (x, y, w, h), so
                    -- top-left' is subtracted from bottom-right';
                    -- bottom-right' is found by subtracting the
                    -- inset from the original bottom-right.
                    local lVal = min(lInset, xInsetLimit)
                    local rVal = min(rInset, xInsetLimit)
                    local tVal = min(tInset, yInsetLimit)
                    local bVal = min(bInset, yInsetLimit)
                    slice.center = Rectangle(
                        lVal, tVal,
                        1 + ((brx - rVal) - lVal),
                        1 + ((bry - bVal) - tVal)
                    )

                    -- For even numbers, the center will round to
                    -- the bottom right corner. Because (brx, bry)
                    -- is (w - 1, h - 1), this seems sensible.
                    slice.pivot = Point(
                        trunc(0.5 + xPivFac * brx),
                        trunc(0.5 + yPivFac * bry))

                    local clrFac = flatIdx * toClrFac
                    local cClr = mixLch(aClr, bClr, clrFac, hueFunc);
                    local cColor = clrToAse(cClr)
                    slice.color = cColor

                    flatIdx = flatIdx + 1
                end
            end

            sliceSprite:deleteLayer(sliceSprite.layers[1])
        end)

        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
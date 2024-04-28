dofile("../../support/gradientutilities.lua")

local palTypes <const> = { "ACTIVE", "FILE" }
local ditherTypes <const> = { "CHECKER", "CUSTOM" }

local defaults <const> = {
    palType = "ACTIVE",
    startIndex = 0,
    count = 256,
    swatchSize = 8,
    padding = 1,
    border = 3,
    useHighlight = false,
    minHighlight = 15,
    maxHighlight = 50,
    highColor = 0x80d5f7ff,
    bkgColor = 0xff101010,
    ditherType = "CHECKER",
    matrix = {
        0.0, 1.0,
        1.0, 0.0
    },
    mw = 2,
    mh = 2
}

local dlg <const> = Dialog { title = "Palette Dither Mix" }

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = defaults.palType,
    options = palTypes,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.palType --[[@as string]]
        dlg:modify {
            id = "palFile",
            visible = state == "FILE"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = { "aseprite", "gpl", "pal", "png", "webp" },
    open = true,
    visible = defaults.palType == "FILE"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "ditherType",
    label = "Dither:",
    option = defaults.ditherType,
    options = ditherTypes,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.ditherType --[[@as string]]
        dlg:modify {
            id = "ditherPath",
            visible = state == "CUSTOM"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "ditherPath",
    label = "File:",
    filetypes = AseUtilities.FILE_FORMATS_SAVE,
    open = true,
    focus = false,
    visible = defaults.ditherType == "CUSTOM"
}

dlg:newrow { always = false }

dlg:slider {
    id = "swatchSize",
    label = "Swatch:",
    min = 4,
    max = 32,
    value = defaults.swatchSize
}

dlg:newrow { always = false }

dlg:slider {
    id = "padding",
    label = "Padding:",
    min = 0,
    max = 32,
    value = defaults.padding
}

dlg:newrow { always = false }

dlg:slider {
    id = "border",
    label = "Border:",
    min = 0,
    max = 32,
    value = defaults.border
}

dlg:newrow { always = false }

dlg:check {
    id = "useHighlight",
    label = "Highlight:",
    text = "Contrast",
    selected = defaults.useHighlight,
    onclick = function()
        local args <const> = dlg.data
        local useHigh <const> = args.useHighlight --[[@as boolean]]
        dlg:modify { id = "highColor", visible = useHigh }
        dlg:modify { id = "minHighlight", visible = useHigh }
        dlg:modify { id = "maxHighlight", visible = useHigh }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "highColor",
    color = AseUtilities.hexToAseColor(defaults.highColor),
    visible = defaults.useHighlight
}

dlg:newrow { always = false }

dlg:slider {
    id = "minHighlight",
    label = "Threshold:",
    min = 0,
    max = 255,
    value = defaults.minHighlight,
    visible = defaults.useHighlight
}

dlg:slider {
    id = "maxHighlight",
    min = 0,
    max = 255,
    value = defaults.maxHighlight,
    visible = defaults.useHighlight
}

dlg:newrow { always = false }

dlg:color {
    id = "bkgColor",
    label = "Background:",
    color = AseUtilities.hexToAseColor(defaults.bkgColor)
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Unpack arguments.
        local args <const> = dlg.data
        local palType <const> = args.palType
            or defaults.palType --[[@as string]]
        local palFile <const> = args.palFile --[[@as string]]
        local ditherType <const> = args.ditherType
            or defaults.ditherType --[[@as string]]
        local swatchSize <const> = args.swatchSize
            or defaults.swatchSize --[[@as integer]]
        local padding <const> = args.padding
            or defaults.padding --[[@as integer]]
        local border <const> = args.border
            or defaults.border --[[@as integer]]
        local useHighlight <const> = args.useHighlight --[[@as boolean]]
        local minHighlight <const> = args.minHighlight
            or defaults.minHighlight --[[@as integer]]
        local maxHighlight <const> = args.maxHighlight
            or defaults.maxHighlight --[[@as integer]]
        local highColor <const> = args.highColor --[[@as Color]]
        local bkgColor <const> = args.bkgColor --[[@as Color]]

        local matrix = defaults.matrix
        local mw = defaults.mw
        local mh = defaults.mh

        if ditherType == "CUSTOM" then
            local ditherPath <const> = args.ditherPath --[[@as string]]
            if ditherPath and #ditherPath > 0
                and app.fs.isFile(ditherPath) then
                -- Disable asking about color profiles when loading these images.
                local oldAskProfile = 0
                local oldAskMissing = 0
                local appPrefs <const> = app.preferences
                if appPrefs then
                    local cmPrefs <const> = appPrefs.color
                    if cmPrefs then
                        oldAskProfile = cmPrefs.files_with_profile or 0 --[[@as integer]]
                        oldAskMissing = cmPrefs.missing_profile or 0 --[[@as integer]]

                        cmPrefs.files_with_profile = 0
                        cmPrefs.missing_profile = 0
                    end
                end

                local image <const> = Image { fromFile = ditherPath }

                if appPrefs then
                    local cmPrefs <const> = appPrefs.color
                    if cmPrefs then
                        cmPrefs.files_with_profile = oldAskProfile
                        cmPrefs.missing_profile = oldAskMissing
                    end
                end

                if image then
                    matrix, mw, mh = GradientUtilities.imageToMatrix(image)
                end
            end
        end

        -- Convert Color objects to hex
        local bkgHex <const> = AseUtilities.aseColorToHex(bkgColor, ColorMode.RGB)
        local highHex <const> = AseUtilities.aseColorToHex(highColor, ColorMode.RGB)

        -- Verify min and max highlight.
        local minHighVrf = minHighlight
        local maxHighVrf = maxHighlight
        if minHighlight > maxHighlight then
            minHighVrf = maxHighlight
            maxHighVrf = minHighlight
        end

        -- Get palette.
        local startIndex <const> = defaults.startIndex
        local count <const> = defaults.count
        local hexesProfile <const>, hexesSrgb <const> = AseUtilities.asePaletteLoad(
            palType, palFile, startIndex, count)

        -- Create profile.
        -- This should be done BEFORE the sprite is
        -- created, while the reference sprite is active.
        local activeSprite <const> = app.site.sprite
        local clrPrf = nil
        if palType == "ACTIVE" and activeSprite then
            clrPrf = activeSprite.colorSpace
            if clrPrf == nil then
                clrPrf = ColorSpace()
            end
        else
            clrPrf = ColorSpace { sRGB = true }
        end

        -- Only include mixed colors if color space is SRGB.
        local useMix <const> = clrPrf == ColorSpace { sRGB = true }
        local paddingGtEq1 <const> = padding >= 1

        ---@type table<integer, { l: number, a: number, b: number, alpha: number }>
        local hexLabDict <const> = {}

        ---@type table<integer, string>
        local hexWebDict <const> = {}

        ---@type integer[]
        local uniqueHexes <const> = {}
        local lenUniqueHexes = 0
        local lenHexesProfile <const> = #hexesProfile
        local g = 0
        while g < lenHexesProfile do
            g = g + 1
            local hexProfile <const> = hexesProfile[g]
            -- It may be advantageous to create a brush from a swatch which
            -- includes alpha.
            -- if (hexProfile & 0xff000000) ~= 0x0 then
            if not hexLabDict[hexProfile] then
                lenUniqueHexes = lenUniqueHexes + 1
                uniqueHexes[lenUniqueHexes] = hexProfile

                local hexSrgb <const> = hexesSrgb[g]
                local clr <const> = Clr.fromHex(hexSrgb)
                local lab <const> = Clr.sRgbToSrLab2(clr)
                hexLabDict[hexProfile] = lab
                hexWebDict[hexProfile] = Clr.toHexWeb(clr)
            end
            -- end
        end

        -- Create sprite.
        local spriteSize <const> = border * 2
            + swatchSize * (lenUniqueHexes + 1)
            + padding * lenUniqueHexes
        local spriteSpec <const> = AseUtilities.createSpec(
            spriteSize, spriteSize, ColorMode.RGB, clrPrf, 0)
        local comboSprite <const> = AseUtilities.createSprite(
            spriteSpec, "Dither Mix")
        local firstFrame <const> = comboSprite.frames[1]

        app.transaction("Set Grid", function()
            -- To set color, see
            -- https://github.com/aseprite/aseprite/blob/main/data/pref.xml#L511
            comboSprite.gridBounds = Rectangle(
                border, border,
                swatchSize + padding, swatchSize + padding)
        end)

        app.transaction("Set Background", function()
            local bkgLayer <const> = comboSprite.layers[1]
            bkgLayer.name = "Bkg"

            local bkgImg <const> = Image(spriteSpec)
            bkgImg:clear(bkgHex)
            comboSprite:newCel(
                bkgLayer, firstFrame,
                bkgImg, Point(0, 0))
        end)

        local headersGroup <const> = comboSprite:newGroup()
        local rowsGroup <const> = comboSprite:newGroup()
        local colsGroup <const> = comboSprite:newGroup()
        local swatchesGroup <const> = comboSprite:newGroup()
        local dithersGroup <const> = comboSprite:newGroup()
        local mixesGroup <const> = useMix
            and comboSprite:newGroup() or nil
        local highsGroup <const> = (useHighlight and paddingGtEq1)
            and comboSprite:newGroup() or nil

        app.transaction("Set Layer Props", function()
            headersGroup.name = "Headers"
            headersGroup.isCollapsed = true

            rowsGroup.name = "Rows"
            rowsGroup.parent = headersGroup
            rowsGroup.isCollapsed = true

            colsGroup.name = "Columns"
            colsGroup.parent = headersGroup
            colsGroup.isCollapsed = true

            swatchesGroup.name = "Swatches"
            swatchesGroup.isCollapsed = true

            dithersGroup.name = "Dithered"
            dithersGroup.parent = swatchesGroup
            dithersGroup.isCollapsed = true

            if mixesGroup then
                mixesGroup.name = "Mixed"
                mixesGroup.parent = swatchesGroup
                mixesGroup.isCollapsed = true
            end

            if highsGroup then
                highsGroup.name = "Highlights"
                -- highsGroup.parent = dithersGroup
                highsGroup.isCollapsed = true
            end
        end)

        local swatchSpec <const> = AseUtilities.createSpec(
            swatchSize, swatchSize, ColorMode.RGB, clrPrf, 0)

        -- Cache methods used in loop
        local abs <const> = math.abs
        local sqrt <const> = math.sqrt
        local strfmt <const> = string.format
        local clrToAseColor <const> = AseUtilities.clrToAseColor
        local srLab2TosRgb <const> = Clr.srLab2TosRgb
        local toHex <const> = Clr.toHex
        local hexToAseColor <const> = AseUtilities.hexToAseColor
        local strpack <const> = string.pack

        local highlightFrame = nil
        local frameWeight = 1
        if useHighlight and paddingGtEq1 then
            -- For some reason, the pixel iterator approach stopped working.
            local highStr <const> = strpack("B B B B",
                highColor.red,
                highColor.green,
                highColor.blue,
                highColor.alpha)
            local zeroStr <const> = strpack("B B B B", 0, 0, 0, 0)

            local wHigh <const> = swatchSize + frameWeight * 2
            local hHigh <const> = swatchSize + frameWeight * 2
            local highFrameSpec <const> = AseUtilities.createSpec(
                wHigh, hHigh, ColorMode.RGB, clrPrf, 0)
            highlightFrame = Image(highFrameSpec)

            ---@type string[]
            local highBytes <const> = {}
            local horizStripWeight <const> = wHigh - frameWeight
            local vertStripWeight <const> = hHigh - frameWeight
            local horizStripArea <const> = frameWeight * horizStripWeight
            local vertStripArea <const> = frameWeight * vertStripWeight
            local swatchArea <const> = swatchSize * swatchSize

            -- Draw top and bottom horizontal strips.
            local i = 0
            while i < horizStripArea do
                local x <const> = i % horizStripWeight
                local y <const> = i // horizStripWeight

                local xTop <const> = x
                local yTop <const> = y
                local idxTop <const> = xTop + yTop * wHigh
                highBytes[1 + idxTop] = highStr

                local xBtm <const> = x + frameWeight
                local yBtm <const> = y + vertStripWeight
                local idxBtm <const> = xBtm + yBtm * wHigh
                highBytes[1 + idxBtm] = highStr

                i = i + 1
            end

            -- Draw left and right horizontal strips.
            local j = 0
            while j < vertStripArea do
                local x <const> = j % frameWeight
                local y <const> = j // frameWeight

                local xLft <const> = x
                local yLft <const> = y + frameWeight
                local idxLft <const> = xLft + yLft * wHigh
                highBytes[1 + idxLft] = highStr

                local xRgt <const> = x + horizStripWeight
                local yRgt <const> = y
                local idxRgt <const> = xRgt + yRgt * wHigh
                highBytes[1 + idxRgt] = highStr

                j = j + 1
            end

            -- Draw clear center.
            local k = 0
            while k < swatchArea do
                local x <const> = frameWeight + k % swatchSize
                local y <const> = frameWeight + k // swatchSize
                local idxCenter <const> = x + y * wHigh
                highBytes[1 + idxCenter] = zeroStr
                k = k + 1
            end

            highlightFrame.bytes = table.concat(highBytes)
        end

        local i = lenUniqueHexes + 1
        while i > 1 do
            i = i - 1
            local rowHex <const> = uniqueHexes[i]
            local rowLab <const> = hexLabDict[rowHex]
            local rowWebStr <const> = hexWebDict[rowHex]

            local y <const> = border + i * swatchSize + i * padding

            app.transaction("Create Headers", function()
                local refImage <const> = Image(swatchSpec)
                refImage:clear(rowHex)

                local leftHeader = nil
                leftHeader = comboSprite:newLayer()
                leftHeader.name = rowWebStr
                leftHeader.parent = rowsGroup

                comboSprite:newCel(
                    leftHeader,
                    firstFrame,
                    refImage,
                    Point(border, y))

                local topHeader = nil
                topHeader = comboSprite:newLayer()
                topHeader.name = rowWebStr
                topHeader.parent = colsGroup

                comboSprite:newCel(
                    topHeader,
                    firstFrame,
                    refImage,
                    Point(y, border))
            end)

            app.transaction("Create Swatches", function()
                local j = lenUniqueHexes + 1
                while j > 1 do
                    j = j - 1
                    local colHex <const> = uniqueHexes[j]
                    local colLab <const> = hexLabDict[colHex]
                    local colWebStr <const> = hexWebDict[colHex]

                    local x <const> = border + j * swatchSize + j * padding

                    if i < j then
                        -- Dither colors.
                        local ditherImage <const> = Image(swatchSpec)

                        -- TODO: Replace with string bytes approach?
                        local dithPxItr <const> = ditherImage:pixels()
                        for pixel in dithPxItr do
                            local xpx <const> = pixel.x
                            local ypx <const> = pixel.y
                            local midx <const> = 1 + (xpx % mw) + (ypx % mh) * mw
                            local hex = colHex
                            if 0.5 >= matrix[midx] then hex = rowHex end
                            pixel(hex)
                        end

                        -- Display distance as a metric for how high
                        -- contrast the dither is.
                        local da <const> = rowLab.a - colLab.a
                        local db <const> = rowLab.b - colLab.b
                        local dist <const> = sqrt(da * da + db * db)
                            + abs(rowLab.l - colLab.l)
                        local fitsHigh <const> = useHighlight
                            and dist >= minHighVrf
                            and dist <= maxHighVrf
                        local layerName <const> = strfmt(
                            "Dither %s %s %03d",
                            rowWebStr, colWebStr, dist)

                        local ditherLayer = nil
                        ditherLayer = comboSprite:newLayer()
                        ditherLayer.name = layerName
                        ditherLayer.parent = dithersGroup

                        local ditherCel <const> = comboSprite:newCel(
                            ditherLayer,
                            firstFrame,
                            ditherImage,
                            Point(x, y))

                        if fitsHigh then
                            ditherCel.color = hexToAseColor(highHex)

                            if paddingGtEq1 then
                                local highLayer = nil
                                highLayer = comboSprite:newLayer()
                                highLayer.name = layerName
                                if highsGroup then
                                    highLayer.parent = highsGroup
                                end

                                comboSprite:newCel(
                                    highLayer,
                                    firstFrame,
                                    highlightFrame,
                                    Point(x - frameWeight, y - frameWeight))
                            end
                        end
                    elseif useMix and i > j then
                        -- Mix colors.
                        local lMixed <const> = (rowLab.l + colLab.l) * 0.5
                        local aMixed <const> = (rowLab.a + colLab.a) * 0.5
                        local bMixed <const> = (rowLab.b + colLab.b) * 0.5
                        local tMixed <const> = (rowLab.alpha + colLab.alpha) * 0.5

                        local srgbMixed <const> = srLab2TosRgb(
                            lMixed, aMixed, bMixed, tMixed)
                        local hexMixed <const> = toHex(srgbMixed)

                        local mixImage <const> = Image(swatchSpec)
                        mixImage:clear(hexMixed)

                        local mixLayer = nil
                        mixLayer = comboSprite:newLayer()
                        mixLayer.name = strfmt(
                            "Mix %s %s",
                            rowWebStr, colWebStr)
                        if mixesGroup then
                            mixLayer.parent = mixesGroup
                        end

                        local mixedCel <const> = comboSprite:newCel(
                            mixLayer,
                            firstFrame,
                            mixImage,
                            Point(x, y))
                        mixedCel.color = clrToAseColor(srgbMixed)
                    end
                end
            end)
        end

        AseUtilities.setPalette(hexesProfile, comboSprite, 1)

        app.sprite = comboSprite
        app.frame = firstFrame
        app.layer = swatchesGroup

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
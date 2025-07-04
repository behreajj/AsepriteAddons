dofile("../../support/gradientutilities.lua")

local palTypes <const> = { "ACTIVE", "FILE", "PRESET" }
local ditherTypes <const> = { "CHECKER", "CUSTOM" }

local defaults <const> = {
    palType = "ACTIVE",
    palResource = "",
    startIndex = 0,
    count = 256,
    swatchSize = 8,
    padding = 1,
    border = 3,
    useComplHl = false,
    useContrastHl = false,
    minHighlight = 15,
    maxHighlight = 50,
    frameWeight = 1,
    highColor = 0x80d5f7ff,
    bkgColor = 0xff101010,
    ditherType = "CHECKER",
    matrix = {
        0.0, 1.0,
        1.0, 0.0
    },
    mw = 2,
    mh = 2,
    isComplLEpsilon = 5.0,
    isComplAbEpsilon = 7.0,
}

local dlg <const> = Dialog { title = "Palette Dither Mix " }

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = defaults.palType,
    options = palTypes,
    hexpand = false,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.palType --[[@as string]]
        dlg:modify {
            id = "palResource",
            visible = state == "PRESET"
        }
        dlg:modify {
            id = "palFile",
            visible = state == "FILE"
        }
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "palResource",
    text = defaults.palResource,
    visible = defaults.palType == "PRESET"
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = AseUtilities.FILE_FORMATS_PAL,
    basepath = app.fs.joinPath(app.fs.userConfigPath, "palettes"),
    visible = defaults.palType == "FILE"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "ditherType",
    label = "Dither:",
    option = defaults.ditherType,
    options = ditherTypes,
    hexpand = false,
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

    basepath = app.fs.userDocsPath,

    focus = false,
    visible = defaults.ditherType == "CUSTOM"
}

dlg:newrow { always = false }

dlg:slider {
    id = "swatchSize",
    label = "Swatch:",
    min = 4,
    max = 64,
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
    id = "useComplHl",
    label = "Highlight:",
    text = "Complement",
    selected = defaults.useComplHl,
    focus = false,
    hexpand = false,
    onclick = function()
        local args <const> = dlg.data
        local useComplHl <const> = args.useComplHl --[[@as boolean]]
        local useContrastHl <const> = args.useContrastHl --[[@as boolean]]
        dlg:modify { id = "highColor", visible = useComplHl or useContrastHl }
    end
}

dlg:check {
    id = "useContrastHl",
    text = "Contrast",
    selected = defaults.useContrastHl,
    focus = false,
    hexpand = false,
    onclick = function()
        local args <const> = dlg.data
        local useComplHl <const> = args.useComplHl --[[@as boolean]]
        local useContrastHl <const> = args.useContrastHl --[[@as boolean]]
        dlg:modify { id = "highColor", visible = useComplHl or useContrastHl }
        dlg:modify { id = "minHighlight", visible = useContrastHl }
        dlg:modify { id = "maxHighlight", visible = useContrastHl }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "highColor",
    color = AseUtilities.hexToAseColor(defaults.highColor),
    visible = defaults.useComplHl
        or defaults.useContrastHl
}

dlg:newrow { always = false }

dlg:slider {
    id = "minHighlight",
    label = "Threshold:",
    min = 0,
    max = 255,
    value = defaults.minHighlight,
    visible = defaults.useContrastHl
}

dlg:slider {
    id = "maxHighlight",
    min = 0,
    max = 255,
    value = defaults.maxHighlight,
    visible = defaults.useContrastHl
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
    focus = false,
    onclick = function()
        -- Unpack arguments.
        local args <const> = dlg.data
        local palType <const> = args.palType
            or defaults.palType --[[@as string]]
        local palResource <const> = args.palResource
            or defaults.palResource --[[@as string]]
        local palFile <const> = args.palFile --[[@as string]]
        local ditherType <const> = args.ditherType
            or defaults.ditherType --[[@as string]]
        local swatchSize <const> = args.swatchSize
            or defaults.swatchSize --[[@as integer]]
        local padding <const> = args.padding
            or defaults.padding --[[@as integer]]
        local border <const> = args.border
            or defaults.border --[[@as integer]]
        local useComplHl <const> = args.useComplHl --[[@as boolean]]
        local useContrastHl <const> = args.useContrastHl --[[@as boolean]]
        local minHighlight <const> = args.minHighlight
            or defaults.minHighlight --[[@as integer]]
        local maxHighlight <const> = args.maxHighlight
            or defaults.maxHighlight --[[@as integer]]
        local highColor <const> = args.highColor --[[@as Color]]
        local bkgColor <const> = args.bkgColor --[[@as Color]]

        local matrix = defaults.matrix
        local mw = defaults.mw
        local mh = defaults.mh

        local isComplLEpsilon <const> = defaults.isComplLEpsilon
        local isComplAbEpsilon <const> = defaults.isComplAbEpsilon

        if ditherType == "CUSTOM" then
            local ditherPath <const> = args.ditherPath --[[@as string]]
            if ditherPath and #ditherPath > 0
                and app.fs.isFile(ditherPath) then
                -- Disable color profile alerts when loading images.
                local oldAskProfile = 0
                local oldAskMissing = 0
                local appPrefs <const> = app.preferences
                if appPrefs then
                    local cmPrefs <const> = appPrefs.color
                    if cmPrefs then
                        oldAskProfile = cmPrefs.files_with_profile
                            or 0 --[[@as integer]]
                        oldAskMissing = cmPrefs.missing_profile
                            or 0 --[[@as integer]]

                        cmPrefs.files_with_profile = 0
                        cmPrefs.missing_profile = 0
                    end -- End color prefs exists.
                end     -- End app prefs exists.

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
            end -- End valid path string.
        end     -- End custom dither.

        -- Convert Color objects to hex
        local bkgHex <const> = AseUtilities.aseColorToHex(
            bkgColor, ColorMode.RGB)
        local highHex <const> = AseUtilities.aseColorToHex(
            highColor, ColorMode.RGB)

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
        local hexesProfile <const>,
        hexesSrgb <const> = AseUtilities.asePaletteLoad(
            palType, palFile, palResource, startIndex, count)

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
            or clrPrf == ColorSpace()
        local paddingGtEq1 <const> = padding >= 1

        -- Cache methods used in loop
        local abs <const> = math.abs
        local sqrt <const> = math.sqrt
        local strfmt <const> = string.format
        local strpack <const> = string.pack
        local tconcat <const> = table.concat
        local labTosRgb <const> = ColorUtilities.srLab2TosRgb
        local sRgbToLab <const> = ColorUtilities.sRgbToSrLab2Internal
        local labnew <const> = Lab.new
        local fromHex <const> = Rgb.fromHexAbgr32
        local toHex <const> = Rgb.toHex
        local toHexWeb <const> = Rgb.toHexWeb
        local clrToAseColor <const> = AseUtilities.rgbToAseColor
        local hexToAseColor <const> = AseUtilities.hexToAseColor

        ---@type table<integer, Lab>
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
                local clr <const> = fromHex(hexSrgb)
                local lab <const> = sRgbToLab(clr)
                hexLabDict[hexProfile] = lab
                hexWebDict[hexProfile] = toHexWeb(clr)
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
            spriteSpec, "Dither Mix", false)
        local firstFrame <const> = comboSprite.frames[1]

        app.transaction("Set Grid", function()
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
        local highsGroup <const> = ((useContrastHl or useComplHl)
                and paddingGtEq1)
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
                highsGroup.isCollapsed = true
            end
        end)

        local swatchSpec <const> = AseUtilities.createSpec(
            swatchSize, swatchSize, ColorMode.RGB, clrPrf, 0)
        local swatchArea <const> = swatchSize * swatchSize

        local highlightFrame = nil
        local frameWeight <const> = defaults.frameWeight
        if (useContrastHl or useComplHl) and paddingGtEq1 then
            local highStr <const> = strpack("<I4", highHex)
            local zeroStr <const> = strpack("<I4", 0)

            local szHigh <const> = swatchSize + frameWeight * 2
            local highFrameSpec <const> = AseUtilities.createSpec(
                szHigh, szHigh, ColorMode.RGB, clrPrf, 0)
            highlightFrame = Image(highFrameSpec)

            ---@type string[]
            local highlightBytes <const> = {}
            local stripWeight <const> = swatchSize + frameWeight
            local stripArea <const> = frameWeight * stripWeight

            -- Because swatches have the same width and height, horizontal
            -- and vertical borders can be drawn in one loop.
            local i = 0
            while i < stripArea do
                -- Horizontal.
                local xh <const> = i % stripWeight
                local yh <const> = i // stripWeight

                local xTop <const> = xh
                local yTop <const> = yh
                local idxTop <const> = xTop + yTop * szHigh
                highlightBytes[1 + idxTop] = highStr

                local xBtm <const> = xh + frameWeight
                local yBtm <const> = yh + stripWeight
                local idxBtm <const> = xBtm + yBtm * szHigh
                highlightBytes[1 + idxBtm] = highStr

                -- Vertical.
                local xv <const> = i % frameWeight
                local yv <const> = i // frameWeight

                local xLft <const> = xv
                local yLft <const> = yv + frameWeight
                local idxLft <const> = xLft + yLft * szHigh
                highlightBytes[1 + idxLft] = highStr

                local xRgt <const> = xv + stripWeight
                local yRgt <const> = yv
                local idxRgt <const> = xRgt + yRgt * szHigh
                highlightBytes[1 + idxRgt] = highStr

                i = i + 1
            end

            -- Draw clear center.
            local k = 0
            while k < swatchArea do
                local x <const> = frameWeight + k % swatchSize
                local y <const> = frameWeight + k // swatchSize
                local idxCenter <const> = y * szHigh + x
                highlightBytes[1 + idxCenter] = zeroStr
                k = k + 1
            end

            highlightFrame.bytes = tconcat(highlightBytes)
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

                local leftHeader <const> = comboSprite:newLayer()
                leftHeader.name = rowWebStr
                leftHeader.parent = rowsGroup

                comboSprite:newCel(
                    leftHeader,
                    firstFrame,
                    refImage,
                    Point(border, y))

                local topHeader <const> = comboSprite:newLayer()
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
                        ---@type string[]
                        local ditherByteArr <const> = {}
                        local n = 0
                        while n < swatchArea do
                            local xpx <const> = n % swatchSize
                            local ypx <const> = n // swatchSize
                            local midx <const> = 1 + (xpx % mw) + (ypx % mh) * mw
                            local hex <const> = 0.5 >= matrix[midx]
                                and rowHex or colHex
                            n = n + 1
                            ditherByteArr[n] = strpack("<I4", hex)
                        end
                        ditherImage.bytes = tconcat(ditherByteArr)

                        local dl <const> = rowLab.l - colLab.l
                        local da <const> = rowLab.a - colLab.a
                        local db <const> = rowLab.b - colLab.b

                        local bothNonZero <const> = rowLab.alpha > 0.0
                            and colLab.alpha > 0.0
                        local fitsCompl <const> = useComplHl
                            and bothNonZero
                            and abs(dl) < isComplLEpsilon
                            and abs(rowLab.a + colLab.a) < isComplAbEpsilon
                            and abs(rowLab.b + colLab.b) < isComplAbEpsilon

                        -- Distance as a metric for dither contrast.
                        local dist <const> = sqrt(da * da + db * db)
                            + abs(dl)
                        local fitsHigh <const> = useContrastHl
                            and bothNonZero
                            and dist >= minHighVrf
                            and dist <= maxHighVrf

                        local layerName <const> = strfmt(
                            "Dither %s %s %03d",
                            rowWebStr, colWebStr, dist)

                        local ditherLayer <const> = comboSprite:newLayer()
                        ditherLayer.name = layerName
                        ditherLayer.parent = dithersGroup

                        local ditherCel <const> = comboSprite:newCel(
                            ditherLayer,
                            firstFrame,
                            ditherImage,
                            Point(x, y))

                        if fitsHigh or fitsCompl then
                            ditherCel.color = hexToAseColor(highHex)

                            if paddingGtEq1 then
                                local highLayer <const> = comboSprite:newLayer()
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
                        local srgbMixed <const> = labTosRgb(labnew(
                            (rowLab.l + colLab.l) * 0.5,
                            (rowLab.a + colLab.a) * 0.5,
                            (rowLab.b + colLab.b) * 0.5,
                            (rowLab.alpha + colLab.alpha) * 0.5))
                        local hexMixed <const> = toHex(srgbMixed)

                        local mixImage <const> = Image(swatchSpec)
                        mixImage:clear(hexMixed)

                        local mixLayer <const> = comboSprite:newLayer()
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
                    end -- Dither or mix check.
                end     -- Right unique hexes loop.
            end)        -- Create swatches transaction.
        end             -- Left Unique hexes loop.

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
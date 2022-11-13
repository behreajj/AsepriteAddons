dofile("../../support/aseutilities.lua")

-- New Sprite Plus doesn't support Color Space conversion
-- because setting color space via script interferes with
-- Aseprite's routine to ask the user what to do when
-- opening a sprite with a profile.
local colorModes = { "RGB", "INDEXED", "GRAY" }
local paletteTypes = { "ACTIVE", "DEFAULT", "FILE", "PRESET" }
local sizeModes = { "ASPECT", "CUSTOM" }

local defaults = {
    filename = "Sprite",

    sizeMode = "CUSTOM",
    width = 320,
    height = 180,
    aRatio = 16,
    bRatio = 9,
    aspectScale = 20,

    colorMode = "RGB",
    rChannel = 0,
    gChannel = 0,
    bChannel = 0,
    aChannel = 0,
    grayChannel = 0,
    bkgIdx = 0,
    linkRgbGray = true,

    frames = 1,
    fps = 12,

    palType = "ACTIVE",
    prependMask = true,

    xGrid = 0,
    yGrid = 0,
    wGrid = 20,
    hGrid = 20,
    pullFocus = true,

    maxSize = 65535
}

local function updateColorPreviewRgba(dialog)
    local args = dialog.data
    dialog:modify {
        id = "preview",
        colors = { Color(
            args.rChannel,
            args.gChannel,
            args.bChannel,
            args.aChannel) }
    }
end

local function updateColorPreviewGray(dialog)
    local args = dialog.data
    dialog:modify {
        id = "preview",
        colors = { Color {
            gray = args.grayChannel,
            alpha = args.aChannel
        } }
    }
end

local function rgbToGray(r8, g8, b8)
    -- HSL Lightness
    local mx = math.max(r8, g8, b8)
    local mn = math.min(r8, g8, b8)
    return math.floor(0.5 + 0.5 * (mx + mn))
end

local function updateGrayLinkFromRgb(dialog)
    local args = dialog.data
    local link = defaults.linkRgbGray
    if link then
        local v = rgbToGray(
            args.rChannel,
            args.gChannel,
            args.bChannel)
        dialog:modify { id = "grayChannel", value = v }
    end
end

local function updateRgbLinkFromGray(dialog)
    local args = dialog.data
    local link = defaults.linkRgbGray
    if link then
        local v = args.grayChannel
        dialog:modify { id = "bChannel", value = v }
        dialog:modify { id = "gChannel", value = v }
        dialog:modify { id = "rChannel", value = v }
    end
end

local function updateRatio(dialog)
    local args = dialog.data
    local aRatio = args.aRatio
    local bRatio = args.bRatio
    aRatio, bRatio = Utilities.reduceRatio(aRatio, bRatio)
    dialog:modify { id = "aRatio", value = aRatio }
    dialog:modify { id = "bRatio", value = bRatio }
end

local function updateSizeFromAspect(dialog)
    local args = dialog.data
    local aRatio = args.aRatio
    local bRatio = args.bRatio
    local scale = args.aspectScale

    scale = math.abs(scale)
    scale = math.floor(0.5 + scale)
    if scale < 1 then scale = 1 end

    aRatio, bRatio = Utilities.reduceRatio(aRatio, bRatio)
    local w = aRatio * scale
    local h = bRatio * scale

    dialog:modify { id = "width", text = string.format("%d", w) }
    dialog:modify { id = "height", text = string.format("%d", h) }
end

local dlg = Dialog { title = "New Sprite +" }

dlg:entry {
    id = "filename",
    label = "Name:",
    text = defaults.filename,
    focus = false
}

dlg:newrow { always = false }

dlg:combobox {
    id = "sizeMode",
    label = "Size:",
    option = defaults.sizeMode,
    options = sizeModes,
    onchange = function()
        local args = dlg.data
        local sizeMode = args.sizeMode

        local isCust = sizeMode == "CUSTOM"
        dlg:modify { id = "width", visible = isCust }
        dlg:modify { id = "height", visible = isCust }

        local isTmpl = sizeMode == "ASPECT"
        dlg:modify { id = "aRatio", visible = isTmpl }
        dlg:modify { id = "bRatio", visible = isTmpl }
        dlg:modify { id = "aspectScale", visible = isTmpl }

        updateRatio(dlg)
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "width",
    text = string.format("%d", app.preferences.new_file.width),
    decimals = 0,
    visible = defaults.sizeMode == "CUSTOM"
}

dlg:number {
    id = "height",
    text = string.format("%d", app.preferences.new_file.height),
    decimals = 0,
    visible = defaults.sizeMode == "CUSTOM"
}

dlg:newrow { always = false }

dlg:slider {
    id = "aRatio",
    label = "Ratio:",
    min = 1,
    max = 16,
    value = defaults.aRatio,
    visible = defaults.sizeMode == "ASPECT",
    onchange = function()
        updateSizeFromAspect(dlg)
    end
}

dlg:slider {
    id = "bRatio",
    min = 1,
    max = 16,
    value = defaults.bRatio,
    visible = defaults.sizeMode == "ASPECT",
    onchange = function()
        updateSizeFromAspect(dlg)
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "aspectScale",
    label = "Scale:",
    text = string.format("%.0f", defaults.aspectScale),
    decimals = 0,
    visible = defaults.sizeMode == "ASPECT",
    onchange = function()
        updateRatio(dlg)
        updateSizeFromAspect(dlg)
    end
}

dlg:separator {
    id = "clrSeparate"
}

dlg:combobox {
    id = "colorMode",
    label = "Color Mode:",
    option = defaults.colorMode,
    options = colorModes,
    onchange = function()
        local args = dlg.data
        local state = args.colorMode
        local isIndexed = state == "INDEXED"
        local isGray = state == "GRAY"
        local isRgb = state == "RGB"
        local minAlpha = args.aChannel > 0

        dlg:modify { id = "preview", visible = not isIndexed }
        dlg:modify { id = "aChannel", visible = not isIndexed }
        dlg:modify { id = "bChannel", visible = minAlpha and isRgb }
        dlg:modify { id = "gChannel", visible = minAlpha and isRgb }
        dlg:modify { id = "rChannel", visible = minAlpha and isRgb }
        dlg:modify { id = "grayChannel", visible = minAlpha and isGray }
        dlg:modify { id = "bkgIdx", visible = isIndexed }

        local palType = args.palType
        dlg:modify { id = "palType", visible = not isGray }
        dlg:modify {
            id = "palFile",
            visible = palType == "FILE" and not isGray
        }
        dlg:modify {
            id = "palPreset",
            visible = palType == "PRESET" and not isGray
        }
        dlg:modify { id = "grayCount", visible = isGray }

        if isRgb then
            updateColorPreviewRgba(dlg)
        elseif isGray then
            updateColorPreviewGray(dlg)
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "preview",
    label = "Background:",
    mode = "pick",
    colors = { Color(
        defaults.rChannel,
        defaults.gChannel,
        defaults.bChannel,
        defaults.aChannel) },
    visible = defaults.colorMode ~= "INDEXED"
}

dlg:newrow { always = false }

dlg:slider {
    id = "aChannel",
    label = "Alpha:",
    min = 0,
    max = 255,
    value = defaults.aChannel,
    visible = defaults.colorMode ~= "INDEXED",
    onchange = function()
        local args = dlg.data
        local cm = args.colorMode
        local isRgb = cm == "RGB"
        local isGray = cm == "GRAY"
        if isRgb then
            updateColorPreviewRgba(dlg)
        elseif isGray then
            updateColorPreviewGray(dlg)
        end

        if args.aChannel < 1 then
            dlg:modify { id = "bChannel", visible = false }
            dlg:modify { id = "gChannel", visible = false }
            dlg:modify { id = "rChannel", visible = false }
            dlg:modify { id = "grayChannel", visible = false }
        else
            dlg:modify { id = "bChannel", visible = isRgb }
            dlg:modify { id = "gChannel", visible = isRgb }
            dlg:modify { id = "rChannel", visible = isRgb }
            dlg:modify { id = "grayChannel", visible = isGray }
        end
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "rChannel",
    label = "RGB:",
    min = 0,
    max = 255,
    value = defaults.rChannel,
    visible = defaults.colorMode == "RGB"
        and defaults.aChannel > 0,
    onchange = function()
        updateColorPreviewRgba(dlg)
        updateGrayLinkFromRgb(dlg)
    end
}

dlg:slider {
    id = "gChannel",
    min = 0,
    max = 255,
    value = defaults.gChannel,
    visible = defaults.colorMode == "RGB"
        and defaults.aChannel > 0,
    onchange = function()
        updateColorPreviewRgba(dlg)
        updateGrayLinkFromRgb(dlg)
    end
}

dlg:slider {
    id = "bChannel",
    min = 0,
    max = 255,
    value = defaults.bChannel,
    visible = defaults.colorMode == "RGB"
        and defaults.aChannel > 0,
    onchange = function()
        updateColorPreviewRgba(dlg)
        updateGrayLinkFromRgb(dlg)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "grayChannel",
    label = "Value:",
    min = 0,
    max = 255,
    value = defaults.grayChannel,
    visible = defaults.colorMode == "GRAY"
        and defaults.aChannel > 0,
    onchange = function()
        updateColorPreviewGray(dlg)
        updateRgbLinkFromGray(dlg)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "bkgIdx",
    label = "Bkg Index:",
    min = 0,
    max = 255,
    value = defaults.bkgIdx,
    visible = defaults.colorMode == "INDEXED"
}

dlg:separator { id = "framesSeparate" }

dlg:slider {
    id = "frames",
    label = "Frames:",
    min = 1,
    max = 96,
    value = defaults.frames
}

dlg:newrow { always = false }

dlg:slider {
    id = "fps",
    label = "FPS:",
    min = 1,
    max = 50,
    value = defaults.fps
}

dlg:separator {
    id = "palSeparate"
}

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = defaults.palType,
    options = paletteTypes,
    visible = defaults.colorMode ~= "GRAY",
    onchange = function()
        local state = dlg.data.palType
        dlg:modify { id = "palFile", visible = state == "FILE" }
        dlg:modify { id = "palPreset", visible = state == "PRESET" }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = { "aseprite", "gpl", "pal", "png", "webp" },
    open = true,
    visible = defaults.colorMode ~= "GRAY"
        and defaults.palType == "FILE"
}

dlg:newrow { always = false }

dlg:entry {
    id = "palPreset",
    text = "",
    focus = false,
    visible = defaults.colorMode ~= "GRAY"
        and defaults.palType == "PRESET"
}

dlg:newrow { always = false }

dlg:slider {
    id = "grayCount",
    label = "Swatches:",
    min = 2,
    max = 256,
    value = AseUtilities.GRAY_COUNT,
    visible = defaults.colorMode == "GRAY"
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = defaults.prependMask
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        local palType = args.palType or defaults.palType
        local prependMask = args.prependMask

        local colorModeStr = args.colorMode or defaults.colorMode
        local useGrayscale = colorModeStr == "GRAY"
        local useIndexed = colorModeStr == "INDEXED"

        -- Create palette.
        local hexesSrgb = {}
        local hexesProfile = {}
        if useGrayscale then
            local grayCount = args.grayCount or AseUtilities.GRAY_COUNT
            hexesProfile = AseUtilities.grayHexes(grayCount)
            hexesSrgb = hexesProfile
        elseif palType ~= "DEFAULT" then
            local palFile = args.palFile
            local palPreset = args.palPreset
            hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                palType, palFile, palPreset, 0, 256, true)
        else
            -- User defined default palette can be loaded with
            -- app.command.LoadPalette { preset = "default" } .
            local hexesDefault = AseUtilities.DEFAULT_PAL_ARR
            local hexDefLen = #hexesDefault
            local i = 0
            while i < hexDefLen do i = i + 1
                hexesProfile[i] = hexesDefault[i]
            end
            hexesSrgb = hexesProfile
        end

        if prependMask then
            Utilities.prependMask(hexesProfile)
        end

        -- Create background image.
        local colorModeInt = 0
        local createBackground = false
        local hexBkg = 0x0
        if useGrayscale then
            colorModeInt = ColorMode.GRAY
            local aChannel = args.aChannel or defaults.aChannel
            createBackground = aChannel > 0
            if createBackground then
                local grayChannel = args.grayChannel
                    or defaults.grayChannel
                hexBkg = (aChannel << 0x18)
                    | (grayChannel << 0x10)
                    | (grayChannel << 0x08)
                    | grayChannel
            end
        elseif useIndexed then
            colorModeInt = ColorMode.INDEXED
            local bkgIdx = args.bkgIdx or defaults.bkgIdx
            if bkgIdx < #hexesProfile then
                hexBkg = hexesProfile[1 + bkgIdx]
                local aChannel = (hexBkg >> 0x18) & 0xff
                createBackground = aChannel > 0
            else
                app.alert {
                    title = "Warning",
                    text = "Index out of bounds for palette."
                }
            end
        else
            -- Default to RGB
            colorModeInt = ColorMode.RGB
            local aChannel = args.aChannel or defaults.aChannel
            createBackground = aChannel > 0
            if createBackground then
                local bChannel = args.bChannel or defaults.bChannel
                local gChannel = args.gChannel or defaults.gChannel
                local rChannel = args.rChannel or defaults.rChannel
                hexBkg = (aChannel << 0x18)
                    | (bChannel << 0x10)
                    | (gChannel << 0x08)
                    | rChannel
            end
        end

        -- Because entries are typed in, they need to be validated
        -- for negative numbers and minimums.
        local sizeMode = args.sizeMode or defaults.sizeMode
        local width = defaults.width
        local height = defaults.height
        if sizeMode == "ASPECT" then
            local aRatio = args.aRatio or defaults.aRatio
            local bRatio = args.bRatio or defaults.bRatio
            aRatio, bRatio = Utilities.reduceRatio(aRatio, bRatio)

            local scale = args.aspectScale or defaults.aspectScale
            scale = math.max(1.0, math.abs(scale))

            width = math.floor(aRatio * scale + 0.5)
            height = math.floor(bRatio * scale + 0.5)
        else
            width = args.width or defaults.width
            height = args.height or defaults.height
            if width < 0 then width = -width end
            if height < 0 then height = -height end
        end

        -- The maximum size defined in source code is 65535,
        -- but the canvas size command allows for more.
        local dfms = defaults.maxSize
        if width < 1 then width = 1 end
        if width > dfms then width = dfms end
        if height < 1 then height = 1 end
        if height > dfms then height = dfms end

        -- Store new dimensions in preferences.
        app.preferences.new_file.width = width
        app.preferences.new_file.height = height

        -- Create sprite, set file name, set to active.
        AseUtilities.preserveForeBack()
        local spec = ImageSpec {
            width = width,
            height = height,
            colorMode = ColorMode.RGB,
            transparentColor = 0
        }
        spec.colorSpace = ColorSpace { sRGB = true }
        local newSprite = Sprite(spec)

        -- File name needs extra validation to remove characters
        -- that could compromise saving a sprite.
        local filename = args.filename or defaults.filename
        filename = Utilities.validateFilename(filename)
        if #filename < 1 then filename = defaults.filename end
        newSprite.filename = filename

        app.activeSprite = newSprite

        -- Only assign palette here if not grayscale.
        if not useGrayscale then
            AseUtilities.setPalette(hexesProfile, newSprite, 1)
        end

        -- Create frames.
        local frameReqs = args.frames or defaults.frames
        local fps = args.fps or defaults.fps
        local duration = 1.0 / math.max(1, fps)
        local firstFrame = newSprite.frames[1]
        firstFrame.duration = duration

        app.transaction(function()
            AseUtilities.createFrames(
                newSprite,
                frameReqs - 1,
                duration)
        end)

        -- Assign a name to layer, avoid "Background".
        local layer = newSprite.layers[1]
        layer.name = "Bkg"

        -- Create background image. Assign to cels.
        if createBackground then
            local bkgImg = Image(spec)
            bkgImg:clear(hexBkg)
            layer.cels[1].image = bkgImg

            app.transaction(function()
                -- For continuous layer see
                -- https://community.aseprite.org/t/
                -- create-new-continuous-layer/13502
                local lenFrames = #newSprite.frames
                local j = 1
                while j < lenFrames do j = j + 1
                    newSprite:newCel(layer, j, bkgImg)
                end
            end)
        end

        -- Convert to grayscale will append palette.
        AseUtilities.changePixelFormat(colorModeInt)
        if useGrayscale then
            AseUtilities.setPalette(hexesProfile, newSprite, 1)
        end

        app.activeFrame = firstFrame
        app.refresh()
        dlg:close()
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

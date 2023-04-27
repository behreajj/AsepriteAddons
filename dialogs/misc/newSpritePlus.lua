dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local screenScale = app.preferences.general.screen_scale

-- New Sprite Plus doesn't support Color Space conversion
-- because setting color space via script interferes with
-- Aseprite's routine to ask the user what to do when
-- opening a sprite with a profile.
local colorModes = { "RGB", "INDEXED", "GRAY" }
local palTypes = { "ACTIVE", "DEFAULT", "FILE" }
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
    bkgIdx = 0,
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

        local isCst = sizeMode == "CUSTOM"
        dlg:modify { id = "width", visible = isCst }
        dlg:modify { id = "height", visible = isCst }

        local isAsp = sizeMode == "ASPECT"
        dlg:modify { id = "aRatio", visible = isAsp }
        dlg:modify { id = "bRatio", visible = isAsp }
        dlg:modify { id = "aspectScale", visible = isAsp }

        updateRatio(dlg)
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "width",
    text = string.format("%d",
        app.preferences.new_file.width),
    decimals = 0,
    visible = defaults.sizeMode == "CUSTOM"
}

dlg:number {
    id = "height",
    text = string.format("%d",
        app.preferences.new_file.height),
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

        dlg:modify { id = "bkgSpectrum", visible = isGray or isRgb }
        dlg:modify { id = "bkgIdx", visible = isIndexed }

        local palType = args.palType
        dlg:modify { id = "palType", visible = not isGray }
        dlg:modify {
            id = "palFile",
            visible = palType == "FILE" and not isGray
        }
        dlg:modify { id = "grayCount", visible = isGray }
    end
}

CanvasUtilities.spectrum(
    dlg, "bkgSpectrum", "Background:",
    180 / screenScale, 56 / screenScale,
    defaults.colorMode == "RGB",
    49.0, 1.0, 0.92, 0)

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
    options = palTypes,
    visible = defaults.colorMode ~= "GRAY",
    onchange = function()
        local state = dlg.data.palType
        dlg:modify { id = "palFile", visible = state == "FILE" }
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
    selected = defaults.prependMask,
    visible = false
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        local scale = args.aspectScale
            or defaults.aspectScale --[[@as number]]
        local palType = args.palType
            or defaults.palType --[[@as string]]
        local prependMask = args.prependMask
        local sizeMode = args.sizeMode
            or defaults.sizeMode --[[@as string]]

        local colorModeStr = args.colorMode
            or defaults.colorMode --[[@as string]]
        local useGray = colorModeStr == "GRAY"
        local useIndexed = colorModeStr == "INDEXED"
        local useAspect = sizeMode == "ASPECT"

        -- Create palette.
        local hexesSrgb = {}
        local hexesProfile = {}
        if useGray then
            local grayCount = args.grayCount
                or AseUtilities.GRAY_COUNT --[[@as integer]]
            hexesProfile = AseUtilities.grayHexes(grayCount)
            hexesSrgb = hexesProfile
        elseif palType ~= "DEFAULT" then
            local palFile = args.palFile --[[@as string]]
            hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                palType, palFile, 0, 256, true)
        else
            -- User defined default palette can be loaded with
            -- app.command.LoadPalette { preset = "default" } .
            local hexesDefault = AseUtilities.DEFAULT_PAL_ARR
            local hexDefLen = #hexesDefault
            local i = 0
            while i < hexDefLen do
                i = i + 1
                hexesProfile[i] = hexesDefault[i]
            end
            hexesSrgb = hexesProfile
        end

        if prependMask then
            Utilities.prependMask(hexesProfile)
        end

        -- Create background image.
        local colorModeInt = ColorMode.RGB
        local createBackground = false
        local hexBkg = 0x0
        if useIndexed then
            colorModeInt = ColorMode.INDEXED
            local bkgIdx = args.bkgIdx or defaults.bkgIdx --[[@as integer]]
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
            if useGray then
                colorModeInt = ColorMode.GRAY
            else
                colorModeInt = ColorMode.RGB
            end

            local specAlpha = args.spectrumAlpha --[[@as number]]
            createBackground = specAlpha > 0
            if createBackground then
                local specHue = args.spectrumHue --[[@as number]]
                local specSat = args.spectrumSat --[[@as number]]
                local specLight = args.spectrumLight --[[@as number]]
                local aseColor = Color {
                    hue = specHue,
                    saturation = specSat,
                    lightness = specLight,
                    alpha = specAlpha
                }
                hexBkg = AseUtilities.aseColorToHex(
                    aseColor, ColorMode.RGB)
            end
        end

        -- Because entries are typed in, they need to be validated
        -- for negative numbers and minimums.
        local width = defaults.width
        local height = defaults.height
        scale = math.max(1.0, math.abs(scale))
        if useAspect then
            local aRatio = args.aRatio
                or defaults.aRatio --[[@as integer]]
            local bRatio = args.bRatio
                or defaults.bRatio --[[@as integer]]
            aRatio, bRatio = Utilities.reduceRatio(aRatio, bRatio)

            width = math.floor(aRatio * scale + 0.5)
            height = math.floor(bRatio * scale + 0.5)
        else
            width = args.width or defaults.width --[[@as integer]]
            height = args.height or defaults.height --[[@as integer]]
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
        local filePrefs = app.preferences.new_file
        filePrefs.width = width
        filePrefs.height = height
        filePrefs.color_mode = colorModeInt

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
        local filename = args.filename
            or defaults.filename --[[@as string]]
        filename = Utilities.validateFilename(filename)
        if #filename < 1 then filename = defaults.filename end
        newSprite.filename = filename

        app.activeSprite = newSprite

        -- Only assign palette here if not gray.
        if not useGray then
            AseUtilities.setPalette(hexesProfile, newSprite, 1)
        end

        -- Create frames.
        local frameReqs = args.frames
            or defaults.frames --[[@as integer]]
        local fps = args.fps
            or defaults.fps --[[@as integer]]
        local duration = 1.0 / math.max(1, fps)
        local firstFrame = newSprite.frames[1]

        app.transaction("New Frames", function()
            firstFrame.duration = duration
            AseUtilities.createFrames(
                newSprite,
                frameReqs - 1,
                duration)
        end)

        -- Create background image. Assign to cels.
        if createBackground then
            app.transaction("Background", function()
                -- For continuous layer, see:
                -- https://community.aseprite.org/t/create-new-continuous-layer/13502
                -- Beware of timeline visibility:
                -- https://github.com/aseprite/aseprite/issues/3722
                -- Not used here because each new cel link creates
                -- a separate transaction.

                -- Assign a name to layer, avoid "Background".
                local layer = newSprite.layers[1]
                layer.name = "Bkg"

                local bkgImg = Image(spec)
                bkgImg:clear(hexBkg)
                layer.cels[1].image = bkgImg

                local j = 1
                while j < frameReqs do
                    j = j + 1
                    newSprite:newCel(layer, j, bkgImg)
                end
            end)
        end

        -- Convert to gray will append palette.
        AseUtilities.changePixelFormat(colorModeInt)
        if useGray then
            AseUtilities.setPalette(hexesProfile, newSprite, 1)
        end

        app.activeFrame = firstFrame
        app.command.FitScreen()
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
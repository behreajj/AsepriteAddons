dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local screenScale = 1
local setWidth = 320
local setHeight = 180
if app.preferences then
    local generalPrefs <const> = app.preferences.general
    if generalPrefs then
        local ssCand <const> = generalPrefs.screen_scale --[[@as integer]]
        if ssCand and ssCand ~= 0 then
            screenScale = ssCand
        end
    end

    local newFilePrefs <const> = app.preferences.new_file
    if newFilePrefs then
        local wCand <const> = newFilePrefs.width
        if wCand and wCand > 0 then
            setWidth = wCand
        end

        local hCand <const> = newFilePrefs.height
        if hCand and hCand > 0 then
            setHeight = hCand
        end
    end
end

-- New Sprite Plus doesn't support Color Space conversion
-- because setting color space via script interferes with
-- Aseprite's routine to ask the user what to do when
-- opening a sprite with a profile.
local colorModes <const> = { "RGB", "INDEXED", "GRAY" }
local palTypes <const> = { "ACTIVE", "DEFAULT", "FILE" }
local sizeModes <const> = { "ASPECT", "CUSTOM" }

local defaults <const> = {
    -- TODO: For width and height number entry, validate them as the user
    -- enters the inputs. Otherwise wrap around to negative is possible.
    filename = "Sprite",
    sizeMode = "CUSTOM",
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
    maxSize = 32767
}

---@param dialog Dialog
local function updateRatio(dialog)
    local args <const> = dialog.data
    local aRatio = args.aRatio --[[@as integer]]
    local bRatio = args.bRatio --[[@as integer]]
    aRatio, bRatio = Utilities.reduceRatio(aRatio, bRatio)
    dialog:modify { id = "aRatio", value = aRatio }
    dialog:modify { id = "bRatio", value = bRatio }
end

---@param dialog Dialog
local function updateSizeFromAspect(dialog)
    local args <const> = dialog.data
    local aRatio = args.aRatio --[[@as integer]]
    local bRatio = args.bRatio --[[@as integer]]
    local scale = args.aspectScale --[[@as number]]

    scale = math.abs(scale)
    scale = math.floor(0.5 + scale)
    if scale < 1 then scale = 1 end

    aRatio, bRatio = Utilities.reduceRatio(aRatio, bRatio)
    local w <const> = aRatio * scale
    local h <const> = bRatio * scale

    dialog:modify { id = "width", text = string.format("%d", w) }
    dialog:modify { id = "height", text = string.format("%d", h) }
end

local dlg <const> = Dialog { title = "New Sprite +" }

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
        local args <const> = dlg.data --[[@as integer]]
        local sizeMode <const> = args.sizeMode --[[@as string]]

        local isCst <const> = sizeMode == "CUSTOM"
        dlg:modify { id = "width", visible = isCst }
        dlg:modify { id = "height", visible = isCst }

        local isAsp <const> = sizeMode == "ASPECT"
        dlg:modify { id = "aRatio", visible = isAsp }
        dlg:modify { id = "bRatio", visible = isAsp }
        dlg:modify { id = "aspectScale", visible = isAsp }

        updateRatio(dlg)
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "width",
    text = string.format("%d", setWidth),
    decimals = 0,
    visible = defaults.sizeMode == "CUSTOM"
}

dlg:number {
    id = "height",
    text = string.format("%d", setHeight),
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
        local args <const> = dlg.data
        local state <const> = args.colorMode --[[@as string]]
        local palType <const> = args.palType --[[@as string]]

        local isIndexed <const> = state == "INDEXED"
        local isGray <const> = state == "GRAY"
        local isRgb <const> = state == "RGB"

        dlg:modify { id = "bkgSpectrum", visible = isGray or isRgb }
        dlg:modify { id = "bkgIdx", visible = isIndexed }

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
    180 // screenScale, 56 // screenScale,
    defaults.colorMode == "RGB",
    97.0, 18.0, 0.275, 0.0)

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
        local args <const> = dlg.data
        local state <const> = args.palType --[[@as string]]
        dlg:modify { id = "palFile", visible = state == "FILE" }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = AseUtilities.FILE_FORMATS_PAL,
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
    visible = true
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args <const> = dlg.data
        local scale = args.aspectScale
            or defaults.aspectScale --[[@as number]]
        local palType <const> = args.palType
            or defaults.palType --[[@as string]]
        local prependMask <const> = args.prependMask --[[@as boolean]]
        local sizeMode <const> = args.sizeMode
            or defaults.sizeMode --[[@as string]]
        local colorModeStr <const> = args.colorMode
            or defaults.colorMode --[[@as string]]

        local useGray <const> = colorModeStr == "GRAY"
        local useIndexed <const> = colorModeStr == "INDEXED"
        local useAspect <const> = sizeMode == "ASPECT"

        -- Create palette.
        local hexesProfile = {}
        if useGray then
            local grayCount <const> = args.grayCount
                or AseUtilities.GRAY_COUNT --[[@as integer]]
            hexesProfile = AseUtilities.grayHexes(grayCount)
        elseif palType ~= "DEFAULT" then
            local palFile <const> = args.palFile --[[@as string]]
            hexesProfile, _ = AseUtilities.asePaletteLoad(
                palType, palFile, 0, 512, true)
        else
            -- As of circa apiVersion 24, version v1.3-rc4.
            -- local defaultPalette <const> = app.defaultPalette
            -- if defaultPalette then
            -- hexesProfile = AseUtilities.asePaletteToHexArr(
            --     defaultPalette, 0, #defaultPalette)
            -- else
            local hexesDefault <const> = AseUtilities.DEFAULT_PAL_ARR
            local lenHexesDef <const> = #hexesDefault
            local i = 0
            while i < lenHexesDef do
                i = i + 1
                hexesProfile[i] = hexesDefault[i]
            end
            -- end
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
            local bkgIdx <const> = args.bkgIdx
                or defaults.bkgIdx --[[@as integer]]
            if bkgIdx < #hexesProfile then
                -- Problem with offset caused by prepending an alpha mask to
                -- start of palette. At least make the check widget visible.
                hexBkg = hexesProfile[1 + bkgIdx]
                local aChannel <const> = (hexBkg >> 0x18) & 0xff
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

            local specAlpha <const> = args.spectrumAlpha --[[@as number]]
            createBackground = specAlpha > 0.0
            if createBackground then
                local specLight <const> = args.spectrumLight --[[@as number]]
                local specChroma <const> = args.spectrumChroma --[[@as number]]
                local specHue <const> = args.spectrumHue --[[@as number]]

                hexBkg = Clr.toHex(
                    Clr.srLchTosRgb(
                        specLight, specChroma, specHue,
                        specAlpha))
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
        local dfms <const> = defaults.maxSize
        if width < 1 then width = 1 end
        if width > dfms then width = dfms end
        if height < 1 then height = 1 end
        if height > dfms then height = dfms end

        -- Store new dimensions in preferences.
        local autoFit = false
        local appPrefs <const> = app.preferences
        if appPrefs then
            local newFilePrefs <const> = appPrefs.new_file
            if newFilePrefs then
                newFilePrefs.width = width
                newFilePrefs.height = height
            end

            local editorPrefs <const> = appPrefs.editor
            if editorPrefs then
                autoFit = editorPrefs.auto_fit
            end
        end

        AseUtilities.preserveForeBack()

        -- File name needs extra validation to remove characters
        -- that could compromise saving a sprite.
        local filename = args.filename
            or defaults.filename --[[@as string]]
        filename = Utilities.validateFilename(filename)
        if #filename < 1 then filename = defaults.filename end

        local spec = AseUtilities.createSpec(width, height)
        local newSprite <const> = AseUtilities.createSprite(spec, filename)
        app.sprite = newSprite

        -- Only assign palette here if not gray.
        if not useGray then
            AseUtilities.setPalette(hexesProfile, newSprite, 1)
        end

        -- Create frames.
        local frameReqs <const> = args.frames
            or defaults.frames --[[@as integer]]
        local fps <const> = args.fps
            or defaults.fps --[[@as integer]]
        local duration <const> = 1.0 / math.max(1, fps)
        local firstFrame <const> = newSprite.frames[1]

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
                -- Assign a name to layer, avoid "Background".
                local layer <const> = newSprite.layers[1]
                layer.name = "Bkg"

                local bkgImg <const> = Image(spec)
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

        app.frame = firstFrame

        if autoFit then
            app.command.FitScreen()
        else
            app.command.Zoom {
                action = "set",
                focus = "center",
                percentage = 100.0
            }
            app.command.ScrollCenter()
        end

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

dlg:show {
    autoscrollbars = true,
    wait = false
}
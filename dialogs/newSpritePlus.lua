dofile("../support/aseutilities.lua")

-- New Sprite Plus doesn't support Color Space conversion
-- because setting color space via script interferes with
-- Aseprite's routine to ask the user what to do when
-- opening a sprite with a profile.
local colorModes = { "RGB", "INDEXED", "GRAY" }
local paletteTypes = { "ACTIVE", "DEFAULT", "FILE", "PRESET" }

local defaults = {
    filename = "Sprite",
    width = 256,
    height = 256,
    colorMode = "RGB",
    rChannel = 0,
    gChannel = 0,
    bChannel = 0,
    aChannel = 0,
    grayChannel = 0,
    linkRgbGray = false,
    transparencyMask = 0, -- This MUST be index ZERO.
    bkgIdx = 0,
    frames = 1,
    fps = 24,
    palType = "DEFAULT",
    prependMask = true,
    pullFocus = true
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
            alpha = args.aChannel } }
    }
end

local function rgbToGray(r8, g8, b8)
    -- HSL Lightness
    local mx = math.max(r8, g8, b8)
    local mn = math.min(r8, g8, b8)
    return math.tointeger(0.5 + 0.5 * (mx + mn))
end

local function updateGrayLinkFromRgb(dialog)
    local args = dialog.data
    local link = args.linkRgbGray
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
    local link = args.linkRgbGray
    if link then
        local v = args.grayChannel
        dialog:modify { id = "bChannel", value = v }
        dialog:modify { id = "gChannel", value = v }
        dialog:modify { id = "rChannel", value = v }
    end
end

local dlg = Dialog {
    title = "New Sprite +"
}

dlg:entry {
    id = "filename",
    label = "Name:",
    text = defaults.filename,
    focus = false
}

dlg:newrow { always = false }

dlg:number {
    id = "width",
    label = "Size:",
    text = string.format("%.0f", defaults.width),
    decimals = 0
}

dlg:number {
    id = "height",
    text = string.format("%.0f", defaults.height),
    decimals = 0
}

dlg:newrow { always = false }

dlg:combobox {
    id = "colorMode",
    label = "Color Mode:",
    option = "RGB",
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
        dlg:modify { id = "linkRgbGray", visible = not isIndexed }
        dlg:modify { id = "bkgIdx", visible = isIndexed }

        local palType = args.palType
        dlg:modify { id = "palSeparate", visible = not isGray }
        dlg:modify { id = "palType", visible = not isGray }
        dlg:modify {
            id = "palFile",
            visible = palType == "FILE" and not isGray
        }
        dlg:modify {
            id = "palPreset",
            visible = palType == "PRESET" and not isGray
        }

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
    -- label = "Red:",
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

-- dlg:newrow { always = false }

dlg:slider {
    id = "gChannel",
    -- label = "Green:",
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

-- dlg:newrow { always = false }

dlg:slider {
    id = "bChannel",
    -- label = "Blue:",
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

dlg:check {
    id = "linkRgbGray",
    label = "Link:",
    text = "RGB and Gray",
    selected = defaults.linkRgbGray,
    visible = defaults.colorMode ~= "INDEXED",
    onclick = function()
        local args = dlg.data
        if args.colorMode == "GRAY" then
            updateRgbLinkFromGray(dlg)
        elseif args.colorMode == "RGB" then
            updateGrayLinkFromRgb(dlg)
        end
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
    max = 90,
    value = defaults.fps
}

dlg:separator {
    id = "palSeparate",
    visible = defaults.colorMode ~= "GRAY"
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
    filetypes = { "aseprite", "gpl", "pal", "png" },
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

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = defaults.prependMask,
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data

        local palType = args.palType or defaults.palType
        local hexesSrgb = {}
        local hexesProfile = {}

        if palType ~= "DEFAULT" then
            local palFile = args.palFile
            local palPreset = args.palPreset

            hexesSrgb, hexesProfile = AseUtilities.asePaletteLoad(
                palType, palFile, palPreset, 0, 256, true)
        else
            -- Since a palette will be created immediately after, pbr.
            -- If this changes, and arrays are modified, then this
            -- will need to be a copy.
            hexesProfile = AseUtilities.DEFAULT_PAL_ARR
            hexesSrgb = hexesProfile
        end

        -- Do we need to change color mode? Where?
        local colorModeStr = args.colorMode or defaults.colorMode
        local colorModeInt = 0
        local createBackground = false
        local hexBkg = 0x0
        if colorModeStr == "GRAY" then
            colorModeInt = ColorMode.GRAY
            local aChannel = args.aChannel or defaults.aChannel
            createBackground = aChannel > 0
            if createBackground then
                local grayChannel = args.grayChannel or defaults.grayChannel
                hexBkg = (aChannel << 0x18)
                    | (grayChannel << 0x10)
                    | (grayChannel << 0x08)
                    | grayChannel
            end
        elseif colorModeStr == "INDEXED" then
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
        local spriteWidth = args.width or defaults.width
        local spriteHeight = args.height or defaults.height
        spriteWidth = math.abs(spriteWidth)
        spriteHeight = math.abs(spriteHeight)
        spriteWidth = math.max(1, spriteWidth)
        spriteHeight = math.max(1, spriteHeight)

        -- Create sprite, set file name, set to active.
        local filename = args.filename or defaults.filename
        if #filename < 1 then filename = defaults.filename end
        local newSprite = Sprite(
            spriteWidth, spriteHeight,
            ColorMode.RGB)
        newSprite.filename = filename
        app.activeSprite = newSprite

        local prependMask = args.prependMask
        if prependMask then
            Utilities.prependMask(hexesProfile)
        end
        local newPal = AseUtilities.hexArrToAsePalette(hexesProfile)
        newSprite:setPalette(newPal)

        -- Create frames.
        local frameReqs = args.frames or defaults.frames
        local fps = args.fps or defaults.fps
        local duration = 1.0 / math.max(1, fps)

        local firstFrame = newSprite.frames[1]
        firstFrame.duration = duration
        local createdFrames = AseUtilities.createNewFrames(
            newSprite,
            frameReqs - 1,
            duration)

        -- Assign a name to layer, avoid "Background".
        local layer = newSprite.layers[1]
        layer.name = "Bkg"

        -- Create background image. Assign to cels.
        if createBackground then
            local bkgImg = Image(
                spriteWidth, spriteHeight,
                ColorMode.RGB)
            local bkgItr = bkgImg:pixels()
            for elm in bkgItr do elm(hexBkg) end
            local firstCel = layer.cels[1]
            firstCel.image = bkgImg

            -- TODO: Replace this with a safety wrapped
            -- AseUtilities method.
            app.transaction(function()
                for i = 0, frameReqs - 2, 1 do
                    newSprite:newCel(layer, i + 2, bkgImg)
                end
            end)
        end

        -- Set proper color mode.
        if colorModeInt == ColorMode.INDEXED then
            app.command.ChangePixelFormat { format = "indexed" }
        elseif colorModeInt == ColorMode.GRAY then
            app.command.ChangePixelFormat { format = "gray" }
        end

        app.activeFrame = firstFrame
        app.refresh()
        dlg:close()
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
dofile("../../support/aseutilities.lua")

--[[
To fix filepath display in Aseprite source:
Go to src/app/commands/cmd_sprite_properties.cpp
Around line 141:
    if (Preferences::instance().general.showFullPath()) {
        window.name()->setText(document->filename());
    } else {
        window.name()->setText(document->name());
    }
--]]

local defaults <const> = {
    maskWarningInvalid = "Mask index is out of bounds.",
    maskWarningIndexed = "Non-zero mask may cause bugs.",
    maskWarningRgb = "Non-zero color at index 0.",
    textLenLimit = 32,
    minPxRatio = 1,
    maxPxRatio = 20
}

local sprite = nil
local colorSpace = nil
local filename = "" -- Make local?
local ext = ""
local title = ""
local path = ""
local prefs = nil
local showFullPath = false

local function updateSprite()
    sprite = app.site.sprite
    if not sprite and #app.sprites > 0 then
        sprite = app.sprites[#app.sprites]
        app.activeSprite = sprite
    end
    if not sprite then return false end
    filename = sprite.filename
    local spec <const> = sprite.spec
    colorSpace = spec.colorSpace

    return true
end

if not updateSprite() then return end

local function updatePrefsShowPath()
    prefs = app.preferences
    showFullPath = prefs.general.show_full_path
end

updatePrefsShowPath()

-- Should this show information only or allow the sprite to be changed?
-- Alternative versions have a pixel dimension label only, so pxRatioStr
-- defaults to the string for that label.
local dlg <const> = Dialog {
    title = string.format(
        "Properties (v %s)",
        tostring(app.version))
}
dlg:label {
    id = "pathLabel",
    label = "Path:",
    text = "",
    visible = false
}
dlg:newrow { always = false }
dlg:label {
    id = "titleLabel",
    label = "Title:",
    text = "",
    visible = false
}
dlg:newrow { always = false }
dlg:label {
    id = "extLabel",
    label = "Extension:",
    text = "",
    visible = false
}
dlg:newrow { always = false }
dlg:label {
    id = "clrMdLabel",
    label = "Color Mode:",
    text = "",
    visible = false
}
dlg:newrow { always = false }
dlg:label {
    id = "clrSpaceLabel",
    label = "Color Space:",
    text = "",
    visible = false
}
dlg:newrow { always = false }
dlg:label {
    id = "palettesLabel",
    label = "Palettes:",
    text = "",
    visible = false
}
dlg:newrow { always = false }
dlg:label {
    id = "palCountLabel",
    label = "Palette Length:",
    text = "",
    visible = false
}
dlg:newrow { always = false }
dlg:label {
    id = "maskIdxLabel",
    label = "Mask Index:",
    text = "",
    visible = false
}
dlg:newrow { always = false }
dlg:shades {
    id = "maskClr",
    label = "Mask Color:",
    mode = "sort",
    colors = {}
}
dlg:newrow { always = false }

-- Many bugs are related to indexed color mode, problematic palettes without a
-- transparent color at index 0, and the custom transparent color property.
dlg:label {
    id = "maskWarning",
    label = "Warning:",
    text = "",
    visible = false
}
dlg:newrow { always = false }
dlg:label {
    id = "dimLabel",
    label = "Dimensions:",
    text = "",
    visible = false
}
dlg:newrow { always = false }
dlg:label {
    id = "aspectLabel",
    label = "Aspect:",
    text = "",
    visible = false
}
dlg:newrow { always = false }
dlg:label {
    id = "framesLabel",
    label = "Frames:",
    text = "",
    visible = false
}
dlg:newrow { always = false }
dlg:label {
    id = "durationLabel",
    label = "Duration:",
    text = "",
    visible = false
}
dlg:newrow { always = false }
dlg:color {
    id = "sprTabColor",
    label = "Tab Color:",
    color = Color { r = 0, g = 0, b = 0, a = 0 },
    visible = false
}
dlg:newrow { always = false }
dlg:entry {
    id = "sprUserData",
    label = "User Data:",
    text = "",
    focus = false,
    visible = false
}
dlg:newrow { always = false }
dlg:slider {
    id = "aPxRatio",
    label = "Pixel Aspect:",
    min = defaults.minPxRatio,
    max = defaults.maxPxRatio,
    value = 1,
    visible = false
}
dlg:slider {
    id = "bPxRatio",
    min = defaults.minPxRatio,
    max = defaults.maxPxRatio,
    value = 1,
    visible = false
}
dlg:newrow { always = false }

-- This is confusing if a tile map layer is active and the grid is visible,
-- since its grid is independent from the sprite grid.
dlg:number {
    id = "xGrid",
    label = "Grid:",
    text = "0",
    decimals = 0,
    focus = false,
    visible = false
}
dlg:number {
    id = "yGrid",
    text = "0",
    decimals = 0,
    focus = false,
    visible = false
}
dlg:newrow { always = false }
dlg:number {
    id = "wGrid",
    text = "0",
    decimals = 0,
    focus = false,
    visible = false
}
dlg:number {
    id = "hGrid",
    text = "0",
    decimals = 0,
    focus = false,
    visible = false
}
dlg:newrow { always = false }

local function updatePath()
    if showFullPath then
        path = app.fs.filePath(filename)
    end
    local lenPath <const> = #path
    if lenPath >= defaults.textLenLimit then
        path = "..." .. string.sub(path,
            lenPath - defaults.textLenLimit, lenPath)
    end

    dlg:modify { id = "pathLabel", text = path }
    dlg:modify { id = "pathLabel", visible = showFullPath
        and path and #path > 0 }
end

local function updateTitle()
    title = app.fs.fileTitle(filename)
    if #title >= defaults.textLenLimit then
        title = string.sub(title, 1,
            defaults.textLenLimit) .. "..."
    end

    dlg:modify { id = "titleLabel", text = title }
    dlg:modify { id = "titleLabel", visible = title and #title > 0 }
end

local function updateExtension()
    ext = app.fs.fileExtension(filename)
    dlg:modify { id = "extLabel", text = ext }
    dlg:modify { id = "extLabel", visible = ext and #ext > 0 }
end

local function updateColorMode()
    local spec <const> = sprite.spec
    local colorMode <const> = spec.colorMode
    local colorModeStr = ""
    if colorMode == ColorMode.RGB then
        colorModeStr = "RGB"
    elseif colorMode == ColorMode.INDEXED then
        colorModeStr = "Indexed"
    elseif colorMode == ColorMode.GRAY then
        colorModeStr = "Grayscale"
    end

    dlg:modify { id = "clrMdLabel", text = colorModeStr }
    dlg:modify { id = "clrMdLabel", visible = #colorModeStr > 0 }
end

local function updateColorSpace()
    local spec <const> = sprite.spec
    colorSpace = spec.colorSpace
    local csName = ""
    if colorSpace then
        csName = colorSpace.name
        if csName and #csName >= defaults.textLenLimit then
            csName = string.sub(csName, 1,
                defaults.textLenLimit) .. "..."
        end
    end

    dlg:modify { id = "clrSpaceLabel", text = csName }
    dlg:modify { id = "clrSpaceLabel", visible = csName
        and #csName > 0 }
end

local function updatePalettes()
    local spec <const> = sprite.spec
    local colorMode <const> = spec.colorMode
    local palettes <const> = sprite.palettes
    local lenPals <const> = #palettes
    local palCountStr <const> = string.format("%d", lenPals)
    dlg:modify { id = "palettesLabel", text = palCountStr }
    dlg:modify {
        id = "palettesLabel",
        visible = lenPals > 1 and colorMode == ColorMode.INDEXED
    }
end

local function updatePalCount()
    local spec <const> = sprite.spec
    local colorMode <const> = spec.colorMode

    local palettes <const> = sprite.palettes
    local lenPalettes <const> = #palettes
    local actFrIdx = 1
    local actFrObj <const> = app.site.frame
    if actFrObj then
        actFrIdx = actFrObj.frameNumber
        if actFrIdx > lenPalettes then actFrIdx = 1 end
    end
    local pal <const> = palettes[actFrIdx]
    local palCount <const> = #pal

    local palCountStr = string.format("%d", palCount)
    if lenPalettes > 1 then
        palCountStr = palCountStr
            .. string.format(" (Palette %d)", actFrIdx)
    end

    dlg:modify { id = "palCountLabel", text = palCountStr }
    dlg:modify { id = "palCountLabel", visible = colorMode == ColorMode.INDEXED }
end

local function updateMaskIndex()
    local spec <const> = sprite.spec
    local colorMode <const> = spec.colorMode
    local maskIdxNum <const> = spec.transparentColor
    local maskIdxStr <const> = string.format("%d", maskIdxNum)
    dlg:modify { id = "maskIdxLabel", text = maskIdxStr }
    dlg:modify { id = "maskIdxLabel", visible = colorMode == ColorMode.INDEXED }
end

local function updateMaskColor()
    -- TODO: This should not only have a color swatch, but display its
    -- RGBA values, so as to cover (255, 0, 0, 255) vs. (0, 255, 0, 255).
    local spec <const> = sprite.spec
    local colorMode <const> = spec.colorMode

    local palettes <const> = sprite.palettes
    local lenPalettes <const> = #palettes
    local actFrIdx = 1
    local actFrObj <const> = app.site.frame
    if actFrObj then
        actFrIdx = actFrObj.frameNumber
        if actFrIdx > lenPalettes then actFrIdx = 1 end
    end
    local pal <const> = palettes[actFrIdx]
    local palLen <const> = #pal

    local maskIdxNum <const> = spec.transparentColor
    local maskIdxIsValid <const> = maskIdxNum > -1 and maskIdxNum < palLen
    local maskColorVal = Color { r = 0, g = 0, b = 0, a = 0 }
    if maskIdxIsValid then
        local maskColorRef <const> = pal:getColor(maskIdxNum)
        maskColorVal = AseUtilities.aseColorCopy(maskColorRef, "UNBOUNDED")
    end
    dlg:modify { id = "maskClr", colors = { maskColorVal } }
    dlg:modify { id = "maskClr", visible = maskIdxIsValid
        and colorMode == ColorMode.INDEXED }
end

local function updateMaskWarning()
    local spec <const> = sprite.spec
    local colorMode <const> = spec.colorMode

    local palettes <const> = sprite.palettes
    local lenPalettes <const> = #palettes
    local actFrIdx = 1
    local actFrObj <const> = app.site.frame
    if actFrObj then
        actFrIdx = actFrObj.frameNumber
        if actFrIdx > lenPalettes then actFrIdx = 1 end
    end
    local pal <const> = palettes[actFrIdx]
    local palLen <const> = #pal

    local maskIdxNum <const> = spec.transparentColor
    local maskIdxIsValid <const> = maskIdxNum > -1
        and maskIdxNum < palLen

    local idx0IsNotMask = false
    if maskIdxIsValid then
        local maskColorRef <const> = pal:getColor(maskIdxNum)
        idx0IsNotMask = AseUtilities.aseColorToHex(
            maskColorRef, ColorMode.RGB) ~= 0
    end
    local maskIsNotIdx0 = maskIdxNum ~= 0
    local maskIsProblem = false

    local maskWarning = ""
    if colorMode == ColorMode.INDEXED then
        if maskIdxIsValid then
            maskWarning = defaults.maskWarningIndexed
            maskIsProblem = idx0IsNotMask or maskIsNotIdx0
        else
            maskWarning = defaults.maskWarningInvalid
            maskIsProblem = true
        end
    else
        maskWarning = defaults.maskWarningRgb
        maskIsProblem = idx0IsNotMask
    end

    dlg:modify { id = "maskWarning", text = maskWarning }
    dlg:modify { id = "maskWarning", visible = maskIsProblem }
end

local function updateDimensions()
    local spec <const> = sprite.spec
    local width <const> = spec.width
    local height <const> = spec.height
    local dimStr <const> = string.format("%d x %d", width, height)
    dlg:modify { id = "dimLabel", text = dimStr }
    dlg:modify { id = "dimLabel", visible = true }
end

local function updateAspect()
    -- Pixel aspect ratio is applied to calculation of sprite aspect ratio.
    local sprPixelRatio <const> = sprite.pixelRatio
    local pixelWidth <const> = sprPixelRatio.width
    local pixelHeight <const> = sprPixelRatio.height

    local spec <const> = sprite.spec
    local width <const> = spec.width
    local height <const> = spec.height

    local augWidth <const> = pixelWidth * width
    local augHeight <const> = pixelHeight * height

    local aspect = 0.0
    local wRatio = 0
    local hRatio = 0
    if augHeight > 0 and augWidth > 0 then
        aspect = augWidth / augHeight
        wRatio, hRatio = Utilities.reduceRatio(augWidth, augHeight)
    end

    local aspectStr = ""
    if aspect ~= 1.0 and aspect ~= 0.0 then
        if wRatio ~= width and hRatio ~= height then
            aspectStr = string.format("%d:%d (%.3f)",
                wRatio, hRatio, aspect)
        else
            aspectStr = string.format("%.3f", aspect)
        end
    end

    dlg:modify { id = "aspectLabel", text = aspectStr }
    dlg:modify { id = "aspectLabel", visible = #aspectStr > 0 }
end

local function updateFrames()
    local frames <const> = sprite.frames
    local lenFrames <const> = #frames
    local frameStr <const> = string.format("%d", lenFrames)
    dlg:modify { id = "framesLabel", text = frameStr }
    dlg:modify { id = "framesLabel", visible = lenFrames > 1 }
end

local function updateDuration()
    local frames <const> = sprite.frames
    local lenFrames <const> = #frames
    local durSum = 0
    local i = 0
    while i < lenFrames do
        i = i + 1
        durSum = durSum + frames[i].duration
    end

    local durStr <const> = string.format("%d ms",
        math.floor(0.5 + durSum * 1000.0))
    dlg:modify { id = "durationLabel", text = durStr }
    dlg:modify { id = "durationLabel", visible = lenFrames > 1 }
end

local function updateTabColor()
    local sprColorRef <const> = sprite.color
    local sprColorVal <const> = AseUtilities.aseColorCopy(
        sprColorRef, "UNBOUNDED")

    dlg:modify { id = "sprTabColor", color = sprColorVal }
    dlg:modify { id = "sprTabColor", visible = true }
end

local function updateUserData()
    local sprUserData <const> = sprite.data

    -- Because this is a text entry widget, not a label, it
    -- needs to be shown even if the string is of length 0.
    dlg:modify { id = "sprUserData", text = sprUserData }
    dlg:modify { id = "sprUserData", visible = true }
end

local function updatePixelRatio()
    local sprPixelRatio <const> = sprite.pixelRatio
    local pixelWidth = sprPixelRatio.width
    local pixelHeight = sprPixelRatio.height

    -- There is no extra validation for size.
    -- Size(0, 0) and Size(-1, -1) are both possible.
    pixelWidth = math.min(math.max(math.abs(pixelWidth),
        defaults.minPxRatio), defaults.maxPxRatio)
    pixelHeight = math.min(math.max(math.abs(pixelHeight),
        defaults.minPxRatio), defaults.maxPxRatio)

    dlg:modify { id = "aPxRatio", value = pixelWidth }
    dlg:modify { id = "bPxRatio", value = pixelHeight }

    dlg:modify { id = "aPxRatio", visible = true }
    dlg:modify { id = "bPxRatio", visible = true }
end

local function updateGrid()
    local spriteGrid <const> = sprite.gridBounds
    local xGrid <const> = spriteGrid.x
    local yGrid <const> = spriteGrid.y
    local wGrid <const> = spriteGrid.width
    local hGrid <const> = spriteGrid.height

    dlg:modify { id = "xGrid", text = string.format("%d", xGrid) }
    dlg:modify { id = "yGrid", text = string.format("%d", yGrid) }
    dlg:modify { id = "wGrid", text = string.format("%d", wGrid) }
    dlg:modify { id = "hGrid", text = string.format("%d", hGrid) }

    dlg:modify { id = "xGrid", visible = true }
    dlg:modify { id = "yGrid", visible = true }
    dlg:modify { id = "wGrid", visible = true }
    dlg:modify { id = "hGrid", visible = true }
end

local function updateDialogWidgets()
    updatePath()
    updateTitle()
    updateExtension()
    updateColorMode()
    updateColorSpace()
    updatePalettes()
    updatePalCount()
    updateMaskIndex()
    updateMaskColor()
    updateMaskWarning()
    updateDimensions()
    updateAspect()
    updateFrames()
    updateDuration()
    updateTabColor()
    updateUserData()
    updatePixelRatio()
    updateGrid()
end

updateDialogWidgets()

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        -- TODO: Instead of an ok button, update each property onchange of its
        -- widgets above... Just remember that sprite aspect ratio depends on
        -- pixel aspect ratio, and so must be updated.
        if sprite and app.site.sprite == sprite then
            local args <const> = dlg.data
            local sprColor <const> = args.sprTabColor --[[@as Color]]
            local userData <const> = args.sprUserData --[[@as string]]

            local xGrid <const> = args.xGrid --[[@as integer]]
            local yGrid <const> = args.yGrid --[[@as integer]]

            local wGrid = args.wGrid --[[@as integer]]
            local hGrid = args.hGrid --[[@as integer]]
            wGrid = math.max(1, math.abs(wGrid))
            hGrid = math.max(1, math.abs(hGrid))

            local aPxRatio = args.aPxRatio --[[@as integer]]
            local bPxRatio = args.bPxRatio --[[@as integer]]
            aPxRatio, bPxRatio = Utilities.reduceRatio(aPxRatio, bPxRatio)

            app.transaction("Set Sprite Props", function()
                sprite.gridBounds = Rectangle(xGrid, yGrid, wGrid, hGrid)
                sprite.pixelRatio = Size(aPxRatio, bPxRatio)
                sprite.color = sprColor
                sprite.data = userData

                if aPxRatio == 1 and bPxRatio == 1 then
                    prefs.new_file.pixel_ratio = "1:1"
                elseif aPxRatio == 2 and bPxRatio == 1 then
                    prefs.new_file.pixel_ratio = "2:1"
                elseif aPxRatio == 1 and bPxRatio == 2 then
                    prefs.new_file.pixel_ratio = "1:2"
                end
            end)

            -- app.command.Refresh() cannot be used to update sprite tab color
            -- because it crashes older versions of Aseprite.
            dlg:close()
        else
            app.alert {
                title = "Error",
                text = "Sprite is no longer active."
            }
        end
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = true,
    onclick = function()
        dlg:close()
    end
}

-- Use wait = true to prevent other user inputs from changing state while
-- the dialog is open.
-- Dialog bounds cannot be realigned because of this.
dlg:show {
    autoscrollbars = true,
    wait = true
}
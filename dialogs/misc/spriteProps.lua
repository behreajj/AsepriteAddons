dofile("../../support/aseutilities.lua")

-- Sprite tab color and user data is unique to v1.3 beta.
local version = app.version
local versionMajor = version.major
local versionMinor = version.minor
local isBetaVersion = versionMajor > 0
    and versionMinor > 2

-- TODO: Consider layer count?
-- Should some diagnostic data be toggled via a t/f
-- in defaults, esp. if it is expensive to calculate?
local defaults = {
    maskWarningInvalid = "Mask index is out of bounds.",
    maskWarningIndexed = "Non-zero mask may cause bugs.",
    maskWarningRgb = "Non-zero color at index 0.",
    textLenLimit = 48
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
    sprite = app.activeSprite
    if not sprite and #app.sprites > 0 then
        sprite = app.sprites[#app.sprites]
        app.activeSprite = sprite
    end
    if not sprite then return false end
    filename = sprite.filename
    local spec = sprite.spec
    colorSpace = spec.colorSpace

    return true
end

if not updateSprite() then return end

local function updatePrefsShowPath()
    prefs = app.preferences
    showFullPath = prefs.general.show_full_path
end

updatePrefsShowPath()

-- It's an open question as to whether this should
-- show information only or allow the sprite to be
-- changed. Alternative versions of the dialog have
-- a pixel dimension label only, so pxRatioStr
-- defaults to the string for that label.
local dlg = Dialog { title = "Sprite Properties +" }
dlg:label {
    id = "pathLabel",
    label = "Path:",
    text = "",
    visible = false }
dlg:newrow { always = false }
dlg:label {
    id = "titleLabel",
    label = "Title:",
    text = "",
    visible = false }
dlg:newrow { always = false }
dlg:label {
    id = "extLabel",
    label = "Extension:",
    text = "",
    visible = false }
dlg:newrow { always = false }
dlg:label {
    id = "clrMdLabel",
    label = "Color Mode:",
    text = "",
    visible = false }
dlg:newrow { always = false }
dlg:label {
    id = "clrSpaceLabel",
    label = "Color Space:",
    text = "",
    visible = false }
dlg:newrow { always = false }
dlg:label {
    id = "palettesLabel",
    label = "Palettes:",
    text = "",
    visible = false }
dlg:newrow { always = false }
dlg:label {
    id = "palCountLabel",
    label = "Palette Length:",
    text = "",
    visible = false }
dlg:newrow { always = false }
dlg:label {
    id = "maskIdxLabel",
    label = "Mask Index:",
    text = "",
    visible = false }
dlg:newrow { always = false }
dlg:shades {
    id = "maskClr",
    label = "Mask Color:",
    mode = "sort",
    colors = {} }
dlg:newrow { always = false }

-- There are multiple bugs related to indexed
-- color mode, problematic palettes without
-- a transparent color at index 0, and the
-- custom transparent color property.
dlg:label {
    id = "maskWarning",
    label = "Warning:",
    text = "",
    visible = false }
dlg:newrow { always = false }
dlg:label {
    id = "dimLabel",
    label = "Dimensions:",
    text = "",
    visible = false }
dlg:newrow { always = false }
dlg:label {
    id = "aspectLabel",
    label = "Aspect:",
    text = "",
    visible = false }
dlg:newrow { always = false }
dlg:label {
    id = "framesLabel",
    label = "Frames:",
    text = "",
    visible = false }
dlg:newrow { always = false }
dlg:label {
    id = "durationLabel",
    label = "Duration:",
    text = "",
    visible = false }
dlg:newrow { always = false }
dlg:color {
    id = "sprTabColor",
    label = "Tab Color:",
    color = Color(0, 0, 0, 0),
    visible = false }
dlg:newrow { always = false }
dlg:entry {
    id = "sprUserData",
    label = "User Data:",
    text = "",
    focus = false,
    visible = false }
dlg:newrow { always = false }
dlg:combobox {
    id = "pxAspectDropdown",
    label = "Pixel Aspect:",
    option = "Square Pixels (1:1)",
    options = {
        "Square Pixels (1:1)",
        "Double-wide Pixels (2:1)",
        "Double-high Pixels (1:2)" },
    visible = false }
dlg:newrow { always = false }

local function updatePath()
    if showFullPath then
        path = app.fs.filePath(filename)
    end
    dlg:modify { id = "pathLabel", text = path }
    dlg:modify { id = "pathLabel", visible = showFullPath
        and path and #path > 0 }
end

local function updateTitle()
    title = app.fs.fileTitle(filename)
    dlg:modify { id = "titleLabel", text = title }
    dlg:modify { id = "titleLabel", visible = title and #title > 0 }
end

local function updateExtension()
    ext = app.fs.fileExtension(filename)
    dlg:modify { id = "extLabel", text = ext }
    dlg:modify { id = "extLabel", visible = ext and #ext > 0 }
end

local function updateColorMode()
    local spec = sprite.spec
    local colorMode = spec.colorMode
    local colorModeStr = ""
    if colorMode == ColorMode.RGB then
        colorModeStr = "RGB"
    elseif colorMode == ColorMode.INDEXED then
        colorModeStr = "Indexed"
    elseif colorMode == ColorMode.GRAY then
        colorModeStr = "Grayscale"
    end

    dlg:modify { id = "clrMdLabel", text = colorModeStr }
    dlg:modify { id = "clrMdLabel", visible = colorModeStr
        and #colorModeStr > 0 }
end

local function updateColorSpace()
    local spec = sprite.spec
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
    local spec = sprite.spec
    local colorMode = spec.colorMode
    local palettes = sprite.palettes
    local lenPals = #palettes
    local palCountStr = string.format("%d", lenPals)
    dlg:modify { id = "palettesLabel", text = palCountStr }
    dlg:modify { id = "palettesLabel", visible = lenPals > 1 and colorMode == ColorMode.INDEXED }
end

local function updatePalCount()
    local spec = sprite.spec
    local colorMode = spec.colorMode

    -- TODO: When opening multiple sprites together and Aseprite
    -- concatenates them, then multiple sprite palettes are used.
    -- Should this show all palette counts?
    local activeFrameIdx = 1
    if app.activeFrame then
        activeFrameIdx = app.activeFrame.frameNumber
    end
    local pal = sprite.palettes[activeFrameIdx]
    local palCount = #pal
    local palCountStr = string.format("%d", palCount)
    dlg:modify { id = "palCountLabel", text = palCountStr }
    dlg:modify { id = "palCountLabel", visible = colorMode == ColorMode.INDEXED }
end

local function updateMaskIndex()
    local spec = sprite.spec
    local colorMode = spec.colorMode
    local maskIdxNum = spec.transparentColor
    local maskIdxStr = string.format("%d", maskIdxNum)
    dlg:modify { id = "maskIdxLabel", text = maskIdxStr }
    dlg:modify { id = "maskIdxLabel", visible = colorMode == ColorMode.INDEXED }
end

local function updateMaskColor()
    local spec = sprite.spec
    local colorMode = spec.colorMode

    local activeFrameIdx = 1
    if app.activeFrame then
        activeFrameIdx = app.activeFrame.frameNumber
    end
    local pal = sprite.palettes[activeFrameIdx]
    local palLen = #pal

    local maskIdxNum = spec.transparentColor
    local maskIdxIsValid = maskIdxNum > -1 and maskIdxNum < palLen
    local maskColorVal = Color(0, 0, 0, 0)
    if maskIdxIsValid then
        local maskColorRef = pal:getColor(maskIdxNum)
        maskColorVal = Color(
            maskColorRef.red,
            maskColorRef.green,
            maskColorRef.blue,
            maskColorRef.alpha)
    end
    dlg:modify { id = "maskClr", colors = { maskColorVal } }
    dlg:modify { id = "maskClr", visible = maskIdxIsValid and colorMode == ColorMode.INDEXED }
end

local function updateMaskWarning()
    local spec = sprite.spec
    local colorMode = spec.colorMode

    local activeFrameIdx = 1
    if app.activeFrame then
        activeFrameIdx = app.activeFrame.frameNumber
    end
    local pal = sprite.palettes[activeFrameIdx]
    local palLen = #pal

    local maskIdxNum = spec.transparentColor
    local maskIdxIsValid = maskIdxNum > -1 and maskIdxNum < palLen

    local idx0IsNotMask = false
    if maskIdxIsValid then
        local maskColorRef = pal:getColor(maskIdxNum)
        idx0IsNotMask = maskColorRef.rgbaPixel ~= 0
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
    local spec = sprite.spec
    local width = spec.width
    local height = spec.height
    local dimStr = string.format("%d x %d", width, height)
    dlg:modify { id = "dimLabel", text = dimStr }
    dlg:modify { id = "dimLabel", visible = true }
end

local function updateAspect()
    -- Pixel aspect ratio is applied to calculation
    -- of sprite aspect ratio.
    local sprPixelRatio = sprite.pixelRatio
    local pixelWidth = sprPixelRatio.width
    local pixelHeight = sprPixelRatio.height

    local spec = sprite.spec
    local width = spec.width
    local height = spec.height

    local augWidth = pixelWidth * width
    local augHeight = pixelHeight * height

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
    dlg:modify { id = "aspectLabel", visible = aspectStr and #aspectStr > 0 }
end

local function updateFrames()
    local frames = sprite.frames
    local lenFrames = #frames
    local frameStr = string.format("%d", lenFrames)
    dlg:modify { id = "framesLabel", text = frameStr }
    dlg:modify { id = "framesLabel", visible = lenFrames > 1 }
end

local function updateDuration()
    local frames = sprite.frames
    local lenFrames = #frames
    local durSum = 0
    for i = 1, lenFrames, 1 do
        durSum = durSum + frames[i].duration
    end

    local durStr = string.format("%d ms",
        math.tointeger(0.5 + durSum * 1000.0))
    dlg:modify { id = "durationLabel", text = durStr }
    dlg:modify { id = "durationLabel", visible = lenFrames > 1 }
end

local function updateTabColor()
    local sprColorVal = nil
    if isBetaVersion then
        local sprColorRef = sprite.color
        sprColorVal = Color(
            sprColorRef.red,
            sprColorRef.green,
            sprColorRef.blue,
            sprColorRef.alpha)
    else
        sprColorVal = Color(0, 0, 0, 0)
    end

    dlg:modify { id = "sprTabColor", color = sprColorVal }
    dlg:modify { id = "sprTabColor", visible = isBetaVersion }
end

local function updateUserData()
    local sprUserData = ""
    if isBetaVersion then
        sprUserData = sprite.data
    end

    -- Because this is a text entry widget, not a label, it
    -- needs to be shown even if the string is of length 0.
    dlg:modify { id = "sprUserData", text = sprUserData }
    dlg:modify { id = "sprUserData", visible = isBetaVersion }
end

local function updatePixelRatio()
    local sprPixelRatio = sprite.pixelRatio
    local pixelWidth = sprPixelRatio.width
    local pixelHeight = sprPixelRatio.height
    local pxRatioStr = string.format(
        "%d:%d", pixelWidth, pixelHeight)
    if pixelWidth == 1 and pixelHeight == 1 then
        pxRatioStr = "Square Pixels (1:1)"
    elseif pixelWidth == 2 and pixelHeight == 1 then
        pxRatioStr = "Double-wide Pixels (2:1)"
    elseif pixelWidth == 1 and pixelHeight == 2 then
        pxRatioStr = "Double-high Pixels (1:2)"
    end

    dlg:modify { id = "pxAspectDropdown", option = pxRatioStr }
    dlg:modify { id = "pxAspectDropdown", visible = true }
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
end

updateDialogWidgets()

-- TODO: Make this its own dialog? paletteClean?
-- dlg:button {
--     id = "fixAlphaMask",
--     text = "&FIX",
--     focus = false,
--     onclick = function()
--         if sprite and app.activeSprite == sprite then
--             app.command.ChangePixelFormat { format = "rgb" }
--             sprite.transparentColor = 0
--             local hexesProfile = AseUtilities.asePaletteToHexArr(palette, 0, palCount)
--             local uniques, _ = Utilities.uniqueColors(hexesProfile, true)
--             local masked = Utilities.prependMask(uniques)
--             local newPal = AseUtilities.hexArrToAsePalette(masked)
--             sprite:setPalette(newPal)
--             app.command.ChangePixelFormat { format = "indexed" }

--             palette = sprite.palettes[1]
--             palCount = #palette
--             palCountStr = string.format("%d", palCount)
--             alphaMaskIdxNum = 0
--             alphaMaskIdxStr = "0"
--             maskClrVal = Color(0, 0, 0, 0)

--             dlg:modify { id = "palCountLabel", text = palCountStr }
--             dlg:modify { id = "maskIdx", text = alphaMaskIdxStr }
--             dlg:modify { id = "maskClr", colors = { maskClrVal } }
--             dlg:modify { id = "fixAlphaMask", visible = false }

--             app.refresh()
--         end
--     end
-- }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        if sprite and app.activeSprite == sprite then
            local args = dlg.data
            local pxAspectStr = args.pxAspectDropdown
            local sprColor = args.sprTabColor
            local userData = args.sprUserData

            app.transaction(function()
                if pxAspectStr == "Double-wide Pixels (2:1)" then
                    sprite.pixelRatio = Size(2, 1)
                elseif pxAspectStr == "Double-high Pixels (1:2)" then
                    sprite.pixelRatio = Size(1, 2)
                elseif pxAspectStr == "Square Pixels (1:1)" then
                    sprite.pixelRatio = Size(1, 1)
                end

                if isBetaVersion then
                    sprite.color = sprColor
                    sprite.data = userData
                end
            end)

            -- This is needed to update the sprite tab color.
            -- Not sure if app.refresh is needed any more...
            app.command.Refresh()
            dlg:close()
        else
            app.alert("Sprite is no longer active.")
        end
    end
}

dlg:button {
    id = "refresh",
    text = "&REFRESH",
    focus = false,
    onclick = function()
        if updateSprite() then
            updatePrefsShowPath()
            updateDialogWidgets()
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

dlg:show { wait = false }

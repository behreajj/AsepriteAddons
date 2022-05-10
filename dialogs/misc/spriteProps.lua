local textLenLimit = 48

local function gcd(a, b)
    while b ~= 0 do a, b = b, a % b end
    return a
end

local function reduceRatio(a, b)
    local denom = gcd(a, b)
    return a // denom, b // denom
end

-- TODO: Consider site events listners?
-- TODO: Handle sprite transparent color index.
local sprite = app.activeSprite

local appVersion = app.version
local versionMajor = appVersion.major
local versionMinor = appVersion.minor
local is13 = versionMajor > 0 and versionMinor > 2

-- In case home tab is selected.
if not sprite and #app.sprites > 0 then
    sprite = app.sprites[#app.sprites]
    app.activeSprite = sprite
end

if not sprite then return end

local filename = sprite.filename
local ext = app.fs.fileExtension(filename)
local title = app.fs.fileTitle(filename)

local path = ""
local showFullPath = app.preferences.general.show_full_path
if showFullPath then
    path = app.fs.filePath(filename)
    if path and #path >= textLenLimit then
        path = string.sub(path, 1, textLenLimit) .. "..."
    end
end

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

-- Assigning and converting a color space,
-- esp. from an .icc file, is considered an
-- operation for a separate dialog.
local colorSpace = spec.colorSpace
local csName = ""
if colorSpace then
    csName = colorSpace.name
    if csName and #csName >= textLenLimit then
        csName = string.sub(csName, 1, textLenLimit) .. "..."
    end
end

local palCount = #sprite.palettes[1]
local palCountStr = string.format("%d", palCount)

local sprPixelRatio = sprite.pixelRatio
local pixelWidth = sprPixelRatio.width
local pixelHeight = sprPixelRatio.height

local pxRatioStr = ""
if pixelWidth == 1 and pixelHeight == 1 then
    pxRatioStr = "Square Pixels (1:1)"
elseif pixelWidth == 2 and pixelHeight == 1 then
    pxRatioStr = "Double-wide Pixels (2:1)"
elseif pixelWidth == 1 and pixelHeight == 2 then
    pxRatioStr = "Double-high Pixels (1:2)"
end

local width = math.max(1, spec.width)
local height = math.max(1, spec.height)
local dimStr = string.format("%d x %d", width, height)

local augWidth = pixelWidth * width
local augHeight = pixelHeight * height
local aspect = augWidth / augHeight
local wRatio, hRatio = reduceRatio(augWidth, augHeight)
local aspectStr = ""
if aspect ~= 1.0 then
    aspectStr = string.format("%d:%d (%.3f)", wRatio, hRatio, aspect)
end

local frameCount = #sprite.frames
local frameStr = string.format("%d", frameCount)

local sprColorRef = nil
local sprColorVal = nil
local sprUserData = ""
if is13 then
    sprColorRef = sprite.color
    sprColorVal = Color(
        sprColorRef.red,
        sprColorRef.green,
        sprColorRef.blue,
        sprColorRef.alpha)
    sprUserData = sprite.data
end

local dlg = Dialog { title = "Sprite Properties +" }

if title and #title > 0 then
    dlg:label {
        id = "titleLabel",
        label = "Title:",
        text = title
    }
    dlg:newrow { always = false }
end

if ext and #ext > 0 then
    dlg:label {
        id = "extLabel",
        label = "Extension:",
        text = ext
    }
    dlg:newrow { always = false }
end

if path and #path > 0 then
    dlg:label {
        id = "pathLabel",
        label = "Path:",
        text = path
    }
    dlg:newrow { always = false }
end

if csName and #csName > 0 then
    dlg:label {
        id = "clrSpaceLabel",
        label = "Color Space:",
        text = csName
    }
    dlg:newrow { always = false }
end

if colorModeStr and #colorModeStr > 0 then
    dlg:label {
        id = "clrMdLabel",
        label = "Color Mode:",
        text = colorModeStr
    }
    dlg:newrow { always = false }
end

dlg:label {
    id = "palCountLabel",
    label = "Palette Length:",
    text = palCountStr
}
dlg:newrow { always = false }

dlg:label {
    id = "dimLabel",
    label = "Dimensions:",
    text = dimStr
}
dlg:newrow { always = false }

if aspectStr and #aspectStr > 0 then
    dlg:label {
        id = "aspectLabel",
        label = "Aspect:",
        text = aspectStr
    }
    dlg:newrow { always = false }
end

dlg:label {
    id = "frameLabel",
    label = "Frames:",
    text = frameStr
}
dlg:newrow { always = false }

dlg:color {
    id = "sprColor",
    label = "Color:",
    color = sprColorVal
}
dlg:newrow { always = false }

dlg:entry {
    id = "sprUserData",
    label = "User Data:",
    text = sprUserData,
    focus = false
}

dlg:combobox {
    id = "pxAspectDropdown",
    label = "Pixel Aspect:",
    option = pxRatioStr,
    options = {
        "Square Pixels (1:1)",
        "Double-wide Pixels (2:1)",
        "Double-high Pixels (1:2)" }
}

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        if sprite and app.activeSprite == sprite then
            local args = dlg.data
            local pxAspectStr = args.pxAspectDropdown
            local sprColor = args.sprColor
            local userData = args.sprUserData

            if pxAspectStr == "Double-wide Pixels (2:1)" then
                sprite.pixelRatio = Size(2, 1)
            elseif pxAspectStr == "Double-high Pixels (1:2)" then
                sprite.pixelRatio = Size(1, 2)
            elseif pxAspectStr == "Square Pixels (1:1)" then
                sprite.pixelRatio = Size(1, 1)
            end

            if is13 then
                sprite.color = sprColor
                sprite.data = userData
            end

            app.refresh()
        end

        dlg:close()
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

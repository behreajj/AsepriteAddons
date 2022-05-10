dofile("../../support/aseutilities.lua")

local defaults = { textLenLimit = 48 }

-- TODO: Move this & new sprite plus versions
-- to Utilities?
local function gcd(a, b)
    while b ~= 0 do a, b = b, a % b end
    return a
end

local function reduceRatio(a, b)
    local denom = gcd(a, b)
    return a // denom, b // denom
end

local sprite = app.activeSprite

-- In case home tab is selected.
if not sprite and #app.sprites > 0 then
    sprite = app.sprites[#app.sprites]
    app.activeSprite = sprite
end
if not sprite then return end

-- Unpack app properties.
local appVersion = app.version
local appPrefs = app.preferences

-- Sprite tab color and user data is unique to v1.3 beta.
local versionMajor = appVersion.major
local versionMinor = appVersion.minor
local isBetaVersion = versionMajor > 0
    and versionMinor > 2

-- Unpack sprite properties.
local filename = sprite.filename
local spec = sprite.spec
local sprPixelRatio = sprite.pixelRatio
local pal = sprite.palettes[1]
local frames = sprite.frames

-- Unpack specification properties.
local colorMode = spec.colorMode
local colorSpace = spec.colorSpace
local maskIdxNum = spec.transparentColor
local height = spec.height
local width = spec.width

local ext = app.fs.fileExtension(filename)
local title = app.fs.fileTitle(filename)

local path = ""
local showFullPath = appPrefs.general.show_full_path
if showFullPath then
    path = app.fs.filePath(filename)
    if path and #path >= defaults.textLenLimit then
        path = string.sub(path, 1,
            defaults.textLenLimit) .. "..."
    end
end

local colorModeStr = ""
local isIndexed = colorMode == ColorMode.INDEXED
if colorMode == ColorMode.RGB then
    colorModeStr = "RGB"
elseif isIndexed then
    colorModeStr = "Indexed"
elseif colorMode == ColorMode.GRAY then
    colorModeStr = "Grayscale"
end

-- There are multiple bugs related to indexed
-- color mode, problematic palettes without
-- a transparent color at index 0, and the
-- custom transparent color property.
local maskIdxStr = ""
local maskClrVal = nil
local maskIsProblem = false
if isIndexed then
    local maskColorRef = pal:getColor(maskIdxNum)
    maskClrVal = Color(
        maskColorRef.red,
        maskColorRef.green,
        maskColorRef.blue,
        maskColorRef.alpha)
    maskIdxStr = string.format("%d", maskIdxNum)
    maskIsProblem = maskIdxNum ~= 0
        or maskClrVal.rgbaPixel ~= 0
end

-- Assigning and converting a color space,
-- esp. from an .icc file, is considered an
-- operation for a separate dialog.
local csName = ""
if colorSpace then
    csName = colorSpace.name
    if csName and #csName >= defaults.textLenLimit then
        csName = string.sub(csName, 1,
            defaults.textLenLimit) .. "..."
    end
end

local palCount = #pal
local palCountStr = string.format("%d", palCount)

-- It's an open question as to whether this should
-- show information only or allow the sprite to be
-- changed. Alternative versions of the dialog have
-- a pixel dimension label only, so pxRatioStr
-- defaults to the string for that label.
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

local dimStr = string.format("%d x %d", width, height)

-- Pixel aspect ratio is applied to calculation
-- of sprite aspect ratio.
local augWidth = pixelWidth * width
local augHeight = pixelHeight * height
local aspect = 0.0
local wRatio = 0
local hRatio = 0
if augHeight > 0 and augWidth > 0 then
    aspect = augWidth / augHeight
    wRatio, hRatio = reduceRatio(augWidth, augHeight)
end

local aspectStr = ""
if aspect ~= 1.0 and aspect ~= 0.0 then
    aspectStr = string.format("%d:%d (%.3f)",
        wRatio, hRatio, aspect)
end

local frameCount = #frames
local frameStr = string.format("%d", frameCount)

local durationStr = ""
local durSum = 0
for i = 1, frameCount, 1 do
    durSum = durSum + frames[i].duration
end
durationStr = string.format("%d ms",
    math.tointeger(0.5 + durSum * 1000.0))

local sprColorRef = nil
local sprColorVal = nil
local sprUserData = ""
if isBetaVersion then
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

if isIndexed then
    dlg:label {
        id = "palCountLabel",
        label = "Palette Length:",
        text = palCountStr
    }

    dlg:newrow { always = false }

    dlg:label {
        id = "maskIdx",
        label = "Mask Index:",
        text = maskIdxStr
    }

    dlg:newrow { always = false }

    dlg:shades {
        id = "maskClr",
        label = "Mask Color:",
        mode = "sort",
        colors = { maskClrVal }
    }

    dlg:newrow { always = false }

    if maskIsProblem then
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

        dlg:label {
            id = "warning",
            label = "Warning:",
            text = "Mask may cause bugs."
        }

        dlg:newrow { always = false }
    end
end

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

-- dlg:label {
--     id = "pxAspectLabel",
--     label = "Pixel Aspect:",
--     text = pxRatioStr
-- }

-- dlg:newrow { always = false }

if frameCount > 1 then
    dlg:label {
        id = "frameLabel",
        label = "Frames:",
        text = frameStr
    }

    dlg:newrow { always = false }

    dlg:label {
        id = "durationLabel",
        label = "Duration:",
        text = durationStr
    }

    dlg:newrow { always = false }
end

if isBetaVersion then
    dlg:color {
        id = "sprColor",
        label = "Tab Color:",
        color = sprColorVal
    }

    dlg:newrow { always = false }

    dlg:entry {
        id = "sprUserData",
        label = "User Data:",
        text = sprUserData,
        focus = false
    }

    dlg:newrow { always = false }
end

dlg:combobox {
    id = "pxAspectDropdown",
    label = "Pixel Aspect:",
    option = pxRatioStr,
    options = {
        "Square Pixels (1:1)",
        "Double-wide Pixels (2:1)",
        "Double-high Pixels (1:2)" }
}

dlg:newrow { always = false }

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
    id = "cancel",
    text = "&CANCEL",
    focus = true,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }

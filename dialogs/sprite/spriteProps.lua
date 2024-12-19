dofile("../../support/aseutilities.lua")

--[[To fix filepath display in Aseprite source:
Go to src/app/commands/cmd_sprite_properties.cpp
Around line 288:
    if (Preferences::instance().general.showFullPath()) {
        window.name()->setText(document->filename());
    } else {
        window.name()->setText(document->name());
    }
]]

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local defaults <const> = {
    textLenLimit = 32,
    maskWarningInvalid = "Mask index is out of bounds.",
    maskWarningIndex = "Mask index is not zero.",
    maskWarningRgb = "Mask color is not clear black.",
    minPxRatio = 1,
    maxPxRatio = 20
}

local showFullPath = false
local allowPxRatio = false

local appPrefs <const> = app.preferences
if appPrefs then
    local generalPrefs <const> = appPrefs.general
    if generalPrefs then
        if generalPrefs.show_full_path then
            showFullPath = generalPrefs.show_full_path
        end
    end

    -- For old renderer, pixel ratios other than the default will cause
    -- crashes under certain zoom levels.
    -- See https://github.com/aseprite/aseprite/issues/4632
    local experimental <const> = appPrefs.experimental
    if experimental then
        if experimental.new_render_engine then
            allowPxRatio = true
        end
    end
end

local fileName <const> = sprite.filename

local dlg <const> = Dialog {
    title = string.format(
        "Properties (v %s)",
        tostring(app.version))
}

if showFullPath then
    local displayPath = app.fs.filePath(fileName)
    local lenDisplayPath <const> = #displayPath
    if lenDisplayPath >= defaults.textLenLimit then
        displayPath = "..." .. string.sub(
            displayPath,
            lenDisplayPath - defaults.textLenLimit,
            lenDisplayPath)
    end

    if #displayPath > 0 then
        dlg:label {
            id = "pathLabel",
            label = "Path:",
            text = displayPath
        }

        dlg:newrow { always = false }
    end
end

local displayTitle = app.fs.fileTitle(fileName)
if #displayTitle >= defaults.textLenLimit then
    displayTitle = string.sub(displayTitle, 1,
        defaults.textLenLimit) .. "..."
end

if #displayTitle > 0 then
    dlg:label {
        id = "titleLabel",
        label = "Title:",
        text = displayTitle,
    }

    dlg:newrow { always = false }
end

local displayExt <const> = app.fs.fileExtension(fileName)

if #displayExt > 0 then
    dlg:label {
        id = "extLabel",
        label = "Extension:",
        text = displayExt
    }

    dlg:newrow { always = false }
end

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

dlg:label {
    id = "clrMdLabel",
    label = "Color Mode:",
    text = colorModeStr
}

dlg:newrow { always = false }

local colorSpace <const> = spec.colorSpace
local csName = ""
if colorSpace then
    csName = colorSpace.name
    if csName and #csName >= defaults.textLenLimit then
        csName = string.sub(csName, 1,
            defaults.textLenLimit) .. "..."
    end
end

if #csName > 0 then
    dlg:label {
        id = "clrSpaceLabel",
        label = "Color Space:",
        text = csName
    }

    dlg:newrow { always = false }
end

if colorMode == ColorMode.INDEXED then
    local pals <const> = sprite.palettes
    local lenPals <const> = #pals
    local lenPalsStr <const> = string.format("%d", lenPals)

    dlg:label {
        id = "palettesLabel",
        label = "Palettes:",
        text = lenPalsStr
    }

    dlg:newrow { always = false }

    local palIdx = 1
    local actFrObj <const> = site.frame
    if actFrObj then
        palIdx = actFrObj.frameNumber
        if palIdx > lenPals then palIdx = 1 end
    end
    local pal <const> = pals[palIdx]
    local lenPal <const> = #pal

    local lenPalStr = string.format("%d", lenPal)
    if lenPals > 1 then
        lenPalStr = lenPalStr
            .. string.format(" (Palette %d)", palIdx)
    end

    dlg:label {
        id = "palCountLabel",
        label = "Swatches:",
        text = lenPalStr
    }

    dlg:newrow { always = false }

    local alphaIndex <const> = spec.transparentColor
    local alphaIdxStr <const> = string.format("%d", alphaIndex)

    dlg:label {
        id = "maskIdxLabel",
        label = "Mask Index:",
        text = alphaIdxStr
    }

    dlg:newrow { always = false }

    local alphaIndexIsValid <const> = alphaIndex >= 0
        and alphaIndex < lenPal
    if alphaIndexIsValid then
        local maskColorRef <const> = pal:getColor(alphaIndex)
        local maskColorVal = AseUtilities.aseColorCopy(maskColorRef, "UNBOUNDED")

        dlg:shades {
            id = "maskClr",
            label = "Mask Color:",
            mode = "sort",
            colors = { maskColorVal }
        }

        dlg:newrow { always = false }

        local alphaIndexNonZero <const> = alphaIndex ~= 0
        if alphaIndexNonZero then
            dlg:label {
                id = "maskWarningIndex",
                label = "Warning:",
                text = defaults.maskWarningIndex
            }

            dlg:newrow { always = false }
        end

        local maskNonZero <const> = maskColorRef.rgbaPixel ~= 0
        if maskNonZero then
            dlg:label {
                id = "maskWarningRgb",
                label = "Warning:",
                text = defaults.maskWarningRgb
            }

            dlg:newrow { always = false }
        end
    else
        dlg:label {
            id = "maskWarningBounds",
            label = "Warning:",
            text = defaults.maskWarningInvalid
        }

        dlg:newrow { always = false }
    end
end

local width <const> = spec.width
local height <const> = spec.height
local dimStr <const> = string.format("%d x %d", width, height)

dlg:label {
    id = "dimLabel",
    label = "Dimensions:",
    text = dimStr
}

dlg:newrow { always = false }

local sprPixelRatio <const> = sprite.pixelRatio
local pixelWidth <const> = math.min(math.max(math.abs(sprPixelRatio.width),
    defaults.minPxRatio), defaults.maxPxRatio)
local pixelHeight <const> = math.min(math.max(math.abs(sprPixelRatio.height),
    defaults.minPxRatio), defaults.maxPxRatio)
local augWidth <const> = pixelWidth * width
local augHeight <const> = pixelHeight * height

local aspect = 0.0
local wRatio = 0
local hRatio = 0
if augHeight > 0 and augWidth > 0 then
    aspect = augWidth / augHeight
    wRatio, hRatio = Utilities.reduceRatio(augWidth, augHeight)
end

if aspect ~= 1.0 and aspect ~= 0.0 then
    local aspectStr = ""
    if wRatio ~= width and hRatio ~= height then
        aspectStr = string.format("%d:%d (%.3f)",
            wRatio, hRatio, aspect)
    else
        aspectStr = string.format("%.3f", aspect)
    end

    dlg:label {
        id = "aspectLabel",
        label = "Aspect:",
        text = aspectStr
    }

    dlg:newrow { always = false }
end

local frObjs <const> = sprite.frames
local lenFrObjs <const> = #frObjs
if lenFrObjs > 1 then
    local frameStr <const> = string.format("%d", lenFrObjs)
    dlg:label {
        id = "framesLabel",
        label = "Frames:",
        text = frameStr
    }

    dlg:newrow { always = false }

    local durSum = 0
    local i = 0
    while i < lenFrObjs do
        i = i + 1
        durSum = durSum + frObjs[i].duration
    end
    local durStr <const> = string.format("%d ms",
        math.floor(durSum * 1000.0 + 0.5))

    dlg:label {
        id = "durationLabel",
        label = "Duration:",
        text = durStr
    }

    dlg:newrow { always = false }
end

local sprColorRef <const> = sprite.color
local sprColorVal <const> = AseUtilities.aseColorCopy(
    sprColorRef, "UNBOUNDED")

dlg:color {
    id = "sprTabColor",
    label = "Tab Color:",
    color = sprColorVal
}

dlg:newrow { always = false }

local userDataOld <const> = sprite.data

dlg:entry {
    id = "sprUserData",
    label = "User Data:",
    text = userDataOld,
    focus = false
}

dlg:newrow { always = false }

dlg:slider {
    id = "aPxRatio",
    label = "Pixel Aspect:",
    min = defaults.minPxRatio,
    max = defaults.maxPxRatio,
    value = pixelWidth,
    visible = allowPxRatio
}

dlg:slider {
    id = "bPxRatio",
    min = defaults.minPxRatio,
    max = defaults.maxPxRatio,
    value = pixelHeight,
    visible = allowPxRatio
}

dlg:newrow { always = false }

local spriteGrid <const> = sprite.gridBounds
local xGridOld <const> = spriteGrid.x
local yGridOld <const> = spriteGrid.y
local wGridOld <const> = spriteGrid.width
local hGridOld <const> = spriteGrid.height

-- This is confusing if a tile map layer is active and the grid is on,
-- since its grid is independent from the sprite grid.
dlg:number {
    id = "xGrid",
    text = string.format("%d", xGridOld),
    decimals = 0,
    focus = false,
    visible = false
}

dlg:number {
    id = "yGrid",
    text = string.format("%d", yGridOld),
    decimals = 0,
    focus = false,
    visible = false
}

dlg:newrow { always = false }

dlg:number {
    id = "wGrid",
    label = "Grid:",
    text = string.format("%d", wGridOld),
    decimals = 0,
    focus = false
}

dlg:number {
    id = "hGrid",
    text = string.format("%d", hGridOld),
    decimals = 0,
    focus = false
}

dlg:newrow { always = false }

if appPrefs then
    local docPrefs <const> = appPrefs.document(sprite)
    if docPrefs then
        local bgPref <const> = docPrefs.bg
        if bgPref then
            dlg:color {
                id = "bkg1",
                color = AseUtilities.aseColorCopy(bgPref.color1, "")
            }

            dlg:color {
                id = "bkg2",
                color = AseUtilities.aseColorCopy(bgPref.color2, "")
            }

            dlg:newrow { always = false }
        end
    end
end

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        if sprite and app.site.sprite == sprite then
            local args <const> = dlg.data
            local sprColor <const> = args.sprTabColor --[[@as Color]]
            local userDataNew <const> = args.sprUserData --[[@as string]]

            local xGridNew <const> = args.xGrid --[[@as integer]]
            local yGridNew <const> = args.yGrid --[[@as integer]]

            local wGridNew = args.wGrid --[[@as integer]]
            local hGridNew = args.hGrid --[[@as integer]]
            wGridNew = math.max(1, math.abs(wGridNew))
            hGridNew = math.max(1, math.abs(hGridNew))

            local aPxRatio = pixelWidth
            local bPxRatio = pixelHeight
            if allowPxRatio then
                aPxRatio = args.aPxRatio --[[@as integer]]
                bPxRatio = args.bPxRatio --[[@as integer]]
                aPxRatio, bPxRatio = Utilities.reduceRatio(
                    aPxRatio, bPxRatio)
            end

            app.transaction("Set Sprite Props", function()
                sprite.gridBounds = Rectangle(
                    xGridNew, yGridNew,
                    wGridNew, hGridNew)
                sprite.color = AseUtilities.aseColorCopy(sprColor, "")
                sprite.data = userDataNew
                sprite.pixelRatio = Size(aPxRatio, bPxRatio)
            end)

            if appPrefs then
                local docPrefs <const> = appPrefs.document(sprite)
                if docPrefs then
                    local bgPref <const> = docPrefs.bg
                    if bgPref then
                        local bkg1 <const> = args.bkg1 --[[@as Color]]
                        local bkg2 <const> = args.bkg2 --[[@as Color]]

                        bgPref.type = 5
                        bgPref.size = Size(wGridNew, hGridNew)
                        bgPref.color1 = AseUtilities.aseColorCopy(bkg1, "")
                        bgPref.color2 = AseUtilities.aseColorCopy(bkg2, "")
                    end
                end
            end

            app.refresh()
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

-- Use wait = true to prevent other user inputs from changing
-- state while the dialog is open.
-- Dialog bounds cannot be realigned because of this.
dlg:show {
    autoscrollbars = true,
    wait = true
}
dofile("../../support/aseutilities.lua")


---@param sprites Sprite[]
---@param hexes integer[]
---@param keepIndices boolean
local function updatePalettes(sprites, hexes, keepIndices)
    local cmIdx <const> = ColorMode.INDEXED
    local cmRgb <const> = ColorMode.RGB
    local notKeep <const> = not keepIndices

    local setPalette <const> = AseUtilities.setPalette
    local changePixelFormat <const> = AseUtilities.changePixelFormat

    local lenCandidates <const> = #sprites
    local i = 0
    while i < lenCandidates do
        i = i + 1

        -- The active sprite needs to be set for the undo history to be
        -- properly maintained among each sprite.
        local sprite <const> = sprites[i]
        local oldColorMode <const> = sprite.colorMode
        local keepMaxLen <const> = oldColorMode == cmIdx and keepIndices

        app.sprite = sprite
        if notKeep then changePixelFormat(cmRgb) end

        local lenPals <const> = #sprite.palettes
        -- This isn't as efficient as it could be because the same
        -- Aseprite Colors are recreated for each target palette when they
        -- are converted by value anyway.
        local j = 0
        while j < lenPals do
            j = j + 1
            setPalette(hexes, sprite, j,
                keepMaxLen)
        end

        if notKeep then changePixelFormat(oldColorMode) end
    end
end

local palTypes <const> = { "ACTIVE", "FILE" }

local defaults <const> = {
    palType = "ACTIVE",
    keepIndices = false,
    uniquesOnly = false,
    prependMask = true,
    startIndex = 0,
    count = 256,
    pullFocus = false
}

local dlg <const> = Dialog { title = "Share Palette" }

dlg:combobox {
    id = "palType",
    label = "Source:",
    option = "ACTIVE",
    options = palTypes,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.palType --[[@as string]]
        dlg:modify {
            id = "palFile",
            visible = state == "FILE"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = AseUtilities.FILE_FORMATS_PAL,
    open = true,
    visible = false
}

dlg:newrow { always = false }

dlg:check {
    id = "keepIndices",
    label = "Indices:",
    text = "&Keep",
    selected = defaults.keepIndices,
    visible = not defaults.useNew
}

dlg:newrow { always = false }

dlg:check {
    id = "uniquesOnly",
    label = "Uniques Only:",
    selected = defaults.uniquesOnly
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = defaults.prependMask,
}

dlg:newrow { always = false }

dlg:slider {
    id = "startIndex",
    label = "Start:",
    min = 0,
    max = 255,
    value = defaults.startIndex,
    visible = false
}

dlg:newrow { always = false }

dlg:slider {
    id = "count",
    label = "Count:",
    min = 1,
    max = 256,
    value = defaults.count,
    visible = false
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local openSprites <const> = app.sprites
        local lenOpenSprites <const> = #openSprites
        if lenOpenSprites <= 0 then
            app.alert {
                title = "Error",
                text = "There are no open sprites."
            }
            return
        end

        local profileNone <const> = ColorSpace()
        local profileSrgb <const> = ColorSpace { sRGB = true }
        local profActive = profileSrgb
        local activeSprite <const> = app.sprite
        if activeSprite then
            profActive = activeSprite.colorSpace
        end

        local appTool <const> = app.tool
        if appTool then
            if appTool.id == "slice" then
                app.tool = "hand"
            end
        end

        AseUtilities.preserveForeBack()

        local args <const> = dlg.data
        local palType <const> = args.palType
            or defaults.palType --[[@as string]]
        local palFile <const> = args.palFile --[[@as string]]
        local startIndex <const> = args.startIndex
            or defaults.startIndex --[[@as integer]]
        local count <const> = args.count
            or defaults.count --[[@as integer]]

        ---@type Sprite[]
        local candidatesApprox <const> = {}
        ---@type Sprite[]
        local candidatesExact <const> = {}
        local rejected <const> = {
            "Not all sprites were included. Check to see",
            "if the sprite has a matching color mode and",
            "color profile. Excluded sprites are:"
        }

        local candLenApprox = 0
        local candLenExact = 0
        local rejLen = #rejected

        local errorFlag = false
        local h = 0
        while h < lenOpenSprites do
            h = h + 1
            local sprite <const> = openSprites[h]
            local filename <const> = app.fs.fileTitle(sprite.filename)

            local profile <const> = sprite.colorSpace
            if profile == profActive then
                candLenExact = candLenExact + 1
                candidatesExact[candLenExact] = sprite
            elseif (profile == nil
                    or profile == profileSrgb
                    or profile == profileNone) then
                candLenApprox = candLenApprox + 1
                candidatesApprox[candLenApprox] = sprite
            else
                errorFlag = true
                rejLen = rejLen + 1
                rejected[rejLen] = filename
            end
        end

        local hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
            palType, palFile, startIndex, count, true)

        local uniquesOnly <const> = args.uniquesOnly --[[@as boolean]]
        if uniquesOnly then
            local uniquesProfile <const>, _ <const> = Utilities.uniqueColors(
                hexesProfile, true)
            hexesProfile = uniquesProfile

            local uniquesSrgb <const>, _ <const> = Utilities.uniqueColors(
                hexesSrgb, true)
            hexesSrgb = uniquesSrgb
        end

        local prependMask <const> = args.prependMask --[[@as boolean]]
        if prependMask then
            Utilities.prependMask(hexesProfile)
            Utilities.prependMask(hexesSrgb)
        end

        local keepIndices <const> = args.keepIndices --[[@as boolean]]
        updatePalettes(candidatesApprox, hexesSrgb, keepIndices)
        updatePalettes(candidatesExact, hexesProfile, keepIndices)

        if activeSprite then
            app.sprite = activeSprite
        end
        app.refresh()

        if errorFlag then
            app.alert {
                title = "Warning",
                text = rejected
            }
        else
            app.alert {
                title = "Success",
                text = "Palette shared."
            }
        end
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
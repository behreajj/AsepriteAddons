dofile("../../support/aseutilities.lua")

local palTypes <const> = { "ACTIVE", "FILE" }
local sortOrders <const> = { "ASCENDING", "DESCENDING" }
local sortPresets <const> = {
    "ALPHA",
    "BLUE_YELLOW",
    "CHROMA",
    "GREEN_RED",
    "HUE",
    "LUMA"
}

local defaults <const> = {
    aPalType = "ACTIVE",
    bPalType = "FILE",
    uniquesOnly = true,
    prependMask = true,
    useSort = false,
    sortPreset = "LUMA",
    ascDesc = "ASCENDING",
}

local dlg <const> = Dialog { title = "Concatenate Palettes" }

dlg:combobox {
    id = "aPalType",
    label = "Palette A:",
    option = defaults.aPalType,
    options = palTypes,
    onchange = function()
        local args <const> = dlg.data
        local aState <const> = args.aPalType --[[@as string]]

        dlg:modify {
            id = "aPalFile",
            visible = aState == "FILE"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "aPalFile",
    filetypes = AseUtilities.FILE_FORMATS_PAL,
    open = true,
    visible = defaults.aPalType == "FILE"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "bPalType",
    label = "Palette B:",
    option = defaults.bPalType,
    options = palTypes,
    onchange = function()
        local args <const> = dlg.data
        local bState <const> = args.bPalType --[[@as string]]
        dlg:modify {
            id = "bPalFile",
            visible = bState == "FILE"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "bPalFile",
    filetypes = AseUtilities.FILE_FORMATS_PAL,
    open = true,
    visible = defaults.bPalType == "FILE",
    focus = defaults.bPalType == "FILE"
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
    selected = defaults.prependMask
}

dlg:newrow { always = false }

dlg:check {
    id = "useSort",
    label = "Sort:",
    selected = defaults.useSort,
    onclick = function()
        local args <const> = dlg.data
        local useSort <const> = args.useSort --[[@as boolean]]
        dlg:modify { id = "sortPreset", visible = useSort }
        dlg:modify { id = "ascDesc", visible = useSort }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "sortPreset",
    label = "Criterion:",
    option = defaults.sortPreset,
    options = sortPresets,
    visible = defaults.useSort
}

dlg:newrow { always = false }

dlg:combobox {
    id = "ascDesc",
    label = "Order:",
    option = defaults.ascDesc,
    options = sortOrders,
    visible = defaults.useSort
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "OK",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local activeSprite = site.sprite
        if not activeSprite then
            local newSpec <const> = AseUtilities.createSpec()
            activeSprite = AseUtilities.createSprite(newSpec, "Palettes")
            AseUtilities.setPalette({ 0x00000000 }, activeSprite, 1)
        end

        local spec <const> = activeSprite.spec
        local colorMode <const> = spec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        AseUtilities.preserveForeBack()

        local spriteFrames <const> = activeSprite.frames
        local spritePalettes <const> = activeSprite.palettes
        local activeFrame = site.frame
        if not activeFrame then
            activeFrame = spriteFrames[1]
        end

        local args <const> = dlg.data
        local aPalType <const> = args.aPalType --[[@as string]]
        local bPalType <const> = args.bPalType --[[@as string]]
        local uniquesOnly <const> = args.uniquesOnly --[[@as boolean]]
        local prependMask <const> = args.prependMask --[[@as boolean]]

        local aPal = nil
        if aPalType == "FILE" then
            local aPalFile = args.aPalFile --[[@as string]]
            if aPalFile and #aPalFile > 0 then
                local candidate <const> = Palette { fromFile = aPalFile }
                if candidate then
                    aPal = candidate
                else
                    app.alert {
                        title = "Error",
                        text = "Palette A could not be found."
                    }
                    return
                end
            else
                app.alert {
                    title = "Error",
                    text = "Invalid path for palette A."
                }
                return
            end
        else
            aPal = AseUtilities.getPalette(
                activeFrame, spritePalettes)
        end

        local bPal = nil
        if bPalType == "FILE" then
            local bPalFile = args.bPalFile --[[@as string]]
            if bPalFile and #bPalFile > 0 then
                local candidate <const> = Palette { fromFile = bPalFile }
                if candidate then
                    bPal = candidate
                else
                    app.alert {
                        title = "Error",
                        text = "Palette B could not be found."
                    }
                    return
                end
            else
                app.alert {
                    title = "Error",
                    text = "Invalid path for palette B."
                }
                return
            end
        else
            bPal = AseUtilities.getPalette(
                activeFrame, spritePalettes)
        end

        -- Cache methods used in loops.
        local hexToAseColor <const> = AseUtilities.hexToAseColor
        local aseColorToHex <const> = AseUtilities.aseColorToHex

        ---@type integer[]
        local cArr <const> = {}
        local aLen <const> = #aPal
        local bLen <const> = #bPal
        local rgbColorMode <const> = ColorMode.RGB

        if uniquesOnly then
            ---@type table<integer, integer>
            local cDict <const> = {}
            local idxDict = 0

            -- Find colors from palette A.
            local i = 0
            while i < aLen do
                local aAseColor <const> = aPal:getColor(i)
                local aHex = aseColorToHex(aAseColor, rgbColorMode)
                if aHex & 0xff000000 == 0 then aHex = 0 end
                if not cDict[aHex] then
                    idxDict = idxDict + 1
                    cDict[aHex] = idxDict
                end
                i = i + 1
            end

            -- Find colors from palette B.
            local j = 0
            while j < bLen do
                local bAseColor <const> = bPal:getColor(j)
                local bHex = aseColorToHex(bAseColor, rgbColorMode)
                if bHex & 0xff000000 == 0 then bHex = 0 end
                if not cDict[bHex] then
                    idxDict = idxDict + 1
                    cDict[bHex] = idxDict
                end
                j = j + 1
            end

            -- Convert dictionary to array.
            for k, v in pairs(cDict) do
                cArr[v] = k
            end
        else
            local cIdx = 0

            -- Find colors from palette A.
            local i = 0
            while i < aLen do
                local aAseColor <const> = aPal:getColor(i)
                local aHex = aseColorToHex(aAseColor, rgbColorMode)
                if aHex & 0xff000000 == 0 then aHex = 0 end
                cIdx = cIdx + 1
                cArr[cIdx] = aHex
                i = i + 1
            end

            -- Find colors from palette B.
            local j = 0
            while j < bLen do
                local bAseColor <const> = bPal:getColor(j)
                local bHex = aseColorToHex(bAseColor, rgbColorMode)
                if bHex & 0xff000000 == 0 then bHex = 0 end
                cIdx = cIdx + 1
                cArr[cIdx] = bHex
                j = j + 1
            end
        end

        -- This cannot be generalized to the same logic as in
        -- paletteManifest, because in that case many color
        -- representations are loaded into a table.
        local useSort <const> = args.useSort --[[@as boolean]]
        if useSort then
            local sortPreset <const> = args.sortPreset
                or defaults.sortPreset --[[@as string]]
            local compare = nil
            if sortPreset == "GREEN_RED" then
                compare = function(a, b)
                    local aLab <const> = Clr.sRgbToSrLab2(Clr.fromHexAbgr32(a))
                    local bLab <const> = Clr.sRgbToSrLab2(Clr.fromHexAbgr32(b))
                    return aLab.a < bLab.a
                end
            elseif sortPreset == "ALPHA" then
                compare = function(a, b)
                    local aClr <const> = Clr.fromHexAbgr32(a)
                    local bClr <const> = Clr.fromHexAbgr32(b)
                    return aClr.a < bClr.a
                end
            elseif sortPreset == "BLUE_YELLOW" then
                compare = function(a, b)
                    local aLab <const> = Clr.sRgbToSrLab2(Clr.fromHexAbgr32(a))
                    local bLab <const> = Clr.sRgbToSrLab2(Clr.fromHexAbgr32(b))
                    return aLab.b < bLab.b
                end
            elseif sortPreset == "CHROMA" then
                compare = function(a, b)
                    local aClr <const> = Clr.fromHexAbgr32(a)
                    local bClr <const> = Clr.fromHexAbgr32(b)
                    local aIsGray <const> = aClr.r == aClr.g and aClr.g == aClr.b
                    local bIsGray <const> = bClr.r == bClr.g and bClr.g == bClr.b
                    local aLch <const> = Clr.sRgbToSrLch(aClr)
                    local bLch <const> = Clr.sRgbToSrLch(bClr)
                    if aIsGray and bIsGray then return aLch.l < bLch.l end
                    return aLch.c < bLch.c
                end
            elseif sortPreset == "HUE" then
                compare = function(a, b)
                    local aClr <const> = Clr.fromHexAbgr32(a)
                    local bClr <const> = Clr.fromHexAbgr32(b)
                    local aIsGray <const> = aClr.r == aClr.g and aClr.g == aClr.b
                    local bIsGray <const> = bClr.r == bClr.g and bClr.g == bClr.b
                    local aLch <const> = Clr.sRgbToSrLch(aClr)
                    local bLch <const> = Clr.sRgbToSrLch(bClr)
                    if aIsGray and bIsGray then return aLch.l < bLch.l end
                    if aIsGray then return true end
                    if bIsGray then return false end
                    return aLch.h < bLch.h
                end
            elseif sortPreset == "LUMA" then
                compare = function(a, b)
                    local aLab <const> = Clr.sRgbToSrLab2(Clr.fromHexAbgr32(a))
                    local bLab <const> = Clr.sRgbToSrLab2(Clr.fromHexAbgr32(b))
                    return aLab.l < bLab.l
                end
            end

            table.sort(cArr, compare)

            local ascDesc <const> = args.ascDesc
                or defaults.ascDesc --[[@as string]]
            if ascDesc == "DESCENDING" then
                Utilities.reverseTable(cArr)
            end
        end

        if prependMask then
            Utilities.prependMask(cArr)
        end

        local cPal <const> = AseUtilities.getPalette(
            activeFrame, spritePalettes)
        local cLen <const> = #cArr

        app.transaction("Concatenate palettes", function()
            cPal:resize(cLen)

            local k = 0
            while k < cLen do
                k = k + 1
                local cHex <const> = cArr[k]
                local cAseColor <const> = hexToAseColor(cHex)
                cPal:setColor(k - 1, cAseColor)
            end
        end)

        app.refresh()

        local colorSpace = spec.colorSpace
        if colorSpace ~= ColorSpace { sRGB = true } then
            app.alert {
                title = "Warning",
                text = {
                    "Sprite uses a custom color profile.",
                    "Palette may not appear as intended."
                }
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
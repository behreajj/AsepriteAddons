dofile("../../../support/aseutilities.lua")

local removeLayerOptions <const> = { "ACTIVE", "ALL", "NONE", "RANGE" }
local removeCelOptions <const> = { "ACTIVE", "ALL", "NONE", "RANGE" }
local removeImageOptions <const> = { "ACTIVE", "ALL", "NONE", "RANGE" }
local removeTilesOptions <const> = { "ACTIVE", "ALL", "NONE" }
local removePalOptions <const> = { "ACTIVE", "ALL", "NONE" }

local defaults <const> = {
    includeLocked = true,
    includeHidden = true,
    includeTiles = true,
    includeBkg = true,
    absOpaque = false,
    removeNonActive = false,
    removeTools = false,
    removeLayer = "ALL",
    removeCel = "ALL",
    removePalette = "ALL",
    removeImage = "ALL",
    removeTiles = "ALL",
    threshold = 128,
    usePremul = true,
}

---@param srcImg Image
---@param threshold integer
---@param absOpaque boolean
---@param usePremul boolean
---@return Image
---@nodiscard
local function opaque(srcImg, threshold, absOpaque, usePremul)
    local bytes <const> = srcImg.bytes

    local spec <const> = srcImg.spec
    local colorMode <const> = spec.colorMode
    local w <const> = spec.width
    local h <const> = spec.height

    local strbyte <const> = string.byte
    local strpack <const> = string.pack

    ---@type string[]
    local strBytes <const> = {}
    local len <const> = w * h

    if colorMode == ColorMode.RGB then
        local i = 0
        while i < len do
            local i4 <const> = i * 4

            local r8, g8, b8, a8 = strbyte(bytes, 1 + i4, 4 + i4)
            if usePremul then
                r8 = (r8 * a8) // 255
                g8 = (g8 * a8) // 255
                b8 = (b8 * a8) // 255
            end

            if a8 < threshold then
                r8, g8, b8, a8 = 0, 0, 0, 0
            else
                a8 = 255
            end

            a8 = absOpaque and 255 or a8

            i = i + 1
            strBytes[i] = strpack("B B B B", r8, g8, b8, a8)
        end
    elseif colorMode == ColorMode.GRAY then
        local i = 0
        while i < len do
            local i2 <const> = i + i

            local v8, a8 = strbyte(bytes, 1 + i2, 2 + i2)
            if usePremul then
                v8 = (v8 * a8) // 255
            end

            if a8 < threshold then
                v8, a8 = 0, 0
            else
                a8 = 255
            end

            a8 = absOpaque and 255 or a8

            i = i + 1
            strBytes[i] = strpack("B B", v8, a8)
        end
    end

    local trgImg <const> = Image(srcImg.spec)
    trgImg.bytes = table.concat(strBytes)
    return trgImg
end

local dlg <const> = Dialog { title = "Remove Alpha" }

dlg:check {
    id = "includeLocked",
    label = "Include:",
    text = "&Locked",
    selected = defaults.includeLocked,
    hexpand = false,
}

dlg:check {
    id = "includeHidden",
    text = "&Hidden",
    selected = defaults.includeHidden,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "includeTiles",
    text = "&Tiles",
    selected = defaults.includeTiles,
    hexpand = false,
}

dlg:check {
    id = "includeBkg",
    text = "&Background",
    selected = defaults.includeBkg,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "removeNonActive",
    text = "&Inactive",
    selected = defaults.removeNonActive,
    visible = false,
    hexpand = false,
}

dlg:check {
    id = "removeTools",
    text = "Tool&s",
    selected = defaults.removeTools,
    hexpand = false,
}

dlg:check {
    id = "absOpaque",
    text = "&Mask",
    selected = defaults.absOpaque,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "removeLayer",
    label = "Layers:",
    option = defaults.removeLayer,
    options = removeLayerOptions
}

dlg:newrow { always = false }

dlg:combobox {
    id = "removeCel",
    label = "Cels:",
    option = defaults.removeCel,
    options = removeCelOptions
}

dlg:newrow { always = false }

dlg:combobox {
    id = "removePalette",
    label = "Palettes:",
    option = defaults.removePalette,
    options = removePalOptions
}

dlg:newrow { always = false }

dlg:combobox {
    id = "removeImage",
    label = "Images:",
    option = defaults.removeImage,
    options = removeImageOptions,
    onchange = function()
        local args <const> = dlg.data
        local removeImage <const> = args.removeImage --[[@as string]]
        local removeTiles <const> = args.removeTiles --[[@as string]]
        local notNone <const> = removeImage ~= "NONE"
            or removeTiles ~= "NONE"
        dlg:modify { id = "threshold", visible = notNone }
        dlg:modify { id = "usePremul", visible = notNone }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "removeTiles",
    label = "Tiles:",
    option = defaults.removeTiles,
    options = removeTilesOptions,
    onchange = function()
        local args <const> = dlg.data
        local removeImage <const> = args.removeImage --[[@as string]]
        local removeTiles <const> = args.removeTiles --[[@as string]]
        local notNone <const> = removeImage ~= "NONE"
            or removeTiles ~= "NONE"
        dlg:modify { id = "threshold", visible = notNone }
        dlg:modify { id = "usePremul", visible = notNone }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "threshold",
    label = "Threshold:",
    min = 0,
    max = 255,
    value = defaults.threshold,
    visible = defaults.removeImage ~= "NONE"
        or defaults.removeTiles ~= "NONE"
}

dlg:newrow { always = false }

dlg:check {
    id = "usePremul",
    text = "&Premultiply",
    selected = defaults.usePremul,
    visible = defaults.removeImage ~= "NONE"
        or defaults.removeTiles ~= "NONE",
    hexpand = false,
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = true,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        local alphaIndex <const> = spriteSpec.transparentColor
        local notIndexed <const> = colorMode ~= ColorMode.INDEXED

        local args <const> = dlg.data
        local includeLocked <const> = args.includeLocked --[[@as boolean]]
        local includeHidden <const> = args.includeHidden --[[@as boolean]]
        local includeTiles <const> = args.includeTiles --[[@as boolean]]
        local includeBkg <const> = args.includeBkg --[[@as boolean]]
        local removeNonActive <const> = args.removeNonActive --[[@as boolean]]
        local removeTools <const> = args.removeTools --[[@as boolean]]
        local absOpaque <const> = args.absOpaque --[[@as boolean]]

        local opaqueLayer <const> = args.removeLayer
            or defaults.removeLayer --[[@as string]]
        local opaqueCel <const> = args.removeCel
            or defaults.removeCel --[[@as string]]
        local opaqueImage <const> = args.removeImage
            or defaults.removeImage --[[@as string]]
        local opaqueTiles <const> = args.removeTiles
            or defaults.removeTiles --[[@as string]]
        local opaquePalette <const> = args.removePalette
            or defaults.removePalette --[[@as boolean]]

        if opaqueLayer ~= "NONE" then
            -- TODO: As of 1.3.10 beta, this also has to do groups.
            -- See app.preferences.experimental.new_blend . Is it worth
            -- making a filterGroups function?

            local chosenLayers <const> = AseUtilities.filterLayers(
                activeSprite, site.layer, opaqueLayer, includeLocked,
                includeHidden, includeTiles, false)
            local lenChosenLayers <const> = #chosenLayers

            if lenChosenLayers > 0 then
                app.transaction("Opaque Layers", function()
                    local i = 0
                    while i < lenChosenLayers do
                        i = i + 1
                        chosenLayers[i].opacity = 255
                    end
                end)
            end
        end

        if opaqueCel ~= "NONE" then
            local chosenCels <const> = AseUtilities.filterCels(
                activeSprite, site.layer, activeSprite.frames, opaqueCel,
                includeLocked, includeHidden, includeTiles, false)
            local lenChosenCels <const> = #chosenCels

            if lenChosenCels > 0 then
                app.transaction("Opaque Cels", function()
                    local i = 0
                    while i < lenChosenCels do
                        i = i + 1
                        chosenCels[i].opacity = 255
                    end
                end)
            end
        end

        if opaqueImage ~= "NONE" and notIndexed then
            -- Target background layers as a precaution, since a script
            -- could introduce translucent colors to an image in a background.
            local chosenCels <const> = AseUtilities.filterCels(
                activeSprite, site.layer, activeSprite.frames, opaqueImage,
                includeLocked, includeHidden, false, includeBkg)
            local lenChosenCels <const> = #chosenCels

            if lenChosenCels > 0 then
                local threshold <const> = args.threshold
                    or defaults.threshold --[[@as integer]]
                local usePremul <const> = args.usePremul --[[@as boolean]]
                local trimImage <const> = AseUtilities.trimImageAlpha
                app.transaction("Opaque Images", function()
                    local i = 0
                    while i < lenChosenCels do
                        i = i + 1
                        local cel <const> = chosenCels[i]
                        local opaqueImg <const> = opaque(cel.image, threshold,
                            absOpaque, usePremul)
                        if absOpaque then
                            cel.image = opaqueImg
                        else
                            local srcPos <const> = cel.position
                            local trimmed <const>,
                            xTrm <const>,
                            yTrm <const> = trimImage(opaqueImg, 0, alphaIndex)
                            cel.image = trimmed
                            cel.position = Point(srcPos.x + xTrm, srcPos.y + yTrm)
                        end
                    end -- End chosen cels loop.
                end)    -- End transaction.
            end         -- End chosen cels gt zero.
        end             -- End opaque images.

        if opaqueTiles ~= "NONE" and notIndexed then
            local chosenTileSets = {}
            if opaqueTiles == "ALL" then
                chosenTileSets = activeSprite.tilesets
            else
                -- Default to active tile set.
                local activeLayer <const> = site.layer
                if activeLayer
                    and activeLayer.isTilemap
                    and activeLayer.tileset then
                    chosenTileSets[1] = activeLayer.tileset
                end
            end
            local lenChosenTileSets <const> = #chosenTileSets

            if lenChosenTileSets > 0 then
                local threshold <const> = args.threshold
                    or defaults.threshold --[[@as integer]]
                local usePremul <const> = args.usePremul --[[@as boolean]]
                app.transaction("Opaque Tiles", function()
                    local i = 0
                    while i < lenChosenTileSets do
                        i = i + 1
                        local tileSet <const> = chosenTileSets[i]
                        local lenTileSet <const> = #tileSet

                        -- Skip initial tile.
                        local j = 1
                        while j < lenTileSet do
                            local tile <const> = tileSet:tile(j)
                            if tile then
                                tile.image = opaque(tile.image, threshold,
                                    absOpaque, usePremul)
                            end
                            j = j + 1
                        end -- End tile loop.
                    end     -- End tile sets loop.
                end)        -- End transaction.
            end             -- End chosen tile sets gt zero.
        end                 -- End opaque tiles.

        if opaquePalette ~= "NONE" then
            local chosenPalettes = {}
            if opaquePalette == "ALL" then
                chosenPalettes = activeSprite.palettes
            else
                -- Default to active palette.
                local activeFrame <const> = site.frame
                if activeFrame then
                    local pal <const> = AseUtilities.getPalette(
                        activeFrame, activeSprite.palettes)
                    chosenPalettes[1] = pal
                end
            end
            local lenChosenPalettes <const> = #chosenPalettes

            if lenChosenPalettes > 0 then
                app.transaction("Opaque Palette", function()
                    if colorMode == ColorMode.INDEXED then
                        -- For indexed color mode, avoid changing the sprite
                        -- transparent color index.

                        local i = 0
                        while i < lenChosenPalettes do
                            i = i + 1
                            local palette <const> = chosenPalettes[i]
                            local lenPalette <const> = #palette

                            local j = 0
                            while j < lenPalette do
                                if j ~= alphaIndex then
                                    local aseColor <const> = palette:getColor(j)
                                    palette:setColor(j, Color {
                                        r = aseColor.red,
                                        g = aseColor.green,
                                        b = aseColor.blue,
                                        a = 255
                                    })
                                end
                                j = j + 1
                            end -- End palette color loop.
                        end     -- End sprite palettes loop.
                    else
                        -- For RGB and grayscale mode, do not remove initial
                        -- alpha mask, if any.

                        local i = 0
                        while i < lenChosenPalettes do
                            i = i + 1
                            local palette <const> = chosenPalettes[i]
                            local lenPalette <const> = #palette

                            local firstColor <const> = palette:getColor(0)
                            local firstHex <const> = AseUtilities.aseColorToHex(
                                firstColor, colorMode)
                            if firstHex ~= 0 then
                                palette:setColor(0, Color {
                                    r = firstColor.red,
                                    g = firstColor.green,
                                    b = firstColor.blue,
                                    a = 255
                                })
                            end

                            local j = 1
                            while j < lenPalette do
                                local aseColor <const> = palette:getColor(j)
                                palette:setColor(j, Color {
                                    r = aseColor.red,
                                    g = aseColor.green,
                                    b = aseColor.blue,
                                    a = 255
                                })
                                j = j + 1
                            end -- End palette color loop.
                        end     -- End sprite palettes loop.
                    end         -- End color mode check.
                end)            -- End transaction.
            end                 -- More than zero palette check.
        end                     -- End remove palette check.

        if removeNonActive then
            local appPrefs <const> = app.preferences
            if appPrefs then
                local experimental <const> = appPrefs.experimental
                if experimental then
                    if experimental.nonactive_layers_opacity then
                        experimental.nonactive_layers_opacity = 255
                    end
                    if experimental.nonactive_layers_opacity_preview then
                        experimental.nonactive_layers_opacity_preview = 255
                    end
                end -- End experimental exists.
            end     -- End app prefs exists.
        end         -- End remove non active layers.

        if removeTools then
            local appPrefs <const> = app.preferences
            if appPrefs then
                -- Preferences seem to read and write as 255, regardless of UI.
                -- local maxOpacity = 255
                -- local maxPref <const> = appPrefs.range
                -- if maxPref then
                --     local opacPref <const> = maxPref.opacity
                --     if opacPref and opacPref == 1 then
                --         maxOpacity = 100
                --     end
                -- end

                local toolsWithAlpha <const> = {
                    "pencil", "spray", "eraser", "paint_bucket", "gradient",
                    "contour", "polygon", "blur", "jumble"
                }
                local lenToolsWithAlpha <const> = #toolsWithAlpha

                local i = 0
                while i < lenToolsWithAlpha do
                    i = i + 1
                    local tool <const> = toolsWithAlpha[i]
                    local toolPref <const> = appPrefs.tool(tool)
                    if toolPref and toolPref.opacity then
                        -- print(string.format("\"%s\": %d", tool, toolPref.opacity))
                        toolPref.opacity = 255
                    end -- End pref has opacity.
                end     -- End tools loop.
            end         -- End app prefs exists.
        end             -- End remove tool opacity.

        app.refresh()
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
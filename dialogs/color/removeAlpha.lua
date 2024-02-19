---@param srcImg Image
---@param absOpaque boolean
---@return Image
local function opaque(srcImg, absOpaque)
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

            local r8 = 0
            local g8 = 0
            local b8 = 0
            local a8 = strbyte(bytes, 4 + i4, 4 + i4)

            if absOpaque or a8 > 0 then
                r8 = strbyte(bytes, 1 + i4, 1 + i4)
                g8 = strbyte(bytes, 2 + i4, 2 + i4)
                b8 = strbyte(bytes, 3 + i4, 3 + i4)
                a8 = 255
            end

            i = i + 1
            strBytes[i] = strpack("B B B B", r8, g8, b8, a8)
        end
    elseif colorMode == ColorMode.GRAY then
        local i = 0
        while i < len do
            local i2 <const> = i * 2

            local v8 = 0
            local a8 = strbyte(bytes, 2 + i2, 2 + i2)

            if absOpaque or a8 > 0 then
                v8 = strbyte(bytes, 1 + i2, 1 + i2)
                a8 = 255
            end

            i = i + 1
            strBytes[i] = strpack("B B", v8, a8)
        end
    end

    local trgImg <const> = Image(srcImg.spec)
    trgImg.bytes = table.concat(strBytes)
    return trgImg
end

local defaults <const> = {
    -- TODO: Replace these with target options comboboxes for each category?
    removeLayer = true,
    removeCel = true,
    removeImage = true,
    removeTiles = true,
    removePalette = true
}

local dlg <const> = Dialog { title = "Remove Alpha" }

dlg:check {
    id = "removeLayer",
    label = "Change:",
    text = "&Layer",
    focus = false,
    selected = defaults.removeLayer
}

dlg:check {
    id = "removeCel",
    text = "C&el",
    focus = false,
    selected = defaults.removeCel
}

dlg:newrow { always = false }

dlg:check {
    id = "removeImage",
    text = "&Image",
    focus = false,
    selected = defaults.removeImage
}

dlg:check {
    id = "removeTiles",
    text = "&Tiles",
    focus = false,
    selected = defaults.removeTiles
}

dlg:newrow { always = false }

dlg:check {
    id = "removePalette",
    text = "&Palette",
    focus = false,
    selected = defaults.removePalette
}

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

        local args <const> = dlg.data
        local opaqueLayer <const> = args.removeLayer --[[@as boolean]]
        local opaqueCel <const> = args.removeCel --[[@as boolean]]
        local opaqueImage <const> = args.removeImage --[[@as boolean]]
        local opaqueTiles <const> = args.removeTiles --[[@as boolean]]
        local opaquePalette <const> = args.removePalette --[[@as boolean]]

        if opaqueLayer then
            local chosenLayers = AseUtilities.getLayerHierarchy(
                activeSprite, true, true, true, false)
            local lenChosenLayers <const> = #chosenLayers

            if lenChosenLayers > 0 then
                app.transaction("Opaque Layers", function()
                    local i = 0
                    while i < lenChosenLayers do
                        i = i + 1
                        local layer <const> = chosenLayers[i]
                        layer.opacity = 255
                    end
                end)
            end
        end

        if opaqueCel then
            local chosenCels <const> = AseUtilities.filterCels(
                activeSprite, site.layer, site.frame, "ALL",
                true, true, true, false)
            local lenChosenCels <const> = #chosenCels

            if lenChosenCels > 0 then
                app.transaction("Opaque Cels", function()
                    local i = 0
                    while i < lenChosenCels do
                        i = i + 1
                        local cel <const> = chosenCels[i]
                        cel.opacity = 255
                    end
                end)
            end
        end

        if opaqueImage and colorMode ~= ColorMode.INDEXED then
            local chosenCels <const> = AseUtilities.filterCels(
                activeSprite, site.layer, site.frame, "ALL",
                true, true, false, false)
            local lenChosenCels <const> = #chosenCels

            if lenChosenCels > 0 then
                app.transaction("Opaque Images", function()
                    local i = 0
                    while i < lenChosenCels do
                        i = i + 1
                        local cel <const> = chosenCels[i]
                        cel.image = opaque(cel.image, false)
                    end
                end)
            end
        end

        if opaqueTiles and colorMode ~= ColorMode.INDEXED then
            local chosenTileSets = activeSprite.tilesets
            local lenChosenTileSets <const> = #chosenTileSets

            if lenChosenTileSets > 0 then
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
                                tile.image = opaque(tile.image, false)
                            end
                            j = j + 1
                        end
                    end
                end)
            end
        end

        if opaquePalette then
            local chosenPalettes = activeSprite.palettes
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
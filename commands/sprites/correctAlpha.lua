dofile("../../support/aseutilities.lua")

if app.fgColor.alpha <= 0 then
    app.fgColor = Color { r = 0, g = 0, b = 0, a = 0 }
end

app.command.SwitchColors()
if app.fgColor.alpha <= 0 then
    app.fgColor = Color { r = 0, g = 0, b = 0, a = 0 }
end
app.command.SwitchColors()

local sprite <const> = app.site.sprite
if not sprite then return end

local spriteSpec <const> = sprite.spec
local colorMode <const> = spriteSpec.colorMode

local aseClearBlack <const> = Color { r = 0, g = 0, b = 0, a = 0 }
local palettes <const> = sprite.palettes
local lenPalettes <const> = #palettes

app.transaction("Correct Alpha Palette", function()
    local f = 0
    while f < lenPalettes do
        f = f + 1
        local palette <const> = palettes[f]
        local lenPalette <const> = #palette
        local g = 0
        while g < lenPalette do
            if palette:getColor(g).alpha <= 0 then
                palette:setColor(g, aseClearBlack)
            end
            g = g + 1
        end
    end
end)

if colorMode == ColorMode.INDEXED then
    app.refresh()
    return
end

-- This has to get unique cels prior to changing cel images,
-- otherwise images within linked cels will not be recognized.
local leaves <const> = AseUtilities.getLayerHierarchy(sprite,
    true, true, false, false)
local cels <const> = AseUtilities.getUniqueCelsFromLeaves(
    leaves, sprite.frames)
local lenCels <const> = #cels
local correctZero <const> = AseUtilities.correctZeroAlpha

if lenCels > 0 then
    app.transaction("Correct Alpha Cels", function()
        local i = 0
        while i < lenCels do
            i = i + 1
            local cel <const> = cels[i]
            cel.image = correctZero(cel.image)
        end
    end)
end

local tileSets <const> = sprite.tilesets
local lenTileSets <const> = #tileSets
if lenTileSets <= 0 then
    app.refresh()
    return
end

app.transaction("Correct Alpha Tiles", function()
    local j = 0
    while j < lenTileSets do
        j = j + 1
        local tileSet <const> = tileSets[j]
        local lenTileSet <const> = #tileSet
        local k = 0
        while k < lenTileSet do
            local tile <const> = tileSet:tile(k)
            if tile then
                tile.image = correctZero(tile.image)
            end
            k = k + 1
        end
    end
end)

app.refresh()
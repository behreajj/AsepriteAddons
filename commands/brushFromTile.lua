dofile("../support/aseutilities.lua")

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local layer <const> = site.layer
if not layer then return end
if not layer.isTilemap then return end

local tileSet <const> = layer.tileset
if not tileSet then return end
local lenTileSet <const> = #tileSet

local tifCurr <const> = app.fgTile
local tiCurr <const> = app.pixelColor.tileI(tifCurr)

if tiCurr < 0 or tiCurr >= lenTileSet then
    return
end

local tile <const> = tileSet:tile(tiCurr)
if not tile then return end

local image <const> = tile.image
local tfCurr <const> = app.pixelColor.tileF(tifCurr)
local flipped <const> = AseUtilities.bakeFlag(image, tfCurr)

if not flipped:isEmpty() then
    app.transaction("Brush From Tile", function()
        AseUtilities.setBrush(AseUtilities.imageToBrush(
            flipped))
    end)
end

app.refresh()
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

if not image:isEmpty() then
    local tfCurr <const> = app.pixelColor.tileF(tifCurr)
    local flipped <const> = AseUtilities.bakeFlag(image, tfCurr)

    local centerPreset = "CENTER"
    local brushPattern = BrushPattern.NONE
    local xPattern = 0
    local yPattern = 0

    -- local cel <const> = site.cel
    -- if cel then
    --     local celPos <const> = cel.position
    --     xPattern = celPos.x
    --     yPattern = celPos.y
    -- end

    -- Problem is that the brush's foreground and background
    -- color can be updated such that the brush no longer uses
    -- colors native to the image. This also happens to brush
    -- from mask. Setting brush fgColor and bgColor manually does
    -- not help the problem. Color mode of color bar fore color
    -- doesn't seem to matter. Brush must be saved for color to
    -- be fixed.
    app.transaction("Brush From Tile", function()
        local brush <const> = AseUtilities.imageToBrush(
            flipped, centerPreset,
            brushPattern, xPattern, yPattern)
        AseUtilities.setBrush(brush)
    end)
end

app.refresh()
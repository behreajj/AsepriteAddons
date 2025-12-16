local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local activeLayer <const> = site.layer
    or activeSprite.layers[1]

if not activeLayer.isTilemap then return end

local srcTileSet <const> = activeLayer.tileset
if not srcTileSet then return end

math.randomseed(os.time())
local minint64 <const> = 0x1000000000000000
local maxint64 <const> = 0x7fffffffffffffff
local trgTsId <const> = math.random(minint64, maxint64)

app.transaction("Unique Tileset", function()
    local trgTileSet <const> = activeSprite:newTileset(srcTileSet)
    trgTileSet.properties["id"] = trgTsId
    -- if #trgTileSet.name <= 0 then
    trgTileSet.name = string.format("%16x", trgTsId)
    -- else
    -- trgTileSet.name = trgTileSet.name .. " Copy"
    -- end
    activeLayer.tileset = trgTileSet
end)

app.refresh()
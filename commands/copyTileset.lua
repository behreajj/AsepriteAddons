local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local activeLayer <const> = site.layer
    or activeSprite.layers[1]

if not activeLayer.isTilemap then return end

local srcTileSet <const> = activeLayer.tileset
if not srcTileSet then return end

local trgTileSet <const> = activeSprite:newTileset(srcTileSet)

math.randomseed(os.time())
local minint64 <const> = 0x1000000000000000
local maxint64 <const> = 0x7fffffffffffffff
local trgTsId <const> = math.random(minint64, maxint64)
trgTileSet.properties["id"] = trgTsId

app.transaction("Rename Tile Set", function()
    -- if #trgTileSet.name <= 0 then
    trgTileSet.name = string.format("%16x", trgTsId)
    -- else
    -- trgTileSet.name = trgTileSet.name .. " (Copy)"
    -- end
end)

local response <const> = app.alert {
    title = "Query",
    text = "Set active layer tile set to copy?",
    buttons = { "YES", "NO" }
}

if response == 1 then
    app.transaction("Update Reference", function()
        activeLayer.tileset = trgTileSet
    end)
end
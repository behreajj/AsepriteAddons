dofile("../support/aseutilities.lua")

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local tileSets <const> = activeSprite.tilesets
local lenTileSets <const> = #tileSets
if lenTileSets <= 0 then return end

local strfmt <const> = string.format
local rng <const> = math.random
local verifName <const> = Utilities.validateFilename

math.randomseed(os.time())
local minint64 <const> = 0x1000000000000000
local maxint64 <const> = 0x7fffffffffffffff

---@type table<string, boolean>
local uniques = {}

app.transaction("Correct tile sets", function()
    local tileSum = 0
    local i = 0
    while i < lenTileSets do
        i = i + 1
        local tileSet <const> = tileSets[i]

        local tileId <const> = rng(minint64, maxint64)
        tileSet.properties["id"] = tileId

        local origName <const> = tileSet.name
        local tsNameVerif = ""
        if origName and #origName > 0 then
            tsNameVerif = verifName(origName)
        else
            tsNameVerif = strfmt("%16x", tileId)
        end

        local attempts = 0
        while (uniques[tsNameVerif] or #tsNameVerif <= 0)
            and attempts < 16 do
            local newTileId <const> = rng(minint64, maxint64)
            tileSet.properties["id"] = newTileId
            tsNameVerif = strfmt("%16x", newTileId)
            attempts = attempts + 1
        end

        uniques[tsNameVerif] = true
        tileSet.name = tsNameVerif

        -- Because Tiled uses a firstgid offset based on count of tile set
        -- references in a map, not in the tile set file itself, it's not as
        -- necessary to do this.
        tileSet.baseIndex = 1 + tileSum
        tileSum = tileSum + #tileSet
    end
end)

app.transaction("Remove unused tile sets", function()
    local leaves <const> = AseUtilities.getLayerHierarchy(
        activeSprite, true, true, true, false)
    local lenLeaves <const> = #leaves
    ---@type table<integer, boolean>
    local usedTileSets = {}
    local i = 0
    while i < lenLeaves do
        i = i + 1
        local leaf <const> = leaves[i]
        if leaf.isTilemap then
            local id <const> = leaf.tileset.properties["id"]
            usedTileSets[id] = true
        end
    end

    local j = lenTileSets + 1
    while j > 1 do
        j = j - 1
        local tileSet <const> = tileSets[j]
        if not usedTileSets[tileSet.properties.id] then
            activeSprite:deleteTileset(tileSet)
        end
    end
end)

app.refresh()
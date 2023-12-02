dofile("../support/utilities.lua")

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local tileSets <const> = activeSprite.tilesets
local lenTileSets <const> = #tileSets

local strfmt <const> = string.format
local rng <const> = math.random
local verifName <const> = Utilities.validateFilename

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

        local tileId = 0
        local tileSetProps <const> = tileSet.properties
        if tileSetProps["id"] then
            tileId = tileSetProps["id"] --[[@as integer]]
            tileSetProps["id"] = tileId
        else
            tileId = rng(minint64, maxint64)
            tileSet.properties["id"] = tileId
        end

        local origName <const> = tileSet.name
        local tsNameVerif = ""
        if origName and #origName > 0 then
            tsNameVerif = verifName(origName)
        else
            tsNameVerif = strfmt("%08x", tileId)
        end

        local attempts = 0
        while (uniques[tsNameVerif] or #tsNameVerif <= 0)
            and attempts < 16 do
            tsNameVerif = strfmt("%16x", tileId)
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

app.refresh()
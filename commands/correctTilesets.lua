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
    local i = 0
    while i < lenTileSets do
        i = i + 1
        local tileSet <const> = tileSets[i]
        local origName <const> = tileSet.name
        local tsNameVerif = ""
        if origName and #origName > 0 then
            tsNameVerif = verifName(origName)
        else
            tsNameVerif = strfmt("%08x", rng(1, maxint64))
        end

        local attempts = 0
        while (uniques[tsNameVerif] or #tsNameVerif <= 0)
            and attempts < 16 do
            tsNameVerif = strfmt("%16x", rng(minint64, maxint64))
            attempts = attempts + 1
        end

        uniques[tsNameVerif] = true
        tileSet.name = tsNameVerif
    end
end)

app.refresh()
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
local uniques <const> = {}

app.transaction("Correct tile sets", function()
    local i = 0
    while i < lenTileSets do
        i = i + 1
        local tileSet <const> = tileSets[i]

        local tsId <const> = rng(minint64, maxint64)
        tileSet.properties["id"] = tsId

        local origName <const> = tileSet.name
        local tsNameVerif = ""
        if origName and #origName > 0 then
            tsNameVerif = verifName(origName)
        else
            tsNameVerif = strfmt("%16x", tsId)
        end

        local attempts = 0
        while (uniques[tsNameVerif] or #tsNameVerif <= 0)
            and attempts < 16 do
            local newTsId <const> = rng(minint64, maxint64)
            tileSet.properties["id"] = newTsId
            tsNameVerif = strfmt("%16x", newTsId)
            attempts = attempts + 1
        end

        uniques[tsNameVerif] = true
        tileSet.name = tsNameVerif
    end
end)

local appPrefs <const> = app.preferences
if appPrefs then
    local tileMapPrefs <const> = appPrefs.tilemap
    if tileMapPrefs then
        if not tileMapPrefs.show_delete_unused_tileset_alert then
            app.transaction("Remove unused tile sets", function()
                local leaves <const> = AseUtilities.getLayerHierarchy(
                    activeSprite, true, true, true, false)
                local lenLeaves <const> = #leaves
                ---@type table<integer, boolean>
                local usedTileSets <const> = {}
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
        end
    end
end

app.refresh()
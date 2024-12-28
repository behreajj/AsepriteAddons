dofile("../../support/aseutilities.lua")

local openSprites <const> = app.sprites
local lenOpenSprites <const> = #openSprites
if lenOpenSprites <= 0 then return end

local site <const> = app.site
local srcSprite <const> = site.sprite
if not srcSprite then return end

local srcTileSets <const> = srcSprite.tilesets
local lenSrcTileSets <const> = #srcTileSets
if lenSrcTileSets <= 0 then return end

local appTool <const> = app.tool
if appTool then
    if appTool.id == "slice" then
        app.tool = "hand"
    end
end

AseUtilities.preserveForeBack()

local abs <const> = math.abs
local max <const> = math.max
local rng <const> = math.random
local strfmt <const> = string.format
local transact <const> = app.transaction
local colorCopy <const> = AseUtilities.aseColorCopy

---@type table[]
local packets <const> = {}
local lenPackets = 0

local h = 0
while h < lenSrcTileSets do
    h = h + 1
    local srcTileSet <const> = srcTileSets[h]
    local lenSrcTileSet <const> = #srcTileSet

    ---@type Image[]
    local tileImages <const> = {}
    local lenTileImages = 0

    local i = 0
    while i < lenSrcTileSet do
        i = i + 1
        local tile <const> = srcTileSet:tile(i)
        if tile then
            local image <const> = tile.image
            lenTileImages = lenTileImages + 1
            tileImages[lenTileImages] = image:clone()
        end
    end

    if lenTileImages > 0 then
        local baseIndex <const> = srcTileSet.baseIndex
        local aseColor <const> = colorCopy(srcTileSet.color, "UNBOUNDED")
        local grid <const> = srcTileSet.grid
        local name <const> = srcTileSet.name

        local gridOrigin <const> = grid.origin
        local gridSize <const> = grid.tileSize

        local xTile <const> = gridOrigin.x
        local yTile <const> = gridOrigin.y
        local wTile <const> = max(1, abs(gridSize.width))
        local hTile <const> = max(1, abs(gridSize.height))

        lenPackets = lenPackets + 1
        packets[lenPackets] = {
            aseColor = aseColor,
            baseIndex = baseIndex,
            name = name,
            tileImages = tileImages,
            xTile = xTile,
            yTile = yTile,
            wTile = wTile,
            hTile = hTile
        }
    end
end

math.randomseed(os.time())
local minint64 <const> = 0x1000000000000000
local maxint64 <const> = 0x7fffffffffffffff

local srcId <const> = srcSprite.id
local srcCm <const> = srcSprite.colorMode

local j = 0
while j < lenOpenSprites do
    j = j + 1
    local sprite <const> = openSprites[j]
    if srcId ~= sprite.id
        and srcCm == sprite.colorMode then
        app.sprite = sprite

        local k = 0
        while k < lenPackets do
            k = k + 1
            local packet <const> = packets[k]

            local aseColor <const> = packet.aseColor
            local baseIndex <const> = packet.baseIndex
            local srcName <const> = packet.name
            local tileImages <const> = packet.tileImages
            local xTile <const> = packet.xTile
            local yTile <const> = packet.yTile
            local wTile <const> = packet.wTile
            local hTile <const> = packet.hTile

            local tsId <const> = rng(minint64, maxint64)
            local lenTileImages <const> = #tileImages

            local trgTileSet <const> = sprite:newTileset(
                Rectangle(xTile, yTile, wTile, hTile),
                lenTileImages)

            local trgName = strfmt("%16x", tsId)
            if srcName and #srcName > 0 then
                trgName = srcName
            end

            transact(strfmt("Share Tile Set %s", trgName), function()
                trgTileSet.baseIndex = baseIndex
                trgTileSet.color = colorCopy(aseColor, "UNBOUNDED")
                trgTileSet.name = trgName
                trgTileSet.properties["id"] = tsId

                local m = 0
                while m < lenTileImages do
                    m = m + 1
                    local tile <const> = trgTileSet:tile(m)
                    if tile then
                        tile.image = tileImages[m]:clone()
                    end
                end
            end)
        end
    end
end

app.sprite = srcSprite
app.refresh()
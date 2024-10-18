dofile("../support/aseutilities.lua")

local sprite <const> = app.site.sprite
if not sprite then return end

local sprColorMode <const> = sprite.colorMode

local leaves <const> = AseUtilities.getLayerHierarchy(sprite,
    true, true, true, true)
local lenLeaves <const> = #leaves

local frObjs <const> = sprite.frames
local lenFrObjs <const> = #frObjs

local lenComp <const> = lenLeaves * lenFrObjs
local sizeThresh <const> = 256

local hash <const> = AseUtilities.hashImage
local tileMapToImage <const> = AseUtilities.tileMapToImage

---@type table<integer, Cel>
local dictionary <const> = {}

local original <const> = Color { r = 61, g = 86, b = 255, a = 170 }
local duplicate <const> = Color { r = 255, g = 0, b = 0, a = 170 }
local clear <const> = Color { r = 0, g = 0, b = 0, a = 0 }
local linked <const> = Color { r = 0, g = 137, b = 58, a = 170 }

app.transaction("Find Like Images", function()
    local h = 0
    while h < lenComp do
        local i <const> = h // lenLeaves
        local j <const> = h % lenLeaves
        local frObj <const> = frObjs[1 + i]
        local leaf <const> = leaves[1 + j]
        local isTilemap <const> = leaf.isTilemap
        local tileSet <const> = leaf.tileset
        local cel <const> = leaf:cel(frObj)
        if cel then
            local image = cel.image
            if isTilemap and tileSet then
                image = tileMapToImage(
                    image, tileSet, sprColorMode)
            end

            if not image:isEmpty() then
                local hsh64 <const> = hash(image, sizeThresh)

                if dictionary[hsh64] then
                    local origCel <const> = dictionary[hsh64]
                    if image.id == origCel.image.id then
                        cel.color = linked
                    else
                        cel.color = duplicate
                        origCel.color = original
                    end
                else
                    dictionary[hsh64] = cel
                    cel.color = clear
                end

                cel.properties["hash"] = hsh64
            end
        end
        h = h + 1
    end
end)

app.refresh()
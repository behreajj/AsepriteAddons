dofile("../support/aseutilities.lua")

local sprite <const> = app.site.sprite
if not sprite then return end

local palettes <const> = sprite.palettes

local leaves <const> = AseUtilities.getLayerHierarchy(sprite,
    true, true, true, true)
local lenLeaves <const> = #leaves

local frObjs <const> = sprite.frames
local lenFrObjs <const> = #frObjs

local lenComp <const> = lenLeaves * lenFrObjs

local fingerprint <const> = AseUtilities.fingerprint
local getPalette <const> = AseUtilities.getPalette

---@type table<integer, Cel>
local dictionary <const> = {}

local original <const> = Color { r = 0, g = 115, b = 129, a = 170 }
local duplicate <const> = Color { r = 255, g = 0, b = 0, a = 170 }

app.transaction("Show Duplicate Images", function()
    local k = 0
    while k < lenComp do
        local i <const> = k // lenLeaves
        local j <const> = k % lenLeaves
        local frObj <const> = frObjs[1 + i]
        local leaf <const> = leaves[1 + j]
        local cel <const> = leaf:cel(frObj)
        if cel then
            local palette <const> = getPalette(frObj, palettes)
            local image <const> = cel.image
            local hash <const> = fingerprint(image, palette)
            if dictionary[hash] then
                local origCel <const> = dictionary[hash]
                if image.id ~= origCel.image.id then
                    cel.color = duplicate
                    origCel.color = original
                end

            else
                dictionary[hash] = cel
            end
        end
        k = k + 1
    end
end)

app.refresh()
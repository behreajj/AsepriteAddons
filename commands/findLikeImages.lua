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

local fingerprint <const> = AseUtilities.fingerprintInternal
local getPalette <const> = AseUtilities.getPalette
local strpack <const> = string.pack

---@type table<integer, Cel>
local dictionary <const> = {}

local original <const> = Color { r = 61, g = 86, b = 255, a = 170 }
local duplicate <const> = Color { r = 255, g = 0, b = 0, a = 170 }
local clear <const> = Color { r = 0, g = 0, b = 0, a = 0 }
local linked<const> = Color { r = 0, g = 137, b = 58, a = 170 }

app.transaction("Find Like Images", function()
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
            local lfp <const>, afp <const>,
            bfp <const>, tfp <const> = fingerprint(image, palette)
            local hash <const> = strpack(
                "<I8 <I8 <I8 <I8",
                tfp, lfp, afp, bfp)
            if dictionary[hash] then
                local origCel <const> = dictionary[hash]
                if image.id == origCel.image.id then
                    cel.color = linked
                else
                    cel.color = duplicate
                    origCel.color = original
                end
            else
                dictionary[hash] = cel
                cel.color = clear
            end
        end
        k = k + 1
    end
end)

app.refresh()
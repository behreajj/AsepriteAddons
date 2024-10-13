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
local strfmt <const> = string.format
local strbyte <const> = string.byte
local tconcat <const> = table.concat

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
            local lfp <const>, afp <const>,
            bfp <const>, tfp <const> = fingerprint(image, palette)
            local hash <const> = strpack(
                "<I8 <I8 <I8 <I8",
                tfp, lfp, afp, bfp)
            if dictionary[hash] then
                local origCel <const> = dictionary[hash]
                if image.id ~= origCel.image.id then
                    cel.color = duplicate
                    origCel.color = original
                end
            else
                dictionary[hash] = cel
            end

            -- local lenHash <const> = #hash
            -- ---@type string[]
            -- local byteStrs <const> = {}
            -- local n = 0
            -- while n < lenHash do
            --     n = n + 1
            --     local byte <const> = strbyte(hash, n)
            --     byteStrs[n] = strfmt("%02x", byte)
            -- end
            -- cel.properties["fingerprint"] = tconcat(byteStrs)
        end
        k = k + 1
    end
end)

app.refresh()
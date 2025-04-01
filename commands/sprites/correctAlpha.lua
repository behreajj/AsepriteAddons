dofile("../../support/aseutilities.lua")

if app.fgColor.alpha <= 0 then
    app.fgColor = Color { r = 0, g = 0, b = 0, a = 0 }
end

app.command.SwitchColors()
if app.fgColor.alpha <= 0 then
    app.fgColor = Color { r = 0, g = 0, b = 0, a = 0 }
end
app.command.SwitchColors()

local sprite <const> = app.site.sprite
if not sprite then return end

local spriteSpec <const> = sprite.spec
local colorMode <const> = spriteSpec.colorMode

local aseClearBlack <const> = Color { r = 0, g = 0, b = 0, a = 0 }
local palettes <const> = sprite.palettes
local lenPalettes <const> = #palettes

app.transaction("Correct Zero Alpha Palette", function()
    local f = 0
    while f < lenPalettes do
        f = f + 1
        local palette <const> = palettes[f]
        local lenPalette <const> = #palette
        local g = 0
        while g < lenPalette do
            if palette:getColor(g).alpha <= 0 then
                palette:setColor(g, aseClearBlack)
            end
            g = g + 1
        end
    end
end)

if colorMode == ColorMode.INDEXED then
    app.refresh()
    return
end

local leaves <const> = AseUtilities.getLayerHierarchy(sprite,
    true, true, false, false)
local lenLeaves <const> = #leaves
local frObjs <const> = sprite.frames
local lenFrObjs <const> = #frObjs
local lenComp <const> = lenLeaves * lenFrObjs

---@type table<integer, boolean>
local visited <const> = {}
local correctZero <const> = AseUtilities.correctZeroAlpha

app.transaction("Correct Zero Alpha Cels", function()
    local h = 0
    while h < lenComp do
        local i <const> = h // lenLeaves
        local j <const> = h % lenLeaves
        local frObj <const> = frObjs[1 + i]
        local leaf <const> = leaves[1 + j]

        local cel <const> = leaf:cel(frObj)
        if cel then
            local srcImg <const> = cel.image
            local idSrc <const> = srcImg.id
            if not visited[idSrc] then
                cel.image = correctZero(srcImg)
                visited[idSrc] = true
            end
        end
        h = h + 1
    end
end)

local tileSets <const> = sprite.tilesets
local lenTileSets <const> = #tileSets
if lenTileSets <= 0 then
    app.refresh()
    return
end

app.transaction("Correct Zero Alpha Tiles", function()
    local k = 0
    while k < lenTileSets do
        k = k + 1
        local tileSet <const> = tileSets[k]
        local lenTileSet <const> = #tileSet
        local m = 0
        while m < lenTileSet do
            local tile <const> = tileSet:tile(m)
            if tile then
                tile.image = correctZero(tile.image)
            end
            m = m + 1
        end
    end
end)

app.refresh()
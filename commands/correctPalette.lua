dofile("../support/aseutilities.lua")

local activeSprite <const> = app.site.sprite
if not activeSprite then return end

AseUtilities.preserveForeBack()

local oldColorMode <const> = activeSprite.colorMode
AseUtilities.changePixelFormat(ColorMode.RGB)

activeSprite.transparentColor = 0

local hexesProfile <const> = AseUtilities.asePalettesToHexArr(activeSprite.palettes)
local uniques <const>, _ <const> = Utilities.uniqueColors(hexesProfile, true)
local masked <const> = Utilities.prependMask(uniques)

---@type Color[]
local aseColors <const> = {}
local lenAseColors <const> = #masked
local i = 0
while i < lenAseColors do
    i = i + 1
    aseColors[i] = AseUtilities.hexToAseColor(masked[i])
end

local palettes <const> = activeSprite.palettes
local lenPalettes <const> = #palettes

-- It seems safe to assign the same Aseprite color to multiple palettes because
-- they are copied by value, not passed by reference...?
app.transaction("Correct Palette", function()
    local j = 0
    while j < lenPalettes do
        j = j + 1
        local palette <const> = palettes[j]
        palette:resize(lenAseColors)
        local k = 0
        while k < lenAseColors do
            k = k + 1
            palette:setColor(k - 1, aseColors[k])
        end
    end
end)

AseUtilities.changePixelFormat(oldColorMode)
app.refresh()
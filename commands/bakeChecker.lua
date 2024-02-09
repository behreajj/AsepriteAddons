dofile("../support/aseutilities.lua")

local activeSprite <const> = app.site.sprite
if not activeSprite then return end

app.transaction("Background to Layer", function()
    AseUtilities.bkgToLayer(activeSprite, false)
end)

local docPref <const> = app.preferences.document(activeSprite)
local bgPref <const> = docPref.bg
local size <const> = bgPref.size --[[@as Size]]

local wCheck <const> = math.max(1, math.abs(size.width))
local hCheck <const> = math.max(1, math.abs(size.height))

local activeSpec <const> = activeSprite.spec
local colorMode <const> = activeSpec.colorMode

local aAse <const> = bgPref.color1 --[[@as Color]]
local bAse <const> = bgPref.color2 --[[@as Color]]
local a = AseUtilities.aseColorToHex(aAse, colorMode)
local b = AseUtilities.aseColorToHex(bAse, colorMode)

-- Precaution against background checker colors that may have opacity.
if colorMode == ColorMode.RGB then
    a = 0xff000000 | a
    b = 0xff000000 | b
elseif colorMode == ColorMode.GRAY then
    a = 0xff00 | a
    b = 0xff00 | b
end

-- TODO: Make this its own function in AseUtilities.
local checker <const> = Image(activeSpec)
local pxItr <const> = checker:pixels()
for pixel in pxItr do
    local hex = b
    local x <const> = pixel.x
    local y <const> = pixel.y
    if (((x // wCheck) + (y // hCheck)) % 2) ~= 1 then
        hex = a
    end
    pixel(hex)
end

app.transaction("Bake Checker", function()
    local checkerLayer <const> = activeSprite:newLayer()
    checkerLayer.name = "Checker"

    local frames <const> = activeSprite.frames
    local lenFrames <const> = #frames
    local i = 0
    while i < lenFrames do
        i = i + 1
        activeSprite:newCel(
            checkerLayer,
            frames[i],
            checker)
    end

    checkerLayer.stackIndex = activeSprite.backgroundLayer and 2 or 1
    app.layer = checkerLayer
end)

app.refresh()
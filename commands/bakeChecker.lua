dofile("../support/aseutilities.lua")

local activeSprite <const> = app.site.sprite
if not activeSprite then return end

app.transaction("Background to Layer", function()
    AseUtilities.bkgToLayer(activeSprite, false)
end)

local wCheck <const>,
hCheck <const>,
aAse <const>,
bAse <const> = AseUtilities.getBkgChecker(activeSprite)

local spriteSpec <const> = activeSprite.spec
local colorMode <const> = spriteSpec.colorMode

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

local checker <const> = AseUtilities.checkerImage(
    spriteSpec.width,
    spriteSpec.height,
    wCheck, hCheck, a, b,
    colorMode,
    spriteSpec.colorSpace,
    spriteSpec.transparentColor)

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
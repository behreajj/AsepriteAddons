dofile("../support/aseutilities.lua")

local activeSprite <const> = app.site.sprite
if not activeSprite then return end

app.transaction("Background to Layer", function()
    AseUtilities.bkgToLayer(activeSprite, false)
end)

local wCheck = 8
local hCheck = 8
local aAse = Color { r = 28, g = 28, b = 28, a = 255 }
local bAse = Color { r = 10, g = 10, b = 10, a = 255 }

local appPrefs <const> = app.preferences
if appPrefs then
    local docPrefs <const> = appPrefs.document(activeSprite)
    if docPrefs then
        local bgPrefs <const> = docPrefs.bg
        if bgPrefs then
            local checkSize <const> = bgPrefs.size --[[@as Size]]
            if checkSize then
                wCheck = math.max(1, math.abs(checkSize.width))
                hCheck = math.max(1, math.abs(checkSize.height))
            end

            local bgPrefColor1 <const> = bgPrefs.color1 --[[@as Color]]
            if bgPrefColor1 then
                aAse = bgPrefColor1
            end

            local bgPrefColor2 <const> = bgPrefs.color2 --[[@as Color]]
            if bgPrefColor2 then
                bAse = bgPrefColor2
            end
        end
    end
end

local activeSpec <const> = activeSprite.spec
local colorMode <const> = activeSpec.colorMode

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
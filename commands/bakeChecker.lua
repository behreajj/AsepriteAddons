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
        -- https://github.com/aseprite/aseprite/blob/main/data/pref.xml#L521
        local bgPref <const> = docPrefs.bg
        if bgPref then
            local typePref <const> = bgPref.type --[[@as integer]]
            if typePref == 0 then
                wCheck = 16
                hCheck = 16
            elseif typePref == 1 then
                wCheck = 8
                hCheck = 8
            elseif typePref == 2 then
                wCheck = 4
                hCheck = 4
            elseif typePref == 3 then
                wCheck = 2
                hCheck = 2
            elseif typePref == 4 then
                wCheck = 1
                hCheck = 1
            else
                local checkSize <const> = bgPref.size --[[@as Size]]
                if checkSize then
                    wCheck = math.max(1, math.abs(checkSize.width))
                    hCheck = math.max(1, math.abs(checkSize.height))
                end
            end

            local bgPrefColor1 <const> = bgPref.color1 --[[@as Color]]
            if bgPrefColor1 then
                aAse = bgPrefColor1
            end

            local bgPrefColor2 <const> = bgPref.color2 --[[@as Color]]
            if bgPrefColor2 then
                bAse = bgPrefColor2
            end
        end
    end
end

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
dofile("../../support/aseutilities.lua")

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

app.transaction("Flatten Sprite", function()
    local spriteSpec <const> = activeSprite.spec
    local colorMode <const> = spriteSpec.colorMode
    local colorSpace <const> = spriteSpec.colorSpace
    local alphaIndex <const> = spriteSpec.transparentColor

    local frObjs <const> = activeSprite.frames
    local lenFrObjs <const> = #frObjs
    local flatToImg <const> = AseUtilities.flatToImage

    local flattened <const> = activeSprite:newLayer()
    flattened.name = "Flattened"

    local i = 0
    while i < lenFrObjs do
        i = i + 1
        local frObj <const> = frObjs[i]
        local isValid <const>,
        flatImg <const>,
        xTl <const>,
        yTl <const> = flatToImg(
            activeSprite, frObj,
            colorMode, colorSpace, alphaIndex,
            true, false, true, true)
        if isValid then
            activeSprite:newCel(
                flattened, frObj, flatImg,
                Point(xTl, yTl))
        end
    end

    local topLayers <const> = activeSprite.layers
    local lenTopLayers <const> = #topLayers
    -- Omit the usual plus 1, because you want
    -- the flattened layer to be omitted.
    local j = lenTopLayers
    while j > 1 do
        j = j - 1
        local topLayer <const> = topLayers[j]
        if not topLayer.isReference then
            activeSprite:deleteLayer(topLayer)
        end
    end
end)

app.refresh()
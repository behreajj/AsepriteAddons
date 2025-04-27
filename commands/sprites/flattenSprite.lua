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
    -- Omit the usual plus 1, because the flattened layer at the top of the
    -- stack will be preserved.
    -- No point in retaining top level reference layers, as ones within hidden
    -- groups would be deleted. To retain them, they would have to be
    -- reparented as necessary.
    local j = lenTopLayers
    while j > 1 do
        j = j - 1
        local topLayer <const> = topLayers[j]
        activeSprite:deleteLayer(topLayer)
    end
end)

app.refresh()
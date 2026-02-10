dofile("../../support/aseutilities.lua")

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local overLayer <const> = site.layer
if not overLayer then return end

local overIndex <const> = overLayer.stackIndex
if overIndex < 2 then return end

local parent <const> = overLayer.parent
local underIndex <const> = overIndex - 1
local underLayer <const> = parent.layers[underIndex]

if (not overLayer.isEditable)
    or (not underLayer.isEditable) then
    app.alert {
        title = "Error",
        text = "Locked layers cannot be merged."
    }
    return
end

if overLayer.isReference
    or underLayer.isReference then
    app.alert {
        title = "Error",
        text = "Reference layers cannot be merged."
    }
    return
end

if overLayer.isBackground
    or underLayer.isBackground then
    app.alert {
        title = "Error",
        text = "Background layers cannot be merged."
    }
    return
end

local lenFrames <const> = #sprite.frames

-- Unpack layer opacity.
local overLyrOpacity <const> = overLayer.opacity or 255
local underLyrOpacity <const> = underLayer.opacity or 255
local overLyrOpac01 <const> = overLyrOpacity / 255.0
local underLyrOpac01 <const> = underLyrOpacity / 255.0

local overLyrBlendMode <const> = overLayer.blendMode or BlendMode.NORMAL
local underLyrBlendMode <const> = underLayer.blendMode or BlendMode.NORMAL

-- Create new layer.
local compLayer <const> = sprite:newLayer()
app.transaction("Set Layer Props", function()
    compLayer.name = "Merged"
    -- Exception: this always sets to parent.
    compLayer.parent = parent
    compLayer.stackIndex = overLayer.stackIndex + 1

    -- TODO: Blend compLayer color from source layer colors?
end)

--Unpack the rest of sprite spec.
local spriteSpec <const> = sprite.spec
local colorMode <const> = spriteSpec.colorMode
local alphaIndex <const> = spriteSpec.transparentColor
local colorSpace <const> = spriteSpec.colorSpace
local wSprite <const> = spriteSpec.width
local hSprite <const> = spriteSpec.height

local createSpec <const> = AseUtilities.createSpec
local flatToImage <const> = AseUtilities.flatToImage
local floor <const> = math.floor
local max <const> = math.max
local min <const> = math.min

app.transaction("Merge Layers", function()
    local i = 0
    while i < lenFrames do
        i = i + 1

        local isValidUnder <const>,
        flatImgUnder <const>,
        xTlUnder <const>,
        yTlUnder <const>,
        underCelOpac8 <const>,
        zIndexUnder <const> = flatToImage(
            underLayer, i,
            colorMode, colorSpace, alphaIndex,
            true, false, true, true,
            wSprite, hSprite)

        local underCelOpac01 <const> = underCelOpac8 / 255.0
        local compUnder01 <const> = underLyrOpac01 * underCelOpac01
        local compUnder8 <const> = floor(compUnder01 * 255.0 + 0.5)

        local isValidOver <const>,
        flatImgOver <const>,
        xTlOver <const>,
        yTlOver <const>,
        overCelOpac8 <const>,
        zIndexOver <const> = flatToImage(
            overLayer, i,
            colorMode, colorSpace, alphaIndex,
            true, false, true, true,
            wSprite, hSprite)

        local overCelOpac01 <const> = overCelOpac8 / 255.0
        local compOver01 <const> = overLyrOpac01 * overCelOpac01
        local compOver8 <const> = floor(compOver01 * 255.0 + 0.5)

        if isValidOver and isValidUnder then
            local xMin <const> = min(xTlUnder, xTlOver)
            local yMin <const> = min(yTlUnder, yTlOver)
            local xMax <const> = max(
                xTlUnder + flatImgUnder.width - 1,
                xTlOver + flatImgOver.width - 1)
            local yMax <const> = max(
                yTlUnder + flatImgUnder.height - 1,
                yTlOver + flatImgOver.height - 1)

            local imgBlended = Image(createSpec(
                1 + xMax - xMin,  1 + yMax - yMin,
                colorMode, colorSpace, alphaIndex))

            -- TODO: Decide draw image order based on z indices and
            -- layer stack index?
            imgBlended:drawImage(
                flatImgUnder,
                Point(xTlUnder - xMin, yTlUnder - yMin),
                compUnder8,
                underLyrBlendMode)
            imgBlended:drawImage(
                flatImgOver,
                Point(xTlOver - xMin, yTlOver - yMin),
                compOver8,
                overLyrBlendMode)

            sprite:newCel(compLayer, i, imgBlended, Point(xMin, yMin))
        elseif isValidOver then
            local celBlended <const> = sprite:newCel(
                compLayer, i, flatImgOver,
                Point(xTlOver, yTlOver))
            celBlended.opacity = compOver8
        elseif isValidUnder then
            local celBlended <const> = sprite:newCel(
                compLayer, i, flatImgUnder,
                Point(xTlUnder, yTlUnder))
            celBlended.opacity = compUnder8
        end -- End over and under are valid.
    end     -- End frames loop.

    sprite:deleteLayer(overLayer)
    sprite:deleteLayer(underLayer)
end)

app.layer = compLayer
app.refresh()
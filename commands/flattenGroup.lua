dofile("../support/aseutilities.lua")

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local activeLayer <const> = site.layer
if not activeLayer then return end
if not activeLayer.isGroup then
    app.alert {
        title = "Error",
        text = "Layer is not a group."
    }
    return
end

local spriteSpec <const> = activeSprite.spec
local sprClrMode <const> = spriteSpec.colorMode
local colorSpace <const> = spriteSpec.colorSpace
local alphaIndex <const> = spriteSpec.transparentColor

local frObjs <const> = activeSprite.frames
local lenFrObjs <const> = #frObjs

local flattenGroup <const> = AseUtilities.flattenGroup

app.transaction("Flatten Group", function()
    local flattened <const> = activeSprite:newLayer()

    local i = 0
    while i < lenFrObjs do
        i = i + 1
        local frObj <const> = frObjs[i]
        local isValid <const>,
        flatImg <const>,
        xTl <const>,
        yTl <const> = flattenGroup(
            activeLayer, frObj,
            sprClrMode, colorSpace, alphaIndex,
            true, false, true, true)
        if isValid then
            activeSprite:newCel(
                flattened, frObj, flatImg,
                Point(xTl, yTl))
        end
    end

    local layerName = "Flattened"
    if activeLayer.name and #activeLayer.name > 0 then
        layerName = Utilities.validateFilename(activeLayer.name)
    end
    flattened.name = layerName

    flattened.blendMode = activeLayer.blendMode or BlendMode.NORMAL
    flattened.opacity = activeLayer.opacity or 255

    flattened.color = AseUtilities.aseColorCopy(activeLayer.color, "")
    flattened.data = activeLayer.data
    flattened.parent = activeLayer.parent
    flattened.stackIndex = activeLayer.stackIndex

    flattened.isContinuous = activeLayer.isContinuous
    flattened.isEditable = activeLayer.isEditable
    flattened.isVisible = activeLayer.isVisible

    activeSprite:deleteLayer(activeLayer)
end)

app.refresh()
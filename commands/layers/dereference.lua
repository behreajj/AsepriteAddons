local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end
local refLayer <const> = site.layer
if not refLayer then return end

if not refLayer.isReference then
    app.alert {
        title = "Error",
        text = "Layer is not a reference."
    }
    return
end

app.transaction("Dereference Layer", function()
    local derefLayer <const> = sprite:newLayer()
    local colorCopy <const> = AseUtilities.aseColorCopy

    derefLayer.name = "Ref"
    derefLayer.blendMode = refLayer.blendMode or BlendMode.NORMAL
    derefLayer.color = colorCopy(refLayer.color, "")
    derefLayer.data = refLayer.data
    derefLayer.opacity = refLayer.opacity or 255
    derefLayer.parent = refLayer.parent
    derefLayer.stackIndex = refLayer.stackIndex

    derefLayer.isContinuous = refLayer.isContinuous
    derefLayer.isEditable = refLayer.isEditable
    derefLayer.isVisible = refLayer.isVisible

    local frObjs <const> = sprite.frames
    local lenFrObjs <const> = #frObjs
    local i = 0
    while i < lenFrObjs do
        i = i + 1
        local frObj <const> = frObjs[i]
        local refCel <const> = refLayer:cel(frObj)
        if refCel then
            local derefCel <const> = sprite:newCel(
                derefLayer, frObj,
                refCel.image,
                refCel.position)
            derefCel.color = colorCopy(refCel.color, "")
            derefCel.data = refCel.data
            derefCel.opacity = refCel.opacity
            derefCel.zIndex = refCel.zIndex
        end
    end

    sprite:deleteLayer(refLayer)
end)

app.refresh()
local site = app.site
local sprite = site.sprite
if not sprite then return end
local refLayer = site.layer
if not refLayer then return end

local isRef = refLayer.isReference
if not isRef then
    app.alert {
        title = "Error",
        text = "Layer is not a reference."
    }
    return
end

app.transaction("Dereference Layer", function()
    local derefLayer = nil
    derefLayer = sprite:newLayer()
    derefLayer.name = "Ref"
    derefLayer.blendMode = refLayer.blendMode
    derefLayer.color = refLayer.color
    derefLayer.data = refLayer.data
    derefLayer.opacity = refLayer.opacity
    derefLayer.parent = refLayer.parent

    derefLayer.isEditable = refLayer.isEditable
    derefLayer.isContinuous = refLayer.isContinuous
    derefLayer.isVisible = refLayer.isVisible

    local frames = sprite.frames
    local lenFrames = #frames
    local i = 0
    while i < lenFrames do
        i = i + 1
        local frObj = frames[i]
        local refCel = refLayer:cel(frObj)
        if refCel then
            local derefCel = sprite:newCel(
                derefLayer, frObj,
                refCel.image,
                refCel.position)
            derefCel.color = refCel.color
            derefCel.data = refCel.data
            derefCel.opacity = refCel.opacity
        end
    end

    sprite:deleteLayer(refLayer)
end)

app.refresh()
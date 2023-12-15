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
    derefLayer.name = "Ref"
    derefLayer.blendMode = refLayer.blendMode
    derefLayer.color = refLayer.color
    derefLayer.data = refLayer.data
    derefLayer.opacity = refLayer.opacity
    derefLayer.parent = refLayer.parent
    derefLayer.stackIndex = refLayer.stackIndex

    derefLayer.isContinuous = refLayer.isContinuous
    derefLayer.isEditable = refLayer.isEditable
    derefLayer.isVisible = refLayer.isVisible

    local frames <const> = sprite.frames
    local lenFrames <const> = #frames
    local i = 0
    while i < lenFrames do
        i = i + 1
        local frObj <const> = frames[i]
        local refCel <const> = refLayer:cel(frObj)
        if refCel then
            local derefCel <const> = sprite:newCel(
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
local stepInto = false

local activeSprite = app.activeSprite
if not activeSprite then return end

local activeLayer = app.activeLayer
if activeLayer then
    local activeParent = activeLayer.parent
    local index = activeLayer.stackIndex
    local parentLayers = activeParent.layers
    if index < #parentLayers then
        local nextLayer = parentLayers[index + 1]
        while nextLayer.isGroup
            and #nextLayer.layers > 0
            and (stepInto or nextLayer.isExpanded) do
            nextLayer = nextLayer.layers[1]
        end
        app.activeLayer = nextLayer
    elseif activeParent.__name == "doc::Sprite" then
        app.activeLayer = activeSprite.layers[#activeSprite.layers]
    else
        app.activeLayer = activeParent
    end
else
    app.activeLayer = activeSprite.layers[#activeSprite.layers]
end

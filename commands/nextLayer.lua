local stepInto = false

local activeSprite = app.activeSprite
if not activeSprite then return end

-- TODO: Support moving a range of cels?
local activeLayer = app.activeLayer
if activeLayer then
    local activeParent = activeLayer.parent
    local activeStackIndex = activeLayer.stackIndex
    local parentLayers = activeParent.layers
    if activeStackIndex < #parentLayers then
        local nextStackIndex = activeStackIndex + 1
        local nextLayer = parentLayers[nextStackIndex]
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

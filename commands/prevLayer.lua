local stepInto = false

local activeSprite = app.activeSprite
if not activeSprite then return end

local activeLayer = app.activeLayer
if activeLayer then
    local stackIndex = activeLayer.stackIndex
    if activeLayer.isGroup
        and #activeLayer.layers > 0
        and (stepInto or activeLayer.isExpanded) then
        app.activeLayer = activeLayer.layers[#activeLayer.layers]
    elseif stackIndex > 1 then
        -- Needed for group layers with no children.
        app.activeLayer = activeLayer.parent.layers[stackIndex - 1]
    elseif activeLayer.parent.__name == "doc::Sprite" then
        app.activeLayer = activeSprite.layers[1]
    else
        while activeLayer.__name ~= "doc::Sprite"
            and stackIndex < 2 do
            stackIndex = activeLayer.stackIndex
            activeLayer = activeLayer.parent
        end
        app.activeLayer = activeLayer.layers[stackIndex - 1]
    end
else
    app.activeLayer = activeSprite.layers[1]
end

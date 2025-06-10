local sprite <const> = app.sprite
if not sprite then return end

local tlHidden <const> = not app.preferences.general.visible_timeline --[[@as boolean]]
if tlHidden then
    app.command.Timeline { open = true }
end

local range <const> = app.range
if range.sprite == sprite then
    local rangeType <const> = range.type
    if rangeType == RangeType.EMPTY
        or rangeType == RangeType.FRAMES then
        -- Layer > Visible does not work properly when range is of type frames.
        local layer <const> = app.layer
        if layer then
            layer.isVisible = not layer.isVisible
        end
    else
        local rangeLayers <const> = range.layers
        local lenRangeLayers <const> = #rangeLayers
        local i = 0
        while i < lenRangeLayers do
            i = i + 1
            local layer <const> = rangeLayers[i]
            layer.isVisible = not layer.isVisible
        end
    end
end

if tlHidden then
    app.command.Timeline { close = true }
end

app.refresh()
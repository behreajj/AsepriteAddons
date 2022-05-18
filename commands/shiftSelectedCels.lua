---To set a range's layers, it needs to
---be assigned a table of layers, which
---doesn't seem to be the same as what
---the range's layer getter returns.
---@param range userdata Aseprite range
---@return table
local function rangeLayersTable(range)
    local layersObj = range.layers
    local layersTable = {}
    for i = 1, #layersObj, 1 do
        layersTable[i] = layersObj[i]
    end
    return layersTable
end

---To set a range's frames, it needs to
---be assigned a table of frame indices;
---the range's frame getter returns a
---an array object of frames.
---@param range userdata range
---@return table
local function rangeFrameIdcsTable(range)
    local framesObj = range.frames
    local framesTable = {}
    for i = 1, #framesObj, 1 do
        framesTable[i] = framesObj[i].frameNumber
    end
    return framesTable
end

local shift = 1 -- change to -1 for other direction

local activeSprite = app.activeSprite
if activeSprite then
    local activeFrames = app.activeSprite.frames
    local frameLen = #activeFrames

    if frameLen > 1 then
        local appRange = app.range
        local actFrameIdx = app.activeFrame.frameNumber
        local shiftActIdx = 1 + ((shift + actFrameIdx - 1) % frameLen)
        app.activeFrame = activeFrames[shiftActIdx]

        if appRange.type ~= RangeType.EMPTY then
            local layers = rangeLayersTable(appRange)
            local frameIdcs = rangeFrameIdcsTable(appRange)

            for i = 1, #frameIdcs, 1 do
                local frameIdx = frameIdcs[i]
                frameIdcs[i] = 1 + ((shift + frameIdx - 1) % frameLen)
            end

            appRange.frames = frameIdcs
            appRange.layers = layers
            app.command.Refresh()
        end
    end
end
dofile("../support/aseutilities.lua")

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local activeLayer <const> = site.layer
if not activeLayer then return end

local origFrObj <const> = site.frame
if not origFrObj then return end

local shift <const> = -1
local frames <const> = activeSprite.frames
local lenFrames <const> = #frames
local origFrIdx <const> = origFrObj.frameNumber
local destFrIdx <const> = 1 + (shift + origFrIdx - 1) % lenFrames
local destFrObj <const> = frames[destFrIdx]

if activeLayer.isBackground then
    local origCel <const> = activeLayer:cel(origFrObj)
    local destCel <const> = activeLayer:cel(destFrObj)
    if origCel and destCel then
        local origImg <const> = Image(origCel.image)
        local origData <const> = origCel.data
        local origColor <const> = AseUtilities.aseColorCopy(origCel.color, "")
        local origzIndex <const> = origCel.zIndex

        local destImg <const> = Image(destCel.image)
        local destData <const> = destCel.data
        local destColor <const> = AseUtilities.aseColorCopy(destCel.color, "")
        local destzIndex <const> = destCel.zIndex

        app.transaction("Cycle Cel Left", function()
            origCel.image = destImg
            origCel.data = destData
            origCel.color = destColor
            origCel.zIndex = destzIndex

            destCel.image = origImg
            destCel.data = origData
            destCel.color = origColor
            destCel.zIndex = origzIndex

            app.frame = destFrObj
        end)
    end
else
    -- No point in basing this on a range, which will be removed
    -- by the swap. Could use getLayerHierarchy for all layers.
    -- Reference layers are ignored, even though they could be included.
    local leaves <const> = AseUtilities.appendLeaves(
        activeLayer, {},
        true, true, true, false)
    local lenLeaves <const> = #leaves
    if lenLeaves > 0 then
        app.transaction("Cycle Cel Left", function()
            local tempFrObj <const> = activeSprite:newEmptyFrame()
            local i = 0
            while i < lenLeaves do
                i = i + 1
                local leaf <const> = leaves[i]
                local origCel <const> = leaf:cel(origFrObj)
                local destCel <const> = leaf:cel(destFrObj)
                if origCel and destCel then
                    origCel.frame = tempFrObj
                    destCel.frame = origFrObj
                    origCel.frame = destFrObj
                elseif origCel then
                    origCel.frame = destFrObj
                elseif destCel then
                    destCel.frame = origFrObj
                end
            end
            activeSprite:deleteFrame(tempFrObj)
            app.frame = destFrObj
        end)
    end
end
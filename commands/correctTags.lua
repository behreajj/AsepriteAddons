-- TODO: Would this be more useful if it were generalized to correct any names,
-- including layer names, as seen in
-- https://community.aseprite.org/t/export-sprite-sheet-group-name-conflict/4902

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local tags <const> = activeSprite.tags
local lenTags <const> = #tags
local lenFrames <const> = #activeSprite.frames

---@type table<string, Tag[]>
local dict <const> = {}
---@type Tag[]
local tagsToRename <const> = {}
---@type Tag[]
local tagsToRemove <const> = {}

local i = 0
while i < lenTags do
    i = i + 1
    local tag <const> = tags[i]
    local fromFrame <const> = tag.fromFrame
    local toFrame <const> = tag.toFrame
    if toFrame and fromFrame then
        local fromIdx <const> = fromFrame.frameNumber
        local toIdx <const> = toFrame.frameNumber
        if fromIdx >= 1 and toIdx <= lenFrames then
            local name <const> = tag.name
            local arr <const> = dict[name]
            if arr then
                arr[#arr + 1] = tag
            else
                dict[name] = { tag }
            end
        else
            tagsToRemove[#tagsToRemove + 1] = tag
        end
    else
        tagsToRemove[#tagsToRemove + 1] = tag
    end
end

for _, arr in pairs(dict) do
    local lenArr <const> = #arr
    if lenArr > 1 then
        local j = 0
        while j < lenArr do
            j = j + 1
            tagsToRename[#tagsToRename + 1] = arr[j]
        end
    end
end

local lenTagsToRename <const> = #tagsToRename
if lenTagsToRename > 0 then
    app.transaction("Rename tags", function()
        local k = 0
        while k < lenTagsToRename do
            k = k + 1
            local tag <const> = tagsToRename[k]
            local oldName <const> = tag.name

            -- Two tags could have the same fromFrame and toFrame, so those
            -- cannot be used as distinguishing features.
            local newName <const> = string.format(
                "%s (%d)", oldName, k)
            tag.name = newName
        end
    end)
end

local lenTagsToRemove <const> = #tagsToRemove
if lenTagsToRemove > 0 then
    app.transaction("Remove tags", function()
        local m = lenTagsToRemove + 1
        while m > 1 do
            m = m - 1
            local tag <const> = tagsToRemove[m]
            activeSprite:deleteTag(tag)
        end
    end)
end
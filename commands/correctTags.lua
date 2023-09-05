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
---@type Tag[][]
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
        if fromIdx <= lenFrames and toIdx <= lenFrames
            and fromIdx >= 1 and toIdx >= 1 then
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

-- Transfer dictionary of arrays to array of arrays.
for _, arr in pairs(dict) do
    local lenArr <const> = #arr
    if lenArr > 1 then
        tagsToRename[#tagsToRename + 1] = arr
    end
end

local lenTagsToRename <const> = #tagsToRename
if lenTagsToRename > 0 then
    local strfmt <const> = string.format
    app.transaction("Rename tags", function()
        local k = 0
        while k < lenTagsToRename do
            k = k + 1
            local arr <const> = tagsToRename[k]
            local lenArr <const> = #arr

            local m = 0
            while m < lenArr do
                -- Two tags could have the same fromFrame and toFrame, so those
                -- cannot be used as distinguishing features.

                m = m + 1
                local tag <const> = arr[m]
                local oldName <const> = tag.name
                local newName <const> = strfmt("%s (%d)", oldName, m)
                tag.name = newName
            end
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
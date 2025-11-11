local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local tags <const> = activeSprite.tags
local lenTags <const> = #tags
local lenFrames <const> = #activeSprite.frames

---@type table<string, Tag[]>
local dict <const> = {}

---@type Tag[]
local tagsToRemove <const> = {}
local lenTagsToRemove = 0

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
            -- TODO: Assign an ID similar to correctTilesets?

            local name <const> = tag.name
            local arr <const> = dict[name]
            if arr then
                arr[#arr + 1] = tag
            else
                dict[name] = { tag }
            end
        else
            lenTagsToRemove = lenTagsToRemove + 1
            tagsToRemove[lenTagsToRemove] = tag
        end
    else
        lenTagsToRemove = lenTagsToRemove + 1
        tagsToRemove[lenTagsToRemove] = tag
    end
end

---@type Tag[][]
local tagsToRename <const> = {}
local lenTagsToRename = 0

-- Transfer dictionary of arrays to array of arrays.
for _, arr in pairs(dict) do
    local lenArr <const> = #arr
    if lenArr > 1 then
        lenTagsToRename = lenTagsToRename + 1
        tagsToRename[lenTagsToRename] = arr
    end
end

-- "Loop" is a reserved tag name. The rename loop should already take care
-- of the case where multiple tags have this name.
-- https://github.com/aseprite/aseprite/blob/main/src/app/loop_tag.cpp#L26
-- https://github.com/aseprite/aseprite/blob/main/src/app/commands/cmd_set_loop_section.cpp

if lenTagsToRename > 0 then
    local strfmt <const> = string.format
    app.transaction("Rename tags", function()
        local j = 0
        while j < lenTagsToRename do
            j = j + 1
            local arr <const> = tagsToRename[j]
            local lenArr <const> = #arr

            local k = 0
            while k < lenArr do
                k = k + 1
                local tag <const> = arr[k]

                -- Two tags could have the same fromFrame and toFrame, so those
                -- cannot be used as distinguishing features.
                local oldName <const> = tag.name
                local newName <const> = strfmt("%s (%d)", oldName, k)
                tag.name = newName
            end
        end
    end)
end

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
dofile("../../support/gradientutilities.lua")

local inputTypes = { "COUNT", "MANUAL", "SPAN" }

local aniDirs = {
    "FORWARD",
    "REVERSE",
    "PING_PONG",
    "PING_PONG_REVERSE"
}

local colorOptions = { "ALL", "NEW" }

local defaults = {
    inputType = "MANUAL",
    totalCount = 6,
    spanCount = 6,
    rangeStr = "",
    strExample = "4,6-9,13",
    nameFormat = "[%%02d,%%02d]",
    colorOption = "ALL",
    aniDir = "FORWARD",
    -- This is 1, not 0 (infinity), because of
    -- Play Subtags and Repetitions Setting.
    repeats = 1,
    infiniteNote = "Use 0 for infinite loop.",
    deleteExisting = false
}

local dlg = Dialog { title = "Create Tags" }

dlg:combobox {
    id = "inputType",
    label = "Input:",
    option = defaults.inputType,
    options = inputTypes,
    onchange = function()
        local args = dlg.data
        local isManual = args.inputType == "MANUAL"
        local isSpan = args.inputType == "SPAN"
        local isCount = args.inputType == "COUNT"
        dlg:modify { id = "rangeStr", visible = isManual }
        dlg:modify { id = "strExample", visible = false }
        dlg:modify { id = "spanCount", visible = isSpan }
        dlg:modify { id = "totalCount", visible = isCount }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "totalCount",
    label = "Count:",
    min = 1,
    max = 16,
    value = defaults.totalCount,
    visible = defaults.inputType == "COUNT"
}

dlg:newrow { always = false }

dlg:slider {
    id = "spanCount",
    label = "Span:",
    min = 1,
    max = 32,
    value = defaults.spanCount,
    visible = defaults.inputType == "SPAN"
}

dlg:newrow { always = false }

dlg:entry {
    id = "rangeStr",
    label = "Frames:",
    text = defaults.rangeStr,
    focus = defaults.inputType == "MANUAL",
    visible = defaults.inputType == "MANUAL",
    onchange = function()
        dlg:modify { id = "strExample", visible = true }
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "strExample",
    label = "Example:",
    text = defaults.strExample,
    visible = false
}

dlg:newrow { always = false }

dlg:entry {
    id = "nameFormat",
    label = "Name:",
    text = defaults.nameFormat,
    focus = false
}

dlg:newrow { always = false }

dlg:combobox {
    id = "aniDir",
    label = "Direction:",
    option = defaults.aniDir,
    options = aniDirs
}

dlg:newrow { always = false }

dlg:number {
    id = "repeats",
    label = "Repeats:",
    text = string.format("%d", defaults.repeats),
    decimals = 0,
    onchange = function()
        dlg:modify { id = "infiniteNote", visible = true }
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "infiniteNote",
    label = "Note:",
    text = defaults.infiniteNote,
    visible = false
}

dlg:newrow { always = false }

dlg:color {
    id = "fromColor",
    label = "From:",
    color = Color { r = 254, g = 91, b = 89, a = 255 }
}

dlg:color {
    id = "toColor",
    label = "To:",
    color = Color { r = 106, g = 205, b = 91, a = 255 }
}

dlg:newrow { always = false }

dlg:combobox {
    id = "colorOption",
    label = "Recolor:",
    option = defaults.colorOption,
    options = colorOptions
}

dlg:check {
    id = "deleteExisting",
    label = "Replace:",
    text = "E&xisting",
    selected = defaults.deleteExisting
}

dlg:button {
    id = "confirm",
    text = "&OK",
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local args = dlg.data
        local inputType = args.inputType
            or defaults.inputType --[[@as string]]
        local rangeStr = args.rangeStr
            or defaults.rangeStr --[[@as string]]
        local nameFormat = args.nameFormat
            or defaults.nameFormat --[[@as string]]
        local fromColor = args.fromColor --[[@as Color]]
        local toColor = args.toColor --[[@as Color]]
        local colorOption = args.colorOption
            or defaults.colorOption --[[@as string]]
        local aniDirStr = args.aniDir
            or defaults.aniDir --[[@as string]]
        local repeats = args.repeats
            or defaults.repeats --[[@as number]]
        local deleteExisting = args.deleteExisting --[[@as boolean]]

        local validNameFormat = #nameFormat > 0
            and pcall(function()
                return string.format(nameFormat, 1, 2)
            end)
        if not validNameFormat then
            -- The % escapes are needed for text entry above,
            -- but should not be used here.
            nameFormat = "[%02d,%02d]"
        end

        if deleteExisting then
            local oldTags = activeSprite.tags
            local lenOldTags = #oldTags
            app.transaction("Remove Tags", function()
                local h = lenOldTags + 1
                while h > 1 do
                    h = h - 1
                    local oldTag = oldTags[h]
                    activeSprite:deleteTag(oldTag)
                end
            end)
        end

        local recolorNew = colorOption == "NEW"
        local recolorAll = colorOption == "ALL"
        repeats = math.abs(repeats)
        local fromClr = AseUtilities.aseColorToClr(fromColor)
        local toClr = AseUtilities.aseColorToClr(toColor)

        ---@type integer|AniDir
        local aniDirEnum = AniDir.FOWARD
        if aniDirStr == "REVERSE" then
            aniDirEnum = AniDir.REVERSE
        elseif aniDirStr == "PING_PONG" then
            aniDirEnum = AniDir.PING_PONG
        elseif aniDirStr == "PING_PONG_REVERSE" then
            aniDirEnum = 3
        end

        -- How to prevent duplicate tags from being created?
        -- Way to set play subtags and repetitions
        -- vs Play all, play once?
        -- print(app.preferences.editor.play_once)
        -- print(app.preferences.editor.play_all)
        -- print(app.preferences.editor.play_subtags)

        local frIdcs2 = {}
        if inputType == "COUNT" then
            local totalCount = args.totalCount
                or defaults.totalCount --[[@as integer]]

            local lenFrames = #activeSprite.frames
            local span = lenFrames // totalCount
            if span > 0 then
                local h = 0
                while h < totalCount do
                    local idxOrig = 1 + h * span
                    local idxDest = idxOrig + span - 1
                    h = h + 1
                    frIdcs2[h] = { idxOrig, idxDest }
                end

                local remainder = lenFrames % totalCount
                if remainder > 0 then
                    frIdcs2[totalCount][2] = lenFrames
                end
            else
                app.alert {
                    title = "Error",
                    text = { "Span is too small.", "Try reducing count." }
                }
                return
            end
        elseif inputType == "SPAN" then
            local spanCount = args.spanCount
                or defaults.spanCount --[[@as integer]]

            local lenFrames = #activeSprite.frames
            spanCount = math.min(math.max(spanCount, 1), lenFrames)
            local iterations = lenFrames // spanCount
            local h = 0
            while h < iterations do
                local idxOrig = 1 + h * spanCount
                local idxDest = idxOrig + spanCount - 1
                h = h + 1
                frIdcs2[h] = { idxOrig, idxDest }
            end
        else
            frIdcs2 = AseUtilities.getFrames(
                activeSprite, "MANUAL",
                true, rangeStr, nil)
        end
        local lenOuter = #frIdcs2

        local toFacNew = 0.0
        if lenOuter > 1 then
            toFacNew = 1.0 / (lenOuter - 1.0)
        end

        local autoSort = recolorNew
            and inputType == "MANUAL"
        if autoSort then
            table.sort(frIdcs2, function(a, b)
                return a[1] < b[1]
            end)
        end

        local min = math.min
        local max = math.max
        local strfmt = string.format
        local hueFunc = GradientUtilities.lerpHueCcw
        local mixer = Clr.mixSrLch
        local clrToAse = AseUtilities.clrToAseColor

        local i = 0
        while i < lenOuter do
            i = i + 1
            local frIdcs1 = frIdcs2[i]
            local lenInner = #frIdcs1
            if lenInner > 0 then
                local idxFirst = frIdcs1[1]
                local idxLast  = frIdcs1[lenInner]

                local start    = min(idxFirst, idxLast)
                local stop     = max(idxFirst, idxLast)

                app.transaction("New Tag", function()
                    local tag   = activeSprite:newTag(start, stop)
                    tag.name    = strfmt(nameFormat, start, stop)
                    tag.aniDir  = aniDirEnum
                    tag.repeats = repeats

                    if recolorNew then
                        local fac = (i - 1) * toFacNew
                        local clr = mixer(fromClr, toClr, fac, hueFunc)
                        local color = clrToAse(clr)
                        tag.color = color
                    end
                end)
            end
        end

        -- Tags could propagate their color to cels, but
        -- because a linked cel can extend beyond the tag
        -- that contains its frame, this wouldn't work.
        local allTags = activeSprite.tags
        local lenAllTags = #allTags
        if recolorAll then
            local toFacAll = 0.0
            if lenAllTags > 1 then
                toFacAll = 1.0 / (lenAllTags - 1.0)
            end

            app.transaction("Color Tags", function()
                local j = 0
                while j < lenAllTags do
                    j = j + 1
                    local fac = (j - 1) * toFacAll
                    local clr = mixer(fromClr, toClr, fac, hueFunc)
                    local color = clrToAse(clr)
                    local tag = allTags[j]
                    tag.color = color
                end
            end)
        end

        -- This triggers an update to the timeline, causing the tags
        -- to order correctly, but it erases the user's range.
        app.activeLayer = app.activeLayer
        app.refresh()
        app.command.Refresh()

        if not validNameFormat then
            app.alert {
                title = "Warning",
                text = { "Invalid name format.", "Default was used." }
            }
        end
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
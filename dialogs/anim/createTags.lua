dofile("../../support/gradientutilities.lua")

local inputTypes <const> = { "COUNT", "MANUAL", "RANGE", "SPAN" }

local aniDirs <const> = {
    "FORWARD",
    "REVERSE",
    "PING_PONG",
    "PING_PONG_REVERSE"
}

local colorOptions <const> = { "ALL", "NEW" }

local defaults <const> = {
    inputType = "COUNT",
    totalCount = 1,
    spanCount = 6,
    rangeStr = "",
    strExample = "4,6:9,13",
    nameFormat = "[%%02d,%%02d]",
    colorOption = "ALL",
    aniDir = "FORWARD",
    -- This is 1, not 0 (infinity), because of
    -- Play Subtags and Repetitions setting.
    repeats = 1,
    infiniteNote = "Use 0 for infinite loop.",
    deleteExisting = false
}

local dlg <const> = Dialog { title = "Create Tags" }

dlg:combobox {
    id = "inputType",
    label = "Input:",
    option = defaults.inputType,
    options = inputTypes,
    onchange = function()
        local args <const> = dlg.data
        local inputType <const> = args.inputType --[[@as string]]
        local isManual <const> = inputType == "MANUAL"
        local isSpan <const> = inputType == "SPAN"
        local isCount <const> = inputType == "COUNT"
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local args <const> = dlg.data
        local inputType <const> = args.inputType
            or defaults.inputType --[[@as string]]
        local rangeStr <const> = args.rangeStr
            or defaults.rangeStr --[[@as string]]
        local nameFormat = args.nameFormat
            or defaults.nameFormat --[[@as string]]
        local fromColor <const> = args.fromColor --[[@as Color]]
        local toColor <const> = args.toColor --[[@as Color]]
        local colorOption <const> = args.colorOption
            or defaults.colorOption --[[@as string]]
        local aniDirStr <const> = args.aniDir
            or defaults.aniDir --[[@as string]]
        local repeats = args.repeats
            or defaults.repeats --[[@as integer]]
        local deleteExisting <const> = args.deleteExisting --[[@as boolean]]

        local validNameFormat <const> = #nameFormat > 0
            and pcall(function()
                return string.format(nameFormat, 1, 2)
            end)
        if not validNameFormat then
            -- The % escapes are needed for text entry above,
            -- but should not be used here.
            nameFormat = "[%02d,%02d]"
        end

        -- Acquire tool for no other reason than to prevent transformation
        -- preview from stopping script.
        local _ <const> = app.tool

        if deleteExisting then
            local oldTags <const> = activeSprite.tags
            local lenOldTags <const> = #oldTags
            app.transaction("Remove Tags", function()
                local h = lenOldTags + 1
                while h > 1 do
                    h = h - 1
                    activeSprite:deleteTag(oldTags[h])
                end
            end)
        end

        local recolorNew <const> = colorOption == "NEW"
        local recolorAll <const> = colorOption == "ALL"
        repeats = math.abs(repeats)
        local fromClr <const> = AseUtilities.aseColorToClr(fromColor)
        local toClr <const> = AseUtilities.aseColorToClr(toColor)

        local aniDirEnum = AniDir.FORWARD
        if aniDirStr == "REVERSE" then
            aniDirEnum = AniDir.REVERSE
        elseif aniDirStr == "PING_PONG" then
            aniDirEnum = AniDir.PING_PONG
        elseif aniDirStr == "PING_PONG_REVERSE" then
            aniDirEnum = AniDir.PING_PONG_REVERSE
        end

        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        ---@type integer[][]
        local frIdcs2 = {}
        if inputType == "COUNT" then
            local totalCount <const> = args.totalCount
                or defaults.totalCount --[[@as integer]]

            local lenFrames <const> = #activeSprite.frames
            local span <const> = lenFrames // totalCount
            if span > 0 then
                local h = 0
                while h < totalCount do
                    local idxOrig <const> = 1 + h * span
                    local idxDest <const> = idxOrig + span - 1
                    h = h + 1
                    frIdcs2[h] = { idxOrig, idxDest }
                end

                local remainder <const> = lenFrames % totalCount
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

            local lenFrames <const> = #activeSprite.frames
            spanCount = math.min(math.max(spanCount, 1), lenFrames)
            local iterations <const> = lenFrames // spanCount
            local h = 0
            while h < iterations do
                local idxOrig <const> = 1 + h * spanCount
                local idxDest <const> = idxOrig + spanCount - 1
                h = h + 1
                frIdcs2[h] = { idxOrig, idxDest }
            end

            if lenFrames % spanCount > 0 then
                frIdcs2[h + 1] = { frIdcs2[h][2] + 1, lenFrames }
            end
        else
            frIdcs2 = AseUtilities.getFrames(
                activeSprite, inputType,
                true, rangeStr, nil)
        end
        local lenOuter <const> = #frIdcs2

        local toFacNew = 0.0
        if lenOuter > 1 then
            toFacNew = 1.0 / (lenOuter - 1.0)
        end

        local autoSort <const> = recolorNew
            and inputType == "MANUAL"
        if autoSort then
            table.sort(frIdcs2, function(a, b)
                return a[1] < b[1]
            end)
        end

        local min <const> = math.min
        local max <const> = math.max
        local strfmt <const> = string.format
        local hueFunc <const> = GradientUtilities.lerpHueCcw
        local mixer <const> = Clr.mixSrLch
        local clrToAse <const> = AseUtilities.clrToAseColor
        local transact <const> = app.transaction

        local i = 0
        while i < lenOuter do
            i = i + 1
            local frIdcs1 <const> = frIdcs2[i]
            local lenInner <const> = #frIdcs1
            if lenInner > 0 then
                local idxFirst <const> = frIdcs1[1]
                local idxLast <const> = frIdcs1[lenInner]

                local orig <const> = min(idxFirst, idxLast)
                local dest <const> = max(idxFirst, idxLast)
                local uiOrig <const> = frameUiOffset + orig
                local uiDest <const> = frameUiOffset + dest

                transact(strfmt("New Tag %d to %d", uiOrig, uiDest), function()
                    local tag <const> = activeSprite:newTag(orig, dest)
                    tag.name = strfmt(nameFormat, uiOrig, uiDest)
                    tag.aniDir = aniDirEnum
                    tag.repeats = repeats

                    if recolorNew then
                        local fac <const> = (i - 1) * toFacNew
                        local clr <const> = mixer(fromClr, toClr, fac, hueFunc)
                        local color <const> = clrToAse(clr)
                        tag.color = color
                    end
                end)
            end
        end

        -- Because linked cels can extended beyond the tag
        -- that contains their frames, and because an empty
        -- cel cannot be colored, propagating tag colors to
        -- cels is not viable.
        local allTags <const> = activeSprite.tags
        local lenAllTags <const> = #allTags
        if recolorAll then
            local toFacAll = 0.0
            if lenAllTags > 1 then
                toFacAll = 1.0 / (lenAllTags - 1.0)
            end

            app.transaction("Color Tags", function()
                local j = 0
                while j < lenAllTags do
                    j = j + 1
                    local fac <const> = (j - 1) * toFacAll
                    local clr <const> = mixer(fromClr, toClr, fac, hueFunc)
                    local color <const> = clrToAse(clr)
                    local tag <const> = allTags[j]
                    tag.color = color
                end
            end)
        end

        -- This triggers an update to the timeline, causing the tags
        -- to order correctly, but it erases the user's range.
        app.layer = app.layer

        -- Skin Refresh command cannot be used because it crashes older
        -- versions of Aseprite.
        app.refresh()

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

dlg:show {
    autoscrollbars = true,
    wait = false
}
dofile("../../support/aseutilities.lua")

local defaults = {
    uniquesOnly = false,
    prependMask = true
}

local dlg = Dialog { title = "GPL Import" }

dlg:file {
    id = "filepath",
    label = "Path:",
    focus = true,
    filetypes = { "gpl", "pal" },
    open = true
}

dlg:newrow { always = false }

dlg:check {
    id = "uniquesOnly",
    label = "Uniques Only:",
    selected = defaults.uniquesOnly
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = defaults.prependMask,
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()

        local args = dlg.data
        local filepath = args.filepath
        local file, err = io.open(filepath, "r")

        -- Cache functions to local when used in loop.
        local strlower = string.lower
        local strsub = string.sub
        local strgmatch = string.gmatch
        local strmatch = string.match
        local tinsert = table.insert

        -- Implicitly tries to support JASC-PAL.
        local gplHeaderFound = 0
        local palHeaderFound = 0
        local palMagicFound = 0
        local nameFound = 0
        local jascPalClrCountFound = 0
        local aseAlphaFound = 0
        local columns = 0
        local comments = {}
        local colors = {}

        if file ~= nil then
            local lineCount = 1
            local linesItr = file:lines()

            for line in linesItr do
                local lc = strlower(line)

                if lc == "gimp palette" then
                    gplHeaderFound = lineCount
                elseif lc == "jasc-pal" then
                    palHeaderFound = lineCount
                elseif palHeaderFound == (lineCount - 1)
                    and lc == "0100" then
                    palMagicFound = lineCount
                elseif strsub(lc, 1, 4) == "name" then
                    nameFound = lineCount
                elseif strsub(lc, 1, 7) == "columns" then
                    local colStr = strmatch(lc, ":(.*)")
                    local colDraft = tonumber(colStr, 10)
                    if colDraft then
                        columns = colDraft
                    end
                elseif lc == "channels: rgba" then
                    aseAlphaFound = lineCount
                elseif strsub(lc, 1, 1) == '#' then
                    tinsert(comments, strsub(line, 1))
                elseif #lc > 0 then

                    if palHeaderFound > 0
                        and palMagicFound > 0
                        and jascPalClrCountFound < 1 then
                        jascPalClrCountFound = lineCount
                    else
                        local a = 255
                        local b = 0
                        local g = 0
                        local r = 0

                        local tokens = {}
                        for token in strgmatch(line, "%S+") do
                            tinsert(tokens, token)
                        end

                        local tokensLen = #tokens
                        if tokensLen > 2 then
                            if aseAlphaFound > 0
                                and tokensLen > 3 then
                                local aPrs = tonumber(tokens[4], 10)
                                if aPrs then a = aPrs end
                            end

                            if a > 0 then
                                local bPrs = tonumber(tokens[3], 10)
                                local gPrs = tonumber(tokens[2], 10)
                                local rPrs = tonumber(tokens[1], 10)

                                if bPrs then b = bPrs end
                                if gPrs then g = gPrs end
                                if rPrs then r = rPrs end
                            end
                        end

                        -- Saturation arithmetic instead of modular.
                        if a < 0 then a = 0 elseif a > 255 then a = 255 end
                        if b < 0 then b = 0 elseif b > 255 then b = 255 end
                        if g < 0 then g = 0 elseif g > 255 then g = 255 end
                        if r < 0 then r = 0 elseif r > 255 then r = 255 end

                        local hex = (a << 0x18)
                                    | (b << 0x10)
                                    | (g << 0x08)
                                    | r
                        -- print(string.format(
                        --    "%d %d %d %d %08X",
                        --     r, g, b, a, hex))
                        tinsert(colors, hex)
                    end
                end
                -- print(line)
                lineCount = lineCount + 1
            end
            file:close()

            local uniquesOnly = args.uniquesOnly
            if uniquesOnly then
                local uniques, dict = Utilities.uniqueColors(
                    colors, true)
                colors = uniques
            end

            local prependMask = args.prependMask
            if prependMask then
                Utilities.prependMask(colors)
            end

            -- If no sprite exists, then create a new
            -- sprite and place palette swatches in it.
            local activeSprite = app.activeSprite
            if not activeSprite then
                local colorsLen = #colors

                -- Try to base sprite width on columns
                -- in GPL file. If not, find square root
                -- of colors length.
                local spriteWidth = columns
                if columns < 1 then
                    spriteWidth = math.max(8,
                    math.ceil(math.sqrt(math.max(
                        1, colorsLen))))
                end
                local spriteHeight = math.max(1,
                    math.ceil(colorsLen / spriteWidth))
                activeSprite = Sprite(spriteWidth, spriteHeight)
                local layer = activeSprite.layers[1]
                local cel = layer.cels[1]
                local image = cel.image
                local pxItr = image:pixels()

                local index = 1
                for elm in pxItr do
                    if index <= colorsLen then
                        elm(colors[index])
                        index = index + 1
                    end
                end
            end

            local oldMode = activeSprite.colorMode
            app.command.ChangePixelFormat { format = "rgb" }

            activeSprite:setPalette(
                AseUtilities.hexArrToAsePalette(colors))

            AseUtilities.changePixelFormat(oldMode)
            app.refresh()
        end

        if err ~= nil then
            app.alert("Error opening file: " .. err)
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
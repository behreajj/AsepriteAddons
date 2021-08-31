dofile("../../support/aseutilities.lua")

local defaults = {
    uniquesOnly = false,
    prependMask = true,
    pullFocus = false
}

local dlg = Dialog { title = "Import GPL" }

dlg:file {
    id = "filepath",
    label = "Path:",
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
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if activeSprite then
            local args = dlg.data
            local filepath = args.filepath
            local file, err = io.open(filepath, "r")

            -- Implicitly tries to support JASC-PAL.
            local gplHeaderFound = 0
            local palHeaderFound = 0
            local palMagicFound = 0
            local columnsFound = 0
            local nameFound = 0
            local jascPalClrCountFound = 0
            local aseAlphaFound = 0
            local comments = {}
            local colors = {}

            if file ~= nil then
                local lineCount = 1
                local linesItr = file:lines()

                for line in linesItr do
                    local lc = line:lower()

                    if lc == "gimp palette" then
                        gplHeaderFound = lineCount
                    elseif lc == "jasc-pal" then
                        palHeaderFound = lineCount
                    elseif palHeaderFound == (lineCount - 1)
                        and lc == "0100" then
                        palMagicFound = lineCount
                    elseif lc:sub(1, 4) == "name" then
                        nameFound = lineCount
                    elseif lc:sub(1, 7) == "columns" then
                        columnsFound = lineCount
                    elseif lc == "channels: rgba" then
                        aseAlphaFound = lineCount
                    elseif lc:sub(1, 1) == '#' then
                        table.insert(comments, line:sub(1))
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
                            for token in string.gmatch(line, "%S+") do
                                table.insert(tokens, token)
                            end

                            local tokensLen = #tokens
                            if tokensLen > 2 then
                                if aseAlphaFound > 0
                                    and tokensLen > 3 then
                                    local aPrs = tonumber(tokens[4])
                                    if aPrs then a = aPrs end
                                end

                                if a > 0 then
                                    local bPrs = tonumber(tokens[3])
                                    local gPrs = tonumber(tokens[2])
                                    local rPrs = tonumber(tokens[1])

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
                            -- print(string.format("%d %d %d %d %08X", r, g, b, a, hex))
                            table.insert(colors, hex)
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

                activeSprite:setPalette(
                    AseUtilities.hexArrToAsePalette(colors))
                app.refresh()
            end

            if err ~= nil then
                app.alert("Error opening file: " .. err)
            end
        end
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
dofile("../../support/aseutilities.lua")

local defaults <const> = {
    palName = "Palette",
    columns = 0,
    attribName = "Anonymous",
    attribUrl = "https://lospec.com/palette-list",
    useAseGpl = false,
    allPalettes = false
}

local dlg <const> = Dialog { title = "GPL Export" }

dlg:entry {
    id = "palName",
    label = "Palette Name:",
    text = defaults.palName,
    focus = false
}

dlg:newrow { always = false }

dlg:slider {
    id = "columns",
    label = "Columns:",
    min = 0,
    max = 16,
    value = defaults.columns
}

dlg:newrow { always = false }

dlg:entry {
    id = "attribName",
    label = "Author:",
    text = defaults.attribName,
    focus = false
}

dlg:newrow { always = false }

dlg:entry {
    id = "attribUrl",
    label = "URL:",
    text = defaults.attribUrl,
    focus = false
}

dlg:newrow { always = false }

dlg:check {
    id = "useAseGpl",
    label = "Aseprite GPL:",
    selected = defaults.useAseGpl
}

dlg:newrow { always = false }

dlg:check {
    id = "allPalettes",
    label = "All Palettes:",
    selected = defaults.allPalettes
}

dlg:newrow { always = false }

dlg:file {
    id = "filepath",
    label = "Path:",
    filetypes = { "gpl" },
    save = true,

    focus = true
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = false,
    onclick = function()
        -- Early returns.
        local activeSprite <const> = app.site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local args <const> = dlg.data
        local filepath <const> = args.filepath --[[@as string]]
        if (not filepath) or (#filepath < 1) then
            app.alert { title = "Error", text = "Filepath is empty." }
            return
        end

        local fileExt <const> = app.fs.fileExtension(filepath)
        if string.lower(fileExt) ~= "gpl" then
            app.alert { title = "Error", text = "Extension is not gpl." }
            return
        end

        -- Unpack arguments.
        local palName = args.palName or defaults.palName --[[@as string]]
        local columns <const> = args.columns or defaults.columns --[[@as integer]]
        local attribName = args.attribName or defaults.attribName --[[@as string]]
        local attribUrl = args.attribUrl or defaults.attribUrl --[[@as string]]
        local useAseGpl <const> = args.useAseGpl --[[@as boolean]]
        local allPalettes <const> = args.allPalettes --[[@as boolean]]

        -- Validate arguments.
        -- Palette name will be added no matter what.
        -- Attrib name and URL are comments, and will
        -- be omitted if they have no length.
        if #palName < 1 then palName = "Palette" end
        palName = string.sub(palName, 1, 64)
        attribName = string.sub(attribName, 1, 64)
        attribUrl = string.sub(attribUrl, 1, 96)

        local strfmt <const> = string.format
        local gplStr = strfmt(
            "GIMP Palette\nName: %s\nColumns: %d\n",
            palName, columns)

        -- https://github.com/aseprite/aseprite/
        -- blob/main/docs/gpl-palette-extension.md
        if useAseGpl then
            gplStr = gplStr .. "Channels: RGBA\n"
        end

        if #attribName > 0 then
            gplStr = gplStr .. strfmt(
                "# Author: %s\n",
                attribName)
        end

        if #attribUrl > 0 then
            gplStr = gplStr .. strfmt(
                "# URL: %s\n",
                attribUrl)
        end

        local colorSpace <const> = activeSprite.colorSpace
        if colorSpace and #colorSpace.name > 0 then
            gplStr = gplStr .. strfmt(
                "# Profile: %s\n",
                colorSpace.name)
        else
            gplStr = gplStr .. "# Profile: None\n"
        end

        ---@type Palette[]
        local selectedPalettes <const> = {}
        local palettes <const> = activeSprite.palettes
        local lenPalettes <const> = #palettes
        local lenSum = 0
        if allPalettes then
            local h = 0
            while h < lenPalettes do
                h = h + 1
                local palette <const> = palettes[h]
                selectedPalettes[h] = palette
                lenSum = lenSum + #palette
            end
        else
            local palette <const> = AseUtilities.getPalette(
                app.site.frame, palettes)
            selectedPalettes[1] = palette
            lenSum = #palette
        end

        gplStr = gplStr .. strfmt(
            "# Colors: %d\n", lenSum)

        ---@type string[]
        local entryStrArr <const> = {}
        local lenSelected <const> = #selectedPalettes
        local i = 0
        local k = 0
        while i < lenSelected do
            i = i + 1
            local palette <const> = selectedPalettes[i]
            local lenPaletten1 <const> = #palette - 1

            local j = -1
            while j < lenPaletten1 do
                j = j + 1
                local aseColor <const> = palette:getColor(j)
                local r <const> = aseColor.red
                local g <const> = aseColor.green
                local b <const> = aseColor.blue

                local entryStr = ""
                if useAseGpl then
                    local a <const> = aseColor.alpha
                    entryStr = strfmt(
                        "%03d %03d %03d %03d 0x%08x",
                        r, g, b, a,
                        a << 0x18 | b << 0x10 | g << 0x08 | r)
                else
                    entryStr = strfmt(
                        "%03d %03d %03d %06X",
                        r, g, b,
                        r << 0x10 | g << 0x08 | b)
                end

                k = k + 1
                entryStrArr[k] = entryStr
            end
        end

        gplStr = gplStr .. table.concat(entryStrArr, '\n')

        local file <const>, err <const> = io.open(filepath, "w")
        if file then
            file:write(gplStr)
            file:close()
        end

        if err then
            app.alert { title = "Error", text = err }
            return
        end

        app.alert { title = "Success", text = "File exported." }
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
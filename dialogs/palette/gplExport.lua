dofile("../../support/aseutilities.lua")

local defaults = {
    palName = "Palette",
    columns = 0,
    attribName = "Anonymous",
    attribUrl = "https://lospec.com/palette-list",
    useAseGpl = false,
    allPalettes = false
}

local dlg = Dialog { title = "GPL Export" }

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
    focus = true,
    filetypes = { "gpl" },
    save = true
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        -- Cache functions.
        local strfmt = string.format

        -- Unpack arguments.
        local args = dlg.data
        local palName = args.palName or defaults.palName
        local columns = args.columns or defaults.columns
        local attribName = args.attribName or defaults.attribName
        local attribUrl = args.attribUrl or defaults.attribUrl
        local useAseGpl = args.useAseGpl
        local allPalettes = args.allPalettes

        -- Validate arguments.
        -- Palette name will be added no matter what.
        -- Attrib name and URL are comments, and will
        -- be omitted if they have no length.
        if #palName < 1 then palName = "Palette" end
        palName = palName:sub(1, 64)
        attribName = attribName:sub(1, 64)
        attribUrl = attribUrl:sub(1, 96)

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

        local colorSpace = activeSprite.colorSpace
        if colorSpace and #colorSpace.name > 0 then
            gplStr = gplStr .. strfmt(
                "# Profile: %s\n",
                colorSpace.name)
        else
            gplStr = gplStr .. "# Profile: None\n"
        end

        local palettes = activeSprite.palettes
        local lenPalettes = #palettes
        local selectedPalettes = {}
        local lenSum = 0
        if allPalettes then
            local h = 0
            while h < lenPalettes do
                h = h + 1
                local palette = palettes[h]
                selectedPalettes[h] = palette
                lenSum = lenSum + #palette
            end
        else
            local palette = AseUtilities.getPalette(
                app.activeFrame, palettes)
            selectedPalettes[1] = palette
            lenSum = #palette
        end

        gplStr = gplStr .. strfmt(
            "# Colors: %d\n", lenSum)

        local entryStrArr = {}
        local lenSelected = #selectedPalettes
        local i = 0
        local k = 0
        while i < lenSelected do
            i = i + 1
            local palette = selectedPalettes[i]
            local lenPaletten1 = #palette - 1

            local j = -1
            while j < lenPaletten1 do
                j = j + 1
                local aseColor = palette:getColor(j)
                local r = aseColor.red
                local g = aseColor.green
                local b = aseColor.blue

                local entryStr = ""
                if useAseGpl then
                    local a = aseColor.alpha
                    entryStr = strfmt(
                        "%3d %3d %3d %3d 0x%08x",
                        r, g, b, a,
                        a << 0x18 | b << 0x10 | g << 0x08 | r)
                else
                    entryStr = strfmt(
                        "%3d %3d %3d %06X",
                        r, g, b,
                        r << 0x10 | g << 0x08 | b)
                end

                k = k + 1
                entryStrArr[k] = entryStr
            end
        end

        gplStr = gplStr .. table.concat(entryStrArr, '\n')

        local filepath = args.filepath
        if filepath and #filepath > 0 then
            -- app.fs.isFile doesn't apply to files that have been
            -- typed in by the user, but haven't been created.
            local ext = app.fs.fileExtension(filepath)
            if ext ~= "gpl" then
                app.alert("Extension is not gpl.")
            else
                local file, err = io.open(filepath, "w")
                if file then
                    file:write(gplStr)
                    file:close()
                end

                if err then
                    app.alert("Error saving file: " .. err)
                end
            end
        else
            app.alert { title = "Error", text = "Filepath is empty." }
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

dlg:show { wait = false }
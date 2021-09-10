dofile("../../support/aseutilities.lua")

local defaults = {
    palName = "Palette",
    columns = 0,
    attribName = "Anonymous",
    attribUrl = "https://lospec.com/palette-list",
    useAseGpl = false
}

local dlg = Dialog {
    title = "GPL Export"
}

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

dlg:file {
    id = "filepath",
    label = "Path:",
    filetypes = { "gpl" },
    save = true
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if activeSprite then
            local oldMode = activeSprite.colorMode
            app.command.ChangePixelFormat { format = "rgb" }

            local args = dlg.data

            -- Cache functions.
            local min = math.min
            local max = math.max
            local strfmt = string.format

            -- Unpack arguments.
            local palName = args.palName or defaults.palName
            local columns = args.columns or defaults.columns
            local attribName = args.attribName or defaults.attribName
            local attribUrl = args.attribUrl or defaults.attribUrl
            local useAseGpl = args.useAseGpl

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

            local pal = activeSprite.palettes[1]
            local palLen = #pal
            gplStr = gplStr .. strfmt(
                "# Colors: %d\n",
                palLen)

            local palLenn1 = palLen - 1
            for i = 0, palLenn1, 1 do
                local aseColor = pal:getColor(i)

                local r = max(0, min(255, aseColor.red))
                local g = max(0, min(255, aseColor.green))
                local b = max(0, min(255, aseColor.blue))

                if useAseGpl then
                    local a = max(0, min(255, aseColor.alpha))

                    local hexAbgr = (a << 0x18)
                        | (b << 0x10)
                        | (g << 0x08)
                        | r

                    gplStr = gplStr .. strfmt(
                        "%3d %3d %3d %3d 0x%08x",
                        r, g, b, a, hexAbgr)
                else
                    local hexRgb = (r << 0x10)
                        | (g << 0x08)
                        | b

                    gplStr = gplStr .. strfmt(
                        "%3d %3d %3d %06X",
                        r, g, b, hexRgb)
                end

                if i < palLenn1 then
                    gplStr = gplStr .. '\n'
                end
            end

            local filepath = args.filepath
            if filepath and #filepath > 0 then
                -- app.fs.isFile doesn't apply to files
                -- that have been typed in by the user,
                -- but have not yet been created.
                local ext = app.fs.fileExtension(filepath)
                if ext ~= "gpl" then
                    app.alert("Extension is not gpl.")
                else
                    local file = io.open(filepath, "w")
                    file:write(gplStr)
                    file:close()
                end
            else
                app.alert("Filepath is empty.")
            end

            -- TODO: Replace this and other instances with
            -- AseUtilities.changePixelFormat.
            AseUtilities.changePixelFormat(oldMode)
            app.refresh()

            dlg:close()
        else
            app.alert("There is no active sprite.")
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

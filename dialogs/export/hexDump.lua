local importFileExts <const> = {
    "aco", "act", "anim", "ase", "aseprite", "bmp", "ham",
    "hex", "iff", "ilbm", "pbm", "pgm", "ppm", "txt"
}
local exportFileExts <const> = { "csv", "md", "txt" }
local outputTypes <const> = { "FILE", "PRINT" }
local inputTypes <const> = { "CEL", "FILE" }

local defaults <const> = {
    inputType = "FILE",
    outputType = "PRINT",
    useColLabel = true,
    useRowLabel = true,
    useFilename = true,
    usePlainText = true
}

local dlg <const> = Dialog { title = "Hex Dump" }

dlg:combobox {
    id = "inputType",
    label = "Input:",
    option = defaults.inputType,
    options = inputTypes,
    focus = true,
    onchange = function()
        local args <const> = dlg.data
        local inputType <const> = args.inputType
        local isFile <const> = inputType == "FILE"
        dlg:modify { id = "importFilepath", visible = isFile }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "importFilepath",
    label = "File:",
    filetypes = importFileExts,
    open = true,
    focus = false,
    visible = defaults.inputType == "FILE"
}

dlg:newrow { always = false }

dlg:check {
    id = "useColLabel",
    label = "Labels:",
    text = "Columns",
    selected = defaults.useColLabel,
    focus = false
}

dlg:check {
    id = "useRowLabel",
    text = "Rows",
    selected = defaults.useRowLabel,
    focus = false
}

dlg:newrow { always = false }

dlg:check {
    id = "useFilename",
    text = "Filename",
    selected = defaults.useFilename,
    focus = false
}

dlg:check {
    id = "usePlainText",
    text = "Character",
    selected = defaults.usePlainText,
    focus = false
}

dlg:newrow { always = false }

dlg:combobox {
    id = "outputType",
    label = "Output:",
    option = defaults.outputType,
    options = outputTypes,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local outputType <const> = args.outputType
        local isFile <const> = outputType == "FILE"
        dlg:modify { id = "exportFilepath", visible = isFile }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "exportFilepath",
    filetypes = exportFileExts,
    save = true,
    focus = false,
    visible = defaults.outputType == "FILE"
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    onclick = function()
        local args <const> = dlg.data
        local inputType <const> = args.inputType
            or defaults.inputType --[[@as string]]
        local importFilepath <const> = args.importFilepath --[[@as string]]
        local outputType <const> = args.outputType
            or defaults.outputType --[[@as string]]
        local exportFilepath <const> = args.exportFilepath --[[@as string]]

        local useColLabel = args.useColLabel --[[@as boolean]]
        local useRowLabel = args.useRowLabel --[[@as boolean]]
        local useFilename = args.useFilename --[[@as boolean]]
        local useUtf8 = args.usePlainText --[[@as boolean]]

        local diplayFilepath = importFilepath
        local binData = ""
        if inputType == "FILE" then
            if (not importFilepath) or (#importFilepath < 1)
                or (not app.fs.isFile(importFilepath)) then
                app.alert {
                    title = "Error",
                    text = "Invalid import file path."
                }
                return
            end

            local readFile <const>, readErr <const> = io.open(importFilepath, "rb")
            if readErr ~= nil then
                if readFile then readFile:close() end
                app.alert { title = "Error", text = readErr }
                return
            end
            if readFile == nil then return end
            binData = readFile:read("a")
            readFile:close()
        else
            local site <const> = app.site
            local activeSprite <const> = site.sprite
            if not activeSprite then
                app.alert {
                    title = "Error",
                    text = "There is no active sprite."
                }
                return
            end

            local activeLayer <const> = site.layer
            if not activeLayer then
                app.alert {
                    title = "Error",
                    text = "There is no active layer."
                }
                return
            end

            local activeFrame <const> = site.frame
            if not activeFrame then
                app.alert {
                    title = "Error",
                    text = "There is no active frame."
                }
                return
            end

            local activeCel <const> = activeLayer:cel(activeFrame)
            if not activeCel then
                app.alert {
                    title = "Error",
                    text = "There is no active cel."
                }
                return
            end

            binData = activeCel.image.bytes
            diplayFilepath = activeSprite.filename
        end

        local lenBinData <const> = #binData
        local strbyte <const> = string.byte
        local strfmt <const> = string.format
        local strchar <const> = string.char
        local tconcat <const> = table.concat

        local useMarkdown = false
        local useCsv = false
        if outputType == "FILE" and exportFilepath and #exportFilepath > 0 then
            local fileExt = string.lower(app.fs.fileExtension(exportFilepath))
            useMarkdown = fileExt == "md"
            useCsv = fileExt == "csv"

            if useCsv then
                useColLabel = false
                useRowLabel = false
                useFilename = false
                useUtf8 = false
            end
        end

        local colDelimiter = " "
        if useMarkdown then
            colDelimiter = "|"
        elseif useCsv then
            colDelimiter = ","
        end

        local rowDelimiter = "\n"

        local byteFormat = "%02X"
        if useCsv then
            byteFormat = "%03d"
        end

        ---@type string[]
        local hexLines <const> = {}

        if useFilename then
            hexLines[#hexLines + 1] = diplayFilepath .. "\n"
        end

        if useColLabel then
            local headerStr = ""
            if useMarkdown then
                if useRowLabel then headerStr = headerStr .. "Row | " end
                headerStr = headerStr .. "00 | 01 | 02 | 03 | 04 | 05 | 06 | 07 | 08 | 09 | 0A | 0B | 0C | 0D | 0E | 0F"
                if useUtf8 then
                    headerStr = headerStr .. " | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 0 | 1 | 2 | 3 | 4 | 5"
                end
            else
                if useRowLabel then headerStr = headerStr .. "         " end
                headerStr = headerStr .. "00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F"
                if useUtf8 then
                    headerStr = headerStr .. " 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5"
                end
            end

            local headerSep = ""
            if useMarkdown then
                if useRowLabel then headerSep = headerSep .. "---: | " end
                headerSep = headerSep .. string.rep("---:", 16, " | ")
                if useUtf8 then
                    headerSep = headerSep .. " | " .. string.rep(":---:", 16, " | ")
                end
            else
                if useRowLabel then headerSep = headerSep .. "         " end
                headerSep = headerSep .. "-----------------------------------------------"
                if useUtf8 then
                    headerSep = headerSep .. "--------------------------------"
                end
            end

            hexLines[#hexLines + 1] = headerStr
            hexLines[#hexLines + 1] = headerSep
        end

        local cols <const> = 16
        local rows <const> = math.ceil(lenBinData / 16)

        local row = 0
        while row < rows do
            ---@type string[]
            local colStrs <const> = {}

            local rowCols <const> = row * cols
            if useRowLabel then
                -- colStrs[#colStrs + 1] = strfmt("%08X |", rowCols)
                colStrs[#colStrs + 1] = strfmt("%08X", rowCols)
            end

            ---@type integer[]
            local bytes = {}

            local col = 0
            while col < cols do
                local i <const> = 1 + col + rowCols
                if i <= lenBinData then
                    local byte <const> = strbyte(binData, i, i)
                    bytes[#bytes + 1] = byte
                    colStrs[#colStrs + 1] = strfmt(byteFormat, byte)
                else
                    colStrs[#colStrs + 1] = "  "
                end
                col = col + 1
            end

            if useUtf8 then
                -- colStrs[#colStrs + 1] = "|"

                local lenBytes <const> = #bytes
                local j = 0
                while j < lenBytes do
                    j = j + 1
                    local byte <const> = bytes[j]
                    if byte > 0x20 and byte ~= 0x7f then
                        local char <const> = strchar(byte)
                        colStrs[#colStrs + 1] = char
                    else
                        colStrs[#colStrs + 1] = "."
                    end
                end
            end

            local colStr <const> = tconcat(colStrs, colDelimiter)
            hexLines[#hexLines + 1] = colStr

            row = row + 1
        end

        local compStr <const> = tconcat(hexLines, rowDelimiter)

        if outputType == "FILE" then
            if (not exportFilepath) or (#exportFilepath < 1) then
                app.alert {
                    title = "Error",
                    text = "Invalid export file path."
                }
                return
            end

            local writeFile <const>, writeErr <const> = io.open(exportFilepath, "w")
            if writeErr ~= nil then
                if writeFile then writeFile:close() end
                app.alert { title = "Error", text = writeErr }
                return
            end
            if writeFile == nil then return end

            writeFile:write(compStr)
            writeFile:close()

            app.alert { title = "Success", text = "Hex file saved." }
        else
            print(compStr)
        end

        app.refresh()
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
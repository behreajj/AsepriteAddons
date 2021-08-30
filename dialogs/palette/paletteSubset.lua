local dlg = Dialog { title = "Palette Subset" }

dlg:combobox {
    id = "palType",
    label = "Source:",
    option = "ACTIVE",
    options = { "ACTIVE", "FILE", "PRESET" },
    onchange = function()
        local state = dlg.data.palType

        dlg:modify {
            id = "palFile",
            visible = state == "FILE"
        }

        dlg:modify {
            id = "palPreset",
            visible = state == "PRESET"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = { "aseprite", "gpl", "pal" },
    open = true,
    visible = false
}

dlg:newrow { always = false }

dlg:entry {
    id = "palPreset",
    text = "",
    focus = false,
    visible = false
}

dlg:newrow { always = false }

dlg:slider {
        id = "startIdx",
        label = "Start Index:",
        min = 0,
        max = 255,
        value = 0
    }

dlg:newrow { always = false }

dlg:slider {
    id = "stride",
    label = "Stride:",
    min = 2,
    max = 32,
    value = 8
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = true,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = "ACTIVE",
    options = { "ACTIVE", "SAVE" },
    onchange = function()
        local md = dlg.data.target
        dlg:modify {
            id = "filepath",
            visible = md == "SAVE"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "filepath",
    filetypes = { "aseprite", "gpl", "pal" },
    save = true,
    visible = false
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        local args = dlg.data
        local activeSprite = app.activeSprite
        if activeSprite then

            local oldMode = activeSprite.colorMode
            app.command.ChangePixelFormat { format = "rgb" }

            -- TODO: Use AseUtilities method.
            local srcPal = nil
            local palType = args.palType
            if palType == "FILE" then
                local fp =  args.palFile
                if fp and #fp > 0 then
                    srcPal = Palette { fromFile = fp }
                end
            elseif palType == "PRESET" then
                local pr = args.palPreset
                if pr and #pr > 0 then
                    srcPal = Palette { fromResource = pr }
                end
            else
                srcPal = activeSprite.palettes[1]
            end

            if srcPal then

                local origin = args.startIdx
                local stride = args.stride

                local srcLen = #srcPal
                local srcClrIdx = origin % srcLen
                local srcFirstClr = srcPal:getColor(srcClrIdx)

                local prependMask = args.prependMask
                    and srcFirstClr.rgbaPixel ~= 0
                local trgPalLen = stride
                local offByOne = 0
                if prependMask then
                    offByOne = 1
                    trgPalLen = trgPalLen + 1
                end

                local trgPal = Palette(trgPalLen)
                for i = 0, stride - 1, 1 do
                    local j = i % stride
                    local k = (origin + j) % srcLen
                    trgPal:setColor(
                        offByOne + i,
                        srcPal:getColor(k))
                end

                
                -- TODO: For all cases, prepend mask FIRST, then do UNIQUES.
                -- UNIQUES IS GREEDY WHEN IT COMES TO ALPHA, prepend is less so.
                if prependMask then
                    trgPal:setColor(0, Color(0, 0, 0, 0))
                end

                -- TODO: Make this its own AseUtilities method!
                local target = args.target
                if target == "SAVE" then
                    local filepath = args.filepath
                    if filepath and #filepath > 0 then
                        trgPal:saveAs(filepath)
                    else
                        app.alert("Invalid filepath.")
                    end
                else
                    activeSprite:setPalette(trgPal)
                end
            else
                app.alert("The source palette could not be found.")
            end

            if oldMode == ColorMode.INDEXED then
                app.command.ChangePixelFormat { format = "indexed" }
            elseif oldMode == ColorMode.GRAY then
                app.command.ChangePixelFormat { format = "gray" }
            end

            app.refresh()

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
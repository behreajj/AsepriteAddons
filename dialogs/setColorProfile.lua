-- To download some profiles
-- https://ninedegreesbelow.com/photography/lcms-make-icc-profiles.html
-- https://github.com/ellelstone/elles_icc_profiles

local colorModes = {"RGB", "INDEXED", "GRAY"}
local paletteTypes = { "ACTIVE", "DEFAULT", "FILE", "PRESET" }

local defaults = {
    targetSprite = "NEW",
    width = 64,
    height = 64,
    colorMode = "RGB",
    background = Color(0, 0, 0, 0),
    paletteType = "DEFAULT",
    frames = 1,
    transfer = "CONVERT"
}

local dlg = Dialog { title = "Set Color Profile" }

dlg:combobox {
    id = "targetSprite",
    label = "Sprite:",
    option = defaults.targetSprite,
    options = {"ACTIVE", "FILE", "NEW"},
    onchange = function()
        local state = dlg.data.targetSprite
        local isNew = state == "NEW"
        dlg:modify {
            id = "spriteFile",
            visible = state == "FILE"
        }

        dlg:modify {
            id = "width",
            visible = isNew
        }
        dlg:modify {
            id = "height",
            visible = isNew
        }
        dlg:modify {
            id = "colorMode",
            visible = isNew
        }
        dlg:modify {
            id = "background",
            visible = isNew
        }
        dlg:modify {
            id = "frames",
            visible = isNew
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "spriteFile",
    open = true,
    visible = defaults.targetSprite == "FILE"
}

dlg:newrow { always = false }

dlg:number {
    id = "width",
    -- label = "Width:",
    label = "Size:",
    text = string.format("%.0f", defaults.width),
    decimals = 0,
    visible = defaults.targetSprite == "NEW"
}

dlg:number {
    id = "height",
    -- label = "Height:",
    text = string.format("%.0f", defaults.height),
    decimals = 0,
    visible = defaults.targetSprite == "NEW"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "colorMode",
    label = "Color Mode:",
    option = "RGB",
    options = colorModes,
    visible = defaults.targetSprite == "NEW",
    onchange = function()
        local state = dlg.data.colorMode
        dlg:modify {
            id = "background",
            visible = state ~= "INDEXED"
        }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "background",
    label = "Background:",
    color = defaults.background,
    visible = defaults.targetSprite == "NEW"
        and defaults.colorMode ~= "INDEXED"
}

dlg:newrow { always = false }

dlg:slider {
    id = "frames",
    label = "Frames:",
    min = 1,
    max = 64,
    value = defaults.frames
}

dlg:separator {}

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = defaults.paletteType,
    options = paletteTypes,
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
    filetypes = { "gpl", "pal" },
    open = true,
    visible = defaults.paletteType == "FILE"
}

dlg:newrow { always = false }

dlg:entry {
    id = "palPreset",
    text = "",
    focus = false,
    visible = defaults.paletteType == "PRESET"
}

dlg:separator {}

dlg:file {
    id = "prf",
    label = "Profile:",
    filetypes = { "icc" },
    open = true,
    visible = true
}

dlg:newrow { always = false }

dlg:combobox {
    id = "transfer",
    label = "Transfer:",
    option = defaults.transfer,
    options = { "ASSIGN", "CONVERT" }
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then

            -- Set palette.
            local pal = nil
            local palType = args.palType
            if palType == "FILE" then
                local fp =  args.palFile
                if fp and #fp > 0 then
                    pal = Palette { fromFile = fp }
                end
            elseif palType == "PRESET" then
                local pr = args.palPreset
                if pr and #pr > 0 then
                    pal = Palette { fromResource = args.palPreset }
                end
            elseif palType == "ACTIVE" then
                local activeSprite = app.activeSprite
                if activeSprite then
                    pal = activeSprite.palettes[1]
                end
            end

            -- Search for active or file sprite.
            local sprite = nil
            local targetSprite = args.targetSprite
            if targetSprite == "FILE" then
                local pathName = args.spriteFile
                if pathName and #pathName > 0 then
                    sprite = Sprite { fromFile = pathName }
                    app.activeSprite = sprite
                end
            elseif targetSprite == "ACTIVE" then
                sprite = app.activeSprite
            end

            -- Last resort to establish a palette.
            if pal == nil or #pal < 1 then
                if sprite ~= nil then
                    pal = sprite.palettes[1]
                else
                    pal = Palette(16)
                    for i = 0, 15, 1 do
                        local val = math.tointeger(0.5 + (255 * i / 15.0))
                        pal:setColor(i, Color(val, val, val, 255))
                    end
                end
            end

            -- Create a new sprite.
            if targetSprite == "NEW" or sprite == nil then
                local w = math.max(1,
                    math.tointeger(
                    0.5 + math.abs(args.width)))
                local h = math.max(1,
                    math.tointeger(
                    0.5 + math.abs(args.height)))

                -- Create image.
                -- Do these BEFORE sprite is created
                -- and palette is set.
                local bkgClr = args.background
                local colorMode = args.colorMode
                local img = Image(w, h, ColorMode.RGB)
                local alpha = bkgClr.alpha
                local fillCels = alpha > 0 and colorMode ~= "INDEXED"
                if fillCels then
                    local itr = img:pixels()
                    local hex = bkgClr.rgbaPixel
                    for elm in itr do elm(hex) end
                end

                sprite = Sprite(w, h, ColorMode.RGB)
                sprite:setPalette(pal)
                app.activeSprite = sprite

                -- Create frames.
                local frameReqs = args.frames
                local layer = sprite.layers[1]
                local firstCel = layer.cels[1]
                firstCel.image = img
                for i = 0, frameReqs - 2, 1 do
                    sprite:newEmptyFrame()
                end

                -- Create cels.
                if fillCels then
                    local pos = Point(0, 0)
                    for i = 0, frameReqs - 2, 1 do
                        sprite:newCel(layer, i + 2, img, pos)
                    end
                end

                -- Set color mode.
                if colorMode == "INDEXED" then
                    app.command.ChangePixelFormat { format = "indexed" }
                elseif colorMode == "GRAY" then
                    app.command.ChangePixelFormat { format = "gray" }
                end
            elseif sprite ~= nil then
                local oldMode = sprite.colorMode
                app.command.ChangePixelFormat { format = "rgb" }

                sprite:setPalette(pal)

                -- if oldMode == ColorMode.INDEXED then
                --     app.command.ChangePixelFormat { format = "indexed" }
                -- elseif oldMode == ColorMode.GRAY then
                --     app.command.ChangePixelFormat { format = "gray" }
                -- end
            end

            local profilepath = args.prf
            local icc = nil
            if profilepath and #profilepath > 0 then
                icc = ColorSpace { fromFile = profilepath }
            else
                icc = ColorSpace()
            end

            if icc ~= nil then
                local transfer = args.transfer
                if transfer == "CONVERT" then
                    sprite:convertColorSpace(icc)
                else
                    sprite:assignColorSpace(icc)
                end
                app.refresh()
            else
                -- app.alert("File not found.")
            end

            dlg:close()
        else
            -- app.alert("Inputs not ok.")
        end
    end
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
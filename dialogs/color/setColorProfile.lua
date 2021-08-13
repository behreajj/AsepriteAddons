--[[ To download some profiles:
 https://ninedegreesbelow.com/photography/lcms-make-icc-profiles.html
 https://github.com/ellelstone/elles_icc_profiles --]]
local targetOptions = {"ACTIVE", "FILE", "NEW"}
local colorModes = {"RGB", "INDEXED", "GRAY"}
local paletteTypes = { "ACTIVE", "DEFAULT", "FILE", "PRESET" }
local colorSpaceTransfers = { "ASSIGN", "CONVERT" }

local defaults = {
    targetSprite = "NEW",
    width = 256,
    height = 256,
    -- TODO: Hide palette type when color mode is gray?
    colorMode = "RGB",
    background = Color(0, 0, 0, 0),
    paletteType = "DEFAULT",
    frames = 1,
    transfer = "CONVERT",
    pullFocus = true
}

local dlg = Dialog {
    title = "Set Color Profile"
}

dlg:combobox{
    id = "targetSprite",
    label = "Sprite:",
    option = defaults.targetSprite,
    options = targetOptions,
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

dlg:newrow {
    always = false
}

dlg:file {
    id = "spriteFile",
    open = true,
    visible = defaults.targetSprite == "FILE"
}

dlg:newrow {
    always = false
}

dlg:number {
    id = "width",
    label = "Size:",
    text = string.format("%.0f", defaults.width),
    decimals = 0,
    visible = defaults.targetSprite == "NEW"
}

dlg:number {
    id = "height",
    text = string.format("%.0f", defaults.height),
    decimals = 0,
    visible = defaults.targetSprite == "NEW"
}

dlg:newrow {
    always = false
}

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
    max = 96,
    value = defaults.frames
}

dlg:separator{}

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
    filetypes = {"aseprite", "gpl", "pal"},
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

dlg:separator{}

dlg:file {
    id = "prf",
    label = "Profile:",
    filetypes = {"icc"},
    open = true,
    visible = true
}

dlg:newrow { always = false }

dlg:combobox {
    id = "transfer",
    label = "Transfer:",
    option = defaults.transfer,
    options = colorSpaceTransfers
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        local palType = args.palType
        local colorMode = args.colorMode

        -- Set palette.
        local pal = nil
        if palType == "FILE" then
            local fp = args.palFile
            if fp and #fp > 0 then
                pal = Palette { fromFile = fp }
            end
        elseif palType == "PRESET" then
            local pr = args.palPreset
            if pr and #pr > 0 then
                pal = Palette { fromResource = pr }
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
                -- This doesn't use AseUtilities palette default
                -- on purpose so that the script can be copied
                -- and used without the rest of the repository.
                pal = Palette(9)
                pal:setColor(0, Color(  0,   0,   0,   0))
                pal:setColor(1, Color(  0,   0,   0, 255))
                pal:setColor(2, Color(255, 255, 255, 255))
                pal:setColor(3, Color(255,   0,   0, 255))
                pal:setColor(4, Color(255, 255,   0, 255))
                pal:setColor(5, Color(  0, 255,   0, 255))
                pal:setColor(6, Color(  0, 255, 255, 255))
                pal:setColor(7, Color(  0,   0, 255, 255))
                pal:setColor(8, Color(255,   0, 255, 255))
            end
        end

        -- Ensure that palette contains alpha in slot zero.
        local firstColor = pal:getColor(0)
        if firstColor.rgbaPixel ~= 0x0 then
            pal:resize(#pal + 1)
            for i = #pal - 1, 1, -1 do
                pal:setColor(i, pal:getColor(i - 1))
            end
            pal:setColor(0, Color(0, 0, 0, 0))
        elseif firstColor.alpha < 1 then
            -- It's possible that the first color could have
            -- non-zero channels aside from alpha.
            pal:setColor(0, Color(0, 0, 0, 0))
        end

        -- Create a new sprite.
        if targetSprite == "NEW" or sprite == nil then
            local w = args.width
            local h = args.height
            w = math.max(1, math.tointeger(0.5 + math.abs(w)))
            h = math.max(1, math.tointeger(0.5 + math.abs(h)))

            -- Create image.
            -- Do these BEFORE sprite is created
            -- and palette is set.
            local bkgClr = args.background
            local img = Image(w, h, ColorMode.RGB)
            local alpha = bkgClr.alpha
            local fillCels = alpha > 0 and colorMode ~= "INDEXED"
            if fillCels then
                local itr = img:pixels()
                local hex = bkgClr.rgbaPixel
                for elm in itr do
                    elm(hex)
                end
            end

            -- Create sprite with RGB color mode,
            -- set its palette.
            sprite = Sprite(w, h, ColorMode.RGB)
            app.activeSprite = sprite

            -- Create frames.
            local frameReqs = args.frames
            local layer = sprite.layers[1]
            local firstCel = layer.cels[1]
            firstCel.image = img
            app.transaction(function()
                for i = 0, frameReqs - 2, 1 do
                    sprite:newEmptyFrame()
                end
            end)

            -- Create cels.
            if fillCels then
                local pos = Point(0, 0)
                app.transaction(function()
                    for i = 0, frameReqs - 2, 1 do
                        sprite:newCel(layer, i + 2, img, pos)
                    end
                end)
            end

            -- Set color mode.
            if colorMode == "INDEXED" then
                app.command.ChangePixelFormat {
                    format = "indexed"
                }
            elseif colorMode == "GRAY" then
                app.command.ChangePixelFormat {
                    format = "gray"
                }
            end
        elseif sprite ~= nil then
            -- Indexed mode just cannot be trusted when loading sprites.
            app.command.ChangePixelFormat {
                format = "rgb"
            }
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
        end

        -- This needs to be set AFTER the color space
        -- assignment, otherwise it will be impacted.
        sprite:setPalette(pal)

        app.refresh()
        dlg:close()
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

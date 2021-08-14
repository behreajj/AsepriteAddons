--[[ To download some profiles:
 https://ninedegreesbelow.com/photography/lcms-make-icc-profiles.html
 https://github.com/ellelstone/elles_icc_profiles --]]
local targetOptions = {"ACTIVE", "FILE", "NEW"}
local colorModes = { "RGB", "INDEXED", "GRAY" }
local paletteTypes = { "ACTIVE", "DEFAULT", "FILE", "PRESET" }
local colorSpaceTransfers = { "ASSIGN", "CONVERT" }

local defaults = {
    targetSprite = "NEW",
    width = 256,
    height = 256,
    -- TODO: For grayscale, change color selector to
    -- 0-255 slider plus preview shades?

    -- TODO: For indexed, add a bkg index?
    colorMode = "RGB",
    background = Color(0, 0, 0, 0),
    -- This MUST be index ZERO.
    transparencyMask = 0,
    palType = "DEFAULT",
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
        local args = dlg.data
        local state = args.targetSprite
        local cm = args.colorMode

        local isNew = state == "NEW"
        local isIndex = cm == "INDEXED"

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
            visible = isNew and not isIndex
        }
        -- dlg:modify {
        --     id = "transparencyMask",
        --     visible = isNew and isIndex
        -- }
        dlg:modify {
            id = "frames",
            visible = isNew
        }

        -- Because grayscale images allow color palettes
        -- it is not a priority to hide this when gray
        -- is selected.
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
        local isIndexed = state == "INDEXED"
        dlg:modify {
            id = "background",
            visible = not isIndexed
        }
        -- dlg:modify {
        --     id = "transparencyMask",
        --     visible = isIndexed
        -- }
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

-- dlg:slider {
--     id = "transparencyMask",
--     label = "Mask Index:",
--     min = 0,
--     max = 255,
--     value = defaults.transparencyMask,
--     visible = defaults.targetSprite == "NEW"
--         and defaults.colorMode == "INDEXED"
-- }

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
    option = defaults.palType,
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
    visible = defaults.palType == "FILE"
}

dlg:newrow { always = false }

dlg:entry {
    id = "palPreset",
    text = "",
    focus = false,
    visible = defaults.palType == "PRESET"
}

dlg:separator{}

dlg:file {
    id = "prf",
    label = "Profile:",
    filetypes = { "icc" },
    open = true
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
        local palType = args.palType or defaults.palType
        local colorMode = args.colorMode or defaults.colorMode

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
        local targetSprite = args.targetSprite or defaults.targetSprite
        local reapplyIndexMode = false

        local maskClrIdx = args.transparencyMask or defaults.transparencyMask
        if targetSprite == "FILE" then
            local pathName = args.spriteFile
            if pathName and #pathName > 0 then
                sprite = Sprite { fromFile = pathName }
                app.activeSprite = sprite
                reapplyIndexMode = sprite.colorMode == ColorMode.INDEXED
                app.command.ChangePixelFormat { format = "rgb" }

                -- This MUST be index ZERO.
                sprite.transparentColor = 0
                maskClrIdx = sprite.transparentColor
            end
        elseif targetSprite == "ACTIVE" then
            sprite = app.activeSprite
            reapplyIndexMode = sprite.colorMode == ColorMode.INDEXED
            app.command.ChangePixelFormat { format = "rgb" }

            -- This MUST be index ZERO.
            sprite.transparentColor = 0
            maskClrIdx = sprite.transparentColor
        end

        -- Last resort to establish a palette.
        if pal == nil or #pal < 1 then
            if sprite ~= nil then
                pal = sprite.palettes[1]
            else
                -- This doesn't use AseUtilities palette default
                -- on purpose so that the script can be copied
                -- and used without the rest of the repository.
                pal = Palette(8)
                pal:setColor(0, Color(  0,   0,   0, 255))
                pal:setColor(1, Color(255, 255, 255, 255))
                pal:setColor(2, Color(255,   0,   0, 255))
                pal:setColor(3, Color(255, 255,   0, 255))
                pal:setColor(4, Color(  0, 255,   0, 255))
                pal:setColor(5, Color(  0, 255, 255, 255))
                pal:setColor(6, Color(  0,   0, 255, 255))
                pal:setColor(7, Color(255,   0, 255, 255))
            end
        end

        -- Ensure that mask color index is not beyond the
        -- length of the palette. If it is, then reset to 0.
        if maskClrIdx > #pal - 1 then
            maskClrIdx = 0
            if reapplyIndexMode or colorMode == "INDEXED" then
                app.alert(
                    "Mask Color index is out of bounds. "
                    .. "It has been set to zero.")
            end
        end

        -- Check that the color at the mask color index is clear.
        local maskClr = pal:getColor(maskClrIdx)
        local maskHex = maskClr.rgbaPixel
        local maskAlpha = maskClr.alpha
        local maskRgb = maskHex & 0x00ffffff
        if maskAlpha < 1 and maskRgb ~= 0 then
            -- It's possible that the first color could be
            -- transparent red, green, white, etc.
            pal:setColor(maskClrIdx, Color(0, 0, 0, 0))
        elseif maskAlpha > 0 then
            -- Loop backwards over palette, shifting entries
            -- one forward, then insert alpha mask.
            pal:resize(#pal + 1)
            for i = #pal - 1, maskClrIdx + 1, -1 do
                pal:setColor(i, pal:getColor(i - 1))
            end
            pal:setColor(maskClrIdx, Color(0, 0, 0, 0))
        end

        -- Create a new sprite.
        if targetSprite == "NEW" or sprite == nil then
            local w = args.width
            local h = args.height
            w = math.max(1, math.tointeger(0.5 + math.abs(w)))
            h = math.max(1, math.tointeger(0.5 + math.abs(h)))

            -- Create image.
            -- Do BEFORE sprite is created & palette is set.
            local bkgClr = args.background
            local img = Image(w, h, ColorMode.RGB)
            local bkgAlpha = bkgClr.alpha
            local fillCels = bkgAlpha > 0 and colorMode ~= "INDEXED"
            if fillCels then
                local itr = img:pixels()
                local hex = bkgClr.rgbaPixel
                for elm in itr do elm(hex) end
            end

            -- Create sprite with RGB color mode,
            -- set its palette.
            sprite = Sprite(w, h, ColorMode.RGB)
            sprite.transparentColor = maskClrIdx
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
        end

        -- Set color space from .icc file.
        local icc = nil
        local profilepath = args.prf

        -- TODO: Make this a user facing option?
        -- Maybe a combo box with NONE, SRGB, FILE?
        local defaultTosRgb = false
        if profilepath and #profilepath > 0 then
            icc = ColorSpace { fromFile = profilepath }
        elseif defaultTosRgb then
            icc = ColorSpace { sRGB = true }
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

        -- It doesn't seem to matter where you set this
        -- re: setting the color space, it's impacted
        -- by transform either way...
        sprite:setPalette(pal)

        -- If an active sprite or sprite from filepath
        -- is indexed color mode, its colors may be
        -- screwed up due to a transparent mask being
        -- prepended to the palette.
        if reapplyIndexMode then
            app.command.ChangePixelFormat {
                format = "indexed"
            }
        end

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

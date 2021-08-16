--[[ To download some profiles:
 https://ninedegreesbelow.com/photography/lcms-make-icc-profiles.html
 https://github.com/ellelstone/elles_icc_profiles --]]
local targetOptions = { "ACTIVE", "FILE", "NEW" }
local colorModes = { "RGB", "INDEXED", "GRAY" }
local paletteTypes = { "ACTIVE", "DEFAULT", "FILE", "PRESET" }
local colorSpaceTypes = { "FILE", "NONE", "S_RGB" }
local colorSpaceTransfers = { "ASSIGN", "CONVERT" }

local function updateColorPreviewRgba(dialog)
    local args = dialog.data
    dialog:modify {
        id = "preview",
        colors = { Color(
            args.rChannel,
            args.gChannel,
            args.bChannel,
            args.aChannel) }
    }
end

local function updateColorPreviewGray(dialog)
    local args = dialog.data
    dialog:modify {
        id = "preview",
        colors = { Color {
            gray = args.grayChannel,
            alpha = args.aChannel } }
    }
end

local defaults = {
    targetSprite = "NEW",
    width = 256,
    height = 256,
    -- TODO: For indexed, add a bkg index?
    colorMode = "RGB",
    rChannel = 0,
    gChannel = 0,
    bChannel = 0,
    aChannel = 0,
    grayChannel = 0,
    transparencyMask = 0, -- This MUST be index ZERO.
    bkgIdx = 0,
    palType = "DEFAULT",
    frames = 1,
    duration = 100.0,
    spaceType = "FILE",
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
        local isRgb = cm == "RGB"
        local isIndexed = cm == "INDEXED"
        local minAlpha = args.aChannel > 0

        dlg:modify { id = "spriteFile", visible = state == "FILE" }
        dlg:modify { id = "width", visible = isNew }
        dlg:modify { id = "height", visible = isNew }
        dlg:modify { id = "colorMode", visible = isNew }

        dlg:modify { id = "preview", visible = isNew and not isIndexed }
        dlg:modify { id = "aChannel", visible = isNew and not isIndexed }

        dlg:modify { id = "bChannel", visible = minAlpha and isNew and isRgb }
        dlg:modify { id = "gChannel", visible = minAlpha and isNew and isRgb }
        dlg:modify { id = "rChannel", visible = minAlpha and isNew and isRgb }
        dlg:modify { id = "grayChannel", visible = minAlpha and isNew and cm == "GRAY" }

        -- dlg:modify { id = "transparencyMask", visible = isNew and isIndexed }
        dlg:modify { id = "bkgIdx", visible = isNew and isIndexed }

        dlg:modify { id = "framesSep", visible = isNew }
        dlg:modify { id = "frames", visible = isNew }
        dlg:modify { id = "duration", visible = isNew }
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

dlg:newrow { always = false }

dlg:combobox {
    id = "colorMode",
    label = "Color Mode:",
    option = "RGB",
    options = colorModes,
    visible = defaults.targetSprite == "NEW",
    onchange = function()
        local args = dlg.data
        local state = args.colorMode
        local isIndexed = state == "INDEXED"
        local isGray = state == "GRAY"
        local isRgb = state == "RGB"
        local minAlpha = args.aChannel > 0

        dlg:modify { id = "preview", visible = not isIndexed }
        dlg:modify { id = "aChannel", visible = not isIndexed }

        dlg:modify { id = "bChannel", visible = minAlpha and isRgb }
        dlg:modify { id = "gChannel", visible = minAlpha and isRgb }
        dlg:modify { id = "rChannel", visible = minAlpha and isRgb }

        dlg:modify { id = "grayChannel", visible = minAlpha and isGray }

        -- dlg:modify { id = "transparencyMask", visible = isIndexed }
        dlg:modify { id = "bkgIdx", visible = isIndexed }

        if isRgb then
            updateColorPreviewRgba(dlg)
        elseif isGray then
            updateColorPreviewGray(dlg)
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "preview",
    label = "Background:",
    mode = "pick",
    colors = { Color(
        defaults.rChannel,
        defaults.gChannel,
        defaults.bChannel,
        defaults.aChannel) },
    visible = defaults.targetSprite == "NEW"
        and defaults.colorMode ~= "INDEXED",
    onclick=function(ev)
        if ev.button == MouseButton.LEFT then
            app.fgColor = ev.color
        elseif ev.button == MouseButton.RIGHT then
            -- Bug where assigning to app.bgColor leads to
            -- unlocked palette color assignment instead.
            -- app.bgColor = ev.color
            app.command.SwitchColors()
            app.fgColor = ev.color
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "aChannel",
    label = "Alpha:",
    min = 0,
    max = 255,
    value = defaults.aChannel,
    visible = defaults.targetSprite == "NEW"
        and defaults.colorMode ~= "INDEXED",
    onchange = function()

        local args = dlg.data
        local cm = args.colorMode
        local isRgb = cm == "RGB"
        local isGray = cm == "GRAY"
        if isRgb then
            updateColorPreviewRgba(dlg)
        elseif isGray then
            updateColorPreviewGray(dlg)
        end

        if args.aChannel < 1 then
            dlg:modify { id = "bChannel", visible = false }
            dlg:modify { id = "gChannel", visible = false }
            dlg:modify { id = "rChannel", visible = false }
            dlg:modify { id = "grayChannel", visible = false }
        else
            dlg:modify { id = "bChannel", visible = isRgb }
            dlg:modify { id = "gChannel", visible = isRgb }
            dlg:modify { id = "rChannel", visible = isRgb }
            dlg:modify { id = "grayChannel", visible = isGray }
        end
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "rChannel",
    -- label = "Red:",
    label = "RGB:",
    min = 0,
    max = 255,
    value = defaults.rChannel,
    visible = defaults.targetSprite == "NEW"
        and defaults.colorMode == "RGB"
        and defaults.aChannel > 0,
    onchange = function()
        updateColorPreviewRgba(dlg)
    end
}

-- dlg:newrow { always = false }

dlg:slider {
    id = "gChannel",
    -- label = "Green:",
    min = 0,
    max = 255,
    value = defaults.gChannel,
    visible = defaults.targetSprite == "NEW"
        and defaults.colorMode == "RGB"
        and defaults.aChannel > 0,
    onchange = function()
        updateColorPreviewRgba(dlg)
    end
}

-- dlg:newrow { always = false }

dlg:slider {
    id = "bChannel",
    -- label = "Blue:",
    min = 0,
    max = 255,
    value = defaults.bChannel,
    visible = defaults.targetSprite == "NEW"
        and defaults.colorMode == "RGB"
        and defaults.aChannel > 0,
    onchange = function()
        updateColorPreviewRgba(dlg)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "grayChannel",
    label = "Value:",
    min = 0,
    max = 255,
    value = defaults.grayChannel,
    visible = defaults.targetSprite == "NEW"
        and defaults.colorMode == "GRAY"
        and defaults.aChannel > 0,
    onchange = function()
        updateColorPreviewGray(dlg)
    end
}

-- dlg:newrow { always = false }
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
    id = "bkgIdx",
    label = "Bkg Index:",
    min = 0,
    max = 255,
    value = defaults.bkgIdx,
    visible = defaults.targetSprite == "NEW"
        and defaults.colorMode == "INDEXED"
}

dlg:separator{
    id = "framesSep",
    visible = defaults.targetSprite == "NEW"
}

dlg:slider {
    id = "frames",
    label = "Frames:",
    min = 1,
    max = 96,
    value = defaults.frames,
    visible = defaults.targetSprite == "NEW"
}

dlg:newrow { always = false }

dlg:number {
    id = "duration",
    label = "Duration:",
    text = string.format("%.1f", defaults.duration),
    decimals = 1,
    visible = defaults.targetSprite == "NEW"
}

dlg:separator{}

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = defaults.palType,
    options = paletteTypes,
    onchange = function()
        local state = dlg.data.palType
        dlg:modify { id = "palFile", visible = state == "FILE" }
        dlg:modify { id = "palPreset", visible = state == "PRESET" }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = { "aseprite", "gpl", "pal" },
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

dlg:combobox {
    id = "spaceType",
    label = "Profile:",
    option = defaults.spaceType,
    options = colorSpaceTypes,
    onchange = function()
        local state = dlg.data.spaceType
        dlg:modify { id = "prf", visible = state == "FILE" }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "prf",
    filetypes = { "icc" },
    open = true,
    visible = defaults.spaceType == "FILE"
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

                if colorMode == "GRAY" then
                    local grayTones = 16
                    local toGray = 255.0 / (grayTones - 1.0)
                    pal = Palette(grayTones)
                    for i = 0, grayTones - 1, 1 do
                        pal:setColor(i, Color {
                            gray = math.tointeger(0.5 + i * toGray),
                            alpha = 255 })
                    end
                else
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
            local bkgClr = Color(0, 0, 0, 0)
            local img = nil
            if colorMode == "INDEXED" then
                local bkgIdx = args.bkgIdx or defaults.bkgIdx
                if bkgIdx > #pal - 1 or bkgIdx < 0 then
                    app.alert("Background color index is out of bounds.")
                else
                    bkgClr = pal:getColor(bkgIdx)
                end
                img = Image(w, h, ColorMode.RGB)
            elseif colorMode == "GRAY" then
                bkgClr = Color {
                    gray = args.grayChannel or defaults.grayChannel,
                    alpha= args.aChannel or defaults.aChannel }
                img = Image(w, h, ColorMode.RGB)
            else
                bkgClr = Color(
                    args.rChannel or defaults.rChannel,
                    args.gChannel or defaults.gChannel,
                    args.bChannel or defaults.bChannel,
                    args.aChannel or defaults.aChannel)
                img = Image(w, h, ColorMode.RGB)
            end

            local bkgAlpha = bkgClr.alpha
            local fillCels = bkgAlpha > 0
            if fillCels then
                local hex = bkgClr.rgbaPixel
                local itr = img:pixels()
                for elm in itr do elm(hex) end
            end

            -- Create sprite with RGB color mode,
            -- set its palette.
            sprite = Sprite(w, h, ColorMode.RGB)
            sprite.transparentColor = maskClrIdx
            app.activeSprite = sprite

            -- Create frames.
            local frameReqs = args.frames or defaults.frames
            local duration = args.duration or defaults.duration
            duration = duration * 0.001

            local firstFrame = sprite.frames[1]
            firstFrame.duration = duration
            local layer = sprite.layers[1]
            local firstCel = layer.cels[1]
            firstCel.image = img
            app.transaction(function()
                for i = 0, frameReqs - 2, 1 do
                    local frame = sprite:newEmptyFrame()
                    frame.duration = duration
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

            -- Set color mode. Gray is set before the palette,
            -- so that arbitrary color palettes can be assigned;
            -- indexed palette needs to be assigned after.
            if colorMode == "INDEXED" then
                reapplyIndexMode = true
            elseif colorMode == "GRAY" then
                app.command.ChangePixelFormat {
                    format = "gray"
                }
            end
        end

        -- Set color space from .icc file.
        local icc = nil
        local spaceType = args.spaceType or defaults.spaceType
        icc = nil
        if spaceType == "FILE" then
            local profilepath = args.prf
            if profilepath and #profilepath > 0 then
                icc = ColorSpace { fromFile = profilepath }
            end
        elseif spaceType == "S_RGB" then
            icc = ColorSpace { sRGB = true }
        end

        -- May be nil as a result of malformed filepath.
        if icc == nil then icc = ColorSpace() end
        local transfer = args.transfer
        if transfer == "CONVERT" then
            sprite:convertColorSpace(icc)
        else
            sprite:assignColorSpace(icc)
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

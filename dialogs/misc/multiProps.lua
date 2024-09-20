--[[This could respond to app.preferences.range.opacity being 0 (0 to 255)
or 1 (0 to 100), some dialogs have wait=true and others wait=false, meaning the
preference could be changed after the dialog window is opened.
]]

local aniDirs <const> = {
    "FORWARD",
    "REVERSE",
    "PING_PONG",
    "PING_PONG_REVERSE",
}

local blendModes <const> = {
    "NORMAL", "DARKEN", "MULTIPLY", "COLOR_BURN",
    "LIGHTEN", "SCREEN", "COLOR_DODGE", "ADDITION",
    "OVERLAY", "SOFT_LIGHT", "HARD_LIGHT", "DIFFERENCE",
    "EXCLUSION", "SUBTRACT", "DIVIDE", "HSL_HUE",
    "HSL_SATURATION", "HSL_COLOR", "HSL_LUMINOSITY",
}

---@param aniDir AniDir
---@return string
local function aniDirToStr(aniDir)
    if aniDir == AniDir.PING_PONG then return "PING_PONG" end
    if aniDir == AniDir.PING_PONG_REVERSE then return "PING_PONG_REVERSE" end
    if aniDir == AniDir.REVERSE then return "REVERSE" end

    return "FORWARD"
end

---@param bm BlendMode
---@return string
local function blendModeToStr(bm)
    local lenBlendModes <const> = #blendModes
    local i = 0
    while i < lenBlendModes do
        i = i + 1
        local strKey <const> = blendModes[i]
        if bm == BlendMode[strKey] then return strKey end
    end
    return "NORMAL"
end

---@param layer Layer
---@return string
local function getLayerType(layer)
    if layer.isReference then return "Reference" end
    if layer.isBackground then return "Background" end
    if layer.isGroup then return "Group" end
    if layer.isTilemap then return "Tile Map" end
    return "Regular"
end

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local layer <const> = site.layer or sprite.layers[1]
local isBkg <const> = layer.isBackground
local isTilemap <const> = layer.isTilemap
local isGroup <const> = layer.isGroup

local frame <const> = site.frame or sprite.frames[1]
local cel <const> = layer:cel(frame)
local tag <const> = app.tag

local docPrefs <const> = app.preferences.document(sprite)
local tlPrefs <const> = docPrefs.timeline
local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

local dlg <const> = Dialog { title = "Properties" }

dlg:separator {
    id = "frameSep",
    text = string.format("Frame %d", frameUiOffset + frame.frameNumber),
    focus = false
}

dlg:number {
    id = "frameDuration",
    label = "Duration:",
    text = string.format("%d", math.floor(1000.0 * frame.duration + 0.5)),
    decimals = 0,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local msDur <const> = args.frameDuration --[[@as integer]]
        frame.duration = math.min(math.max(math.abs(
            msDur) * 0.001, 0.001), 65.535)
        app.refresh()
    end
}

dlg:separator {
    id = "layerSep",
    text = string.format("%s Layer", getLayerType(layer))
}

dlg:entry {
    id = "layerName",
    label = "Name:",
    text = layer.name,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local layerName <const> = args.layerName --[[@as string]]
        layer.name = layerName
        app.refresh()
    end
}

if (not isBkg) and (not isGroup) then
    dlg:newrow { always = false }

    -- This cannot have focus because it may not even be created if the layer
    -- is a group or background.
    dlg:combobox {
        id = "layerBlend",
        label = "Blend:",
        option = blendModeToStr(layer.blendMode),
        options = blendModes,
        focus = false,
        onchange = function()
            if (not isBkg) and (not isGroup) then
                local args <const> = dlg.data
                local blendStr <const> = args.layerBlend --[[@as string]]
                layer.blendMode = BlendMode[blendStr]
                app.refresh()
            end
        end
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "layerOpacity",
        label = "Opacity:",
        min = 0,
        max = 255,
        value = layer.opacity or 255,
        focus = false,
        onchange = function()
            if (not isBkg) and (not isGroup) then
                local args <const> = dlg.data
                local layerOpacity <const> = args.layerOpacity --[[@as integer]]
                layer.opacity = layerOpacity
                app.refresh()
            end
        end
    }
end

dlg:newrow { always = false }

dlg:color {
    id = "layerColor",
    label = "UI:",
    color = layer.color,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local layerColor <const> = args.layerColor --[[@as Color]]
        layer.color = AseUtilities.aseColorCopy(layerColor, "")
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "layerUserData",
    label = "User Data:",
    text = layer.data,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local layerUserData <const> = args.layerUserData --[[@as string]]
        layer.data = layerUserData
        app.refresh()
    end
}

if isTilemap then
    local tileSet <const> = layer.tileset
    if tileSet then
        -- TODO: Any way to set the allowed flip flags (X, Y, D)?

        local gridSize <const> = tileSet.grid.tileSize

        dlg:separator {
            id = "tileSep",
            text = string.format("Tileset %d x %d (#%d)",
                gridSize.width, gridSize.height, #tileSet)
        }

        dlg:entry {
            id = "tilesetName",
            label = "Name:",
            text = tileSet.name,
            focus = false,
            onchange = function()
                local args <const> = dlg.data
                local tilesetName <const> = args.tilesetName --[[@as string]]
                tileSet.name = tilesetName
                app.refresh()
            end
        }

        dlg:newrow { always = false }

        dlg:number {
            id = "tilesetBaseIndex",
            label = "Base Index:",
            text = string.format("%0d", tileSet.baseIndex),
            decimals = 0,
            focus = false,
            onchange = function()
                local args <const> = dlg.data
                local idx <const> = args.tilesetBaseIndex --[[@as integer]]
                tileSet.baseIndex = math.max(1, math.abs(idx))
                app.refresh()
            end
        }
    end
end

if cel then
    -- There are enough other ways to change a cel's position, it doesn't need
    -- to be changed here.

    local celBounds <const> = cel.bounds
    local celImage <const> = cel.image
    local celText <const> = isTilemap and
        string.format("Cel %d x %d (%d x %d)",
            celImage.width, celImage.height,
            celBounds.width, celBounds.height)
        or string.format("Cel %d x %d",
            celImage.width, celImage.height)

    dlg:separator {
        id = "celSep",
        text = celText
    }

    dlg:slider {
        id = "celZIndex",
        label = "Z Index:",
        min = -128,
        max = 127,
        value = cel.zIndex,
        focus = false,
        onchange = function()
            local args <const> = dlg.data
            local zIndex <const> = args.celZIndex --[[@as integer]]
            cel.zIndex = zIndex
            app.refresh()
        end
    }

    if not isBkg then
        dlg:newrow { always = false }

        dlg:slider {
            id = "celOpacity",
            label = "Opacity:",
            min = 0,
            max = 255,
            value = cel.opacity,
            focus = false,
            onchange = function()
                if not isBkg then
                    local args <const> = dlg.data
                    local celOpacity <const> = args.celOpacity --[[@as integer]]
                    cel.opacity = celOpacity
                    app.refresh()
                end
            end
        }
    end

    dlg:newrow { always = false }

    dlg:color {
        id = "celColor",
        label = "UI:",
        color = cel.color,
        focus = false,
        onchange = function()
            local args <const> = dlg.data
            local celColor <const> = args.celColor --[[@as Color]]
            cel.color = AseUtilities.aseColorCopy(celColor, "")
            app.refresh()
        end
    }

    dlg:newrow { always = false }

    dlg:entry {
        id = "celUserData",
        label = "User Data:",
        text = cel.data,
        focus = false,
        onchange = function()
            local args <const> = dlg.data
            local celUserData <const> = args.celUserData --[[@as string]]
            cel.data = celUserData
            app.refresh()
        end
    }
end

if tag then
    -- Problem with making to and from frames editable is that an app.tag
    -- that begins as the active will no longer be as its range moves.
    local toFrObj <const> = tag.toFrame
    local fromFrObj <const> = tag.fromFrame

    local spriteFrames <const> = sprite.frames
    local lenSpriteFrames <const> = #spriteFrames

    local toFrIdx <const> = toFrObj and toFrObj.frameNumber or 1
    local fromFrIdx <const> = fromFrObj and fromFrObj.frameNumber or 1
    local toFrIdxVrf <const> = math.min(math.max(toFrIdx, 1), lenSpriteFrames)
    local fromFrIdxVrf <const> = math.min(math.max(fromFrIdx, 1), lenSpriteFrames)

    local tagDurSecs = 0.0
    local i = fromFrIdxVrf
    while i <= toFrIdxVrf do
        local duration <const> = spriteFrames[i].duration
        tagDurSecs = tagDurSecs + duration
        i = i + 1
    end
    local tagDurMillis <const> = math.floor(tagDurSecs * 1000.0 + 0.5)

    local tagText <const> = (toFrObj and fromFrObj)
        and string.format("Tag %02d to %02d (%d ms)",
            fromFrIdx + frameUiOffset,
            toFrIdx + frameUiOffset,
            tagDurMillis)
        or "Tag"

    dlg:separator {
        id = "tagSep",
        text = tagText
    }

    dlg:entry {
        id = "tagName",
        label = "Name:",
        text = tag.name,
        focus = false,
        onchange = function()
            local args <const> = dlg.data
            local tagName <const> = args.tagName --[[@as string]]
            tag.name = tagName
            app.refresh()
        end
    }

    dlg:newrow { always = false }

    dlg:combobox {
        id = "tagAniDir",
        label = "Direction:",
        option = aniDirToStr(tag.aniDir),
        options = aniDirs,
        focus = false,
        onchange = function()
            local args <const> = dlg.data
            local aniDirStr <const> = args.tagAniDir --[[@as string]]
            tag.aniDir = AniDir[aniDirStr]
            app.refresh()
        end
    }

    dlg:newrow { always = false }

    dlg:number {
        id = "tagRepeats",
        label = "Repeats:",
        text = string.format("%d", tag.repeats),
        decimals = 0,
        focus = false,
        onchange = function()
            local args <const> = dlg.data
            local tagRepeats <const> = args.tagRepeats --[[@as integer]]
            tag.repeats = math.min(math.max(math.abs(
                tagRepeats), 0), 65535)
            app.refresh()
        end
    }

    dlg:newrow { always = false }

    dlg:color {
        id = "tagColor",
        label = "UI:",
        color = tag.color,
        focus = false,
        onchange = function()
            local args <const> = dlg.data
            local tagColor <const> = args.tagColor --[[@as Color]]
            tag.color = AseUtilities.aseColorCopy(tagColor, "")
            app.refresh()
        end
    }

    dlg:newrow { always = false }

    dlg:entry {
        id = "tagUserData",
        label = "User Data:",
        text = tag.data,
        focus = false,
        onchange = function()
            local args <const> = dlg.data
            local tagUserData <const> = args.tagUserData --[[@as string]]
            tag.data = tagUserData
            app.refresh()
        end
    }
end

dlg:separator { id = "cancelSep" }

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = true,
    onclick = function()
        dlg:close()
    end
}

-- Dialog bounds cannot be realigned because of wait = true.
dlg:show {
    autoscrollbars = true,
    wait = true
}
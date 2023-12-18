JsonUtilities = {}
JsonUtilities.__index = JsonUtilities

setmetatable(JsonUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Format string for cels.
JsonUtilities.CEL_FORMAT = table.concat({
    "{\"fileName\":\"%s\"",
    "\"bounds\":%s",
    "\"data\":%s",
    "\"frame\":%d",
    "\"layer\":%d",
    "\"opacity\":%d",
    "\"zIndex\":%d}"
}, ",")

---Format string for frames.
JsonUtilities.FRAME_FORMAT = table.concat({
    "{\"id\":%d",
    "\"duration\":%d}"
}, ",")

---Format string for layers.
JsonUtilities.LAYER_FORMAT = table.concat({
    "{\"id\":%d",
    "\"blendMode\":\"%s\"",
    "\"data\":%s",
    "\"name\":\"%s\"",
    "\"opacity\":%d",
    "\"parent\":%d",
    "\"stackIndex\":%d",
    "\"tileset\":%d}",
}, ",")

---Rectangle origin formatting presets.
JsonUtilities.RECT_OPTIONS = {
    "CENTER_FULL",
    "CENTER_HALF",
    "CORNERS",
    "TOP_LEFT"
}

---Format string for sprites.
JsonUtilities.SPRITE_FORMAT = table.concat({
    -- File name was ignored because it would
    -- require escaping \ backslashes.
    "{\"id\":%d",
    "\"colorMode\":\"%s\"",
    "\"colorSpace\":\"%s\"",
    "\"data\":%s",
    "\"pixelAspect\":%s",
    "\"size\":%s}"
}, ",")

---Format string for tags.
JsonUtilities.TAG_FORMAT = table.concat({
    "{\"fileName\":\"%s\"",
    "\"name\":\"%s\"",
    "\"aniDir\":\"%s\"",
    "\"data\":%s",
    "\"fromFrame\":%d",
    "\"toFrame\":%d",
    "\"repeats\":%d}"
}, ",")

---Format string for app version.
JsonUtilities.VERSION_FORMAT = table.concat({
    "{\"api\":%d",
    "\"major\":%d",
    "\"minor\":%d",
    "\"patch\":%d",
    "\"prerelease\":\"%s\"",
    "\"prNo\":%d}",
}, ",")

---Converts a tag animation direction to a string. "FORWARD" is returned as
---a default.
---@param ad AniDir|integer|nil animation direction
---@return string
---@nodiscard
function JsonUtilities.aniDirToStr(ad)
    if ad then
        for k, v in pairs(AniDir) do
            if ad == v then return k end
        end
    end
    return "FORWARD"
end

---Converts a layer blend mode to a string. If the layer is a group layer, it
---does not have a blend mode. "NORMAL" is returned as a default.
---@param bm BlendMode|integer|nil blend mode
---@return string
---@nodiscard
function JsonUtilities.blendModeToStr(bm)
    -- Undocumented blend modes:
    -- https://github.com/aseprite/aseprite/blob/main/src/doc/blend_mode.h#L15
    if bm then
        if bm == BlendMode.NORMAL then
            return "NORMAL"
        end
        for k, v in pairs(BlendMode) do
            if bm == v then return k end
        end
    end
    return "NORMAL"
end

---Converts a color mode to a string. "RGB" is returned as a default.
---@param cm ColorMode|integer|nil color mode
---@return string
---@nodiscard
function JsonUtilities.colorModeToStr(cm)
    if cm then
        for k, v in pairs(ColorMode) do
            if cm == v then return k end
        end
    end
    return "RGB"
end

---Fomats a cel, or table containing similar properties, as a JSON string.
---
---The filename reference allows the JSON string to locate a file in a
---directory. This function does not do any filename validation.
---
---The cel's layer property is expected to refer to the layer id, not the layer
---object itself. However, the function will attempt type checking.
---@param cel Cel|table cel or packet
---@param fileName string file name reference
---@param originFormat? string origin format
---@return string
---@nodiscard
function JsonUtilities.celToJson(cel, fileName, originFormat)
    local celDataVrf = "null"
    local celData <const> = cel.data
    if celData and #celData > 0 then
        celDataVrf = celData
    end

    local layerVrf = -1
    local layer <const> = cel.layer
    local typeLayer <const> = type(layer)
    if typeLayer == "userdata" then
        ---@diagnostic disable-next-line: undefined-field
        if layer.__name == "Layer" then layerVrf = layer.id end
    elseif typeLayer == "number"
        and math.type(layer) == "integer" then
        layerVrf = layer
    end

    return string.format(
        JsonUtilities.CEL_FORMAT,
        fileName,
        JsonUtilities.rectToJson(cel.bounds, originFormat),
        celDataVrf,
        cel.frameNumber - 1,
        layerVrf,
        cel.opacity,
        cel.zIndex)
end

---Formats a frame, or table containing the same properties, as a JSON string.
---One is subtracted from the frame number to match the indexing conventions of
---other languages. The duration is multiplied by 1000 and then floored.
---@param frame Frame|table frame or packet
---@return string
---@nodiscard
function JsonUtilities.frameToJson(frame)
    return string.format(
        JsonUtilities.FRAME_FORMAT,
        frame.frameNumber - 1,
        math.floor(frame.duration * 1000))
end

---Formats a layer, or table containing similar properties. Instead of a parent
---and stackIndex, the string contains an array of stack indices of the layer
---and of its parents.
---@param layer Layer|table
---@return string
---@nodiscard
function JsonUtilities.layerToJson(layer)
    local layerDataVrf = "null"
    local layerData <const> = layer.data
    if layerData and #layerData > 0 then
        layerDataVrf = layerData
    end

    local parentVrf = -1
    local parent <const> = layer.parent
    local typeParent <const> = type(parent)
    if typeParent == "userdata" then
        ---@diagnostic disable-next-line: undefined-field
        if parent.__name == "Layer" then parentVrf = parent.id end
    elseif typeParent == "number"
        and math.type(parent) == "integer" then
        parentVrf = parent
    end

    local tileSetVrf = -1
    local tileSet <const> = layer.tileset
    if tileSet then
        local typeTileSet <const> = type(tileSet)
        if typeTileSet == "userdata" then
            -- This is a lousy hack based on properties field.
            ---@diagnostic disable-next-line: undefined-field
            local tileSetProps <const> = tileSet.properties
            if tileSetProps["id"] then
                tileSetVrf = tileSetProps["id"]
            end
        elseif typeTileSet == "number"
            and math.type(tileSet) == "integer" then
            tileSetVrf = tileSet
        end
    end

    return string.format(
        JsonUtilities.LAYER_FORMAT,
        layer.id,
        JsonUtilities.blendModeToStr(layer.blendMode),
        layerDataVrf,
        layer.name,
        layer.opacity,
        parentVrf,
        layer.stackIndex,
        tileSetVrf)
end

---Formats a point as a JSON string.
---@param x number x coordinate
---@param y number y coordinate
---@return string
---@nodiscard
function JsonUtilities.pointToJson(x, y)
    if math.type(x) == "float"
        or math.type(y) == "float" then
        return string.format(
            "{\"x\":%.2f,\"y\":%.2f}",
            x, y)
    end
    return string.format(
        "{\"x\":%d,\"y\":%d}",
        x, y)
end

---Formats a rectangle, or table containing the same properties, as a JSON
---string. The format flag can be "CENTER_FULL", "CENTER_HALF, "CORNERS" or the
---default, "TOP_LEFT".
---@param r Rectangle|table rectangle or packet
---@param format? string origin format
---@return string
---@nodiscard
function JsonUtilities.rectToJson(r, format)
    if format == "CENTER_FULL" then
        local rw_2 <const> = r.width * 0.5
        local rh_2 <const> = r.height * 0.5
        return string.format("{\"center\":%s,\"size\":%s}",
            JsonUtilities.pointToJson(r.x + rw_2, r.y + rh_2),
            JsonUtilities.pointToJson(r.width, r.height))
    elseif format == "CENTER_HALF" then
        local rw_2 <const> = r.width * 0.5
        local rh_2 <const> = r.height * 0.5
        return string.format("{\"center\":%s,\"size\":%s}",
            JsonUtilities.pointToJson(r.x + rw_2, r.y + rh_2),
            JsonUtilities.pointToJson(rw_2, rh_2))
    elseif format == "CORNERS" then
        local xbr <const> = r.x + r.width - 1
        local ybr <const> = r.y + r.height - 1
        return string.format("{\"topLeft\":%s,\"bottomRight\":%s}",
            JsonUtilities.pointToJson(r.x, r.y),
            JsonUtilities.pointToJson(xbr, ybr))
    else
        return string.format("{\"topLeft\":%s,\"size\":%s}",
            JsonUtilities.pointToJson(r.x, r.y),
            JsonUtilities.pointToJson(r.width, r.height))
    end
end

---Formats a sprite, or table containing the same properties, as a JSON string.
---@param sprite Sprite|table sprite or packet
---@return string
---@nodiscard
function JsonUtilities.spriteToJson(sprite)
    -- User data is in 1.3 only.
    local spriteDataVrf = "null"
    local spriteData <const> = sprite.data
    if spriteData and #spriteData > 0 then
        spriteDataVrf = spriteData
    end

    local spec <const> = sprite.spec
    local pxa <const> = sprite.pixelRatio

    return string.format(
        JsonUtilities.SPRITE_FORMAT,
        sprite.id,
        JsonUtilities.colorModeToStr(spec.colorMode),
        spec.colorSpace.name,
        spriteDataVrf,
        JsonUtilities.pointToJson(pxa.width, pxa.height),
        JsonUtilities.pointToJson(spec.width, spec.height))
end

---Fomats a tag, or table containing the same properties, as a JSON string.
---
---One is subtracted from the start and end frame numbers to match the indexing
---conventions of other languages.
---
---The filename reference allows the JSON string to locate a file in a
---directory. This function does not do any filename validation.
---@param tag Tag|table tag or packet
---@param fileName string file name reference
---@return string
---@nodiscard
function JsonUtilities.tagToJson(tag, fileName)
    local tagDataVrf = "null"
    local tagData <const> = tag.data
    if tagData and #tagData > 0 then
        tagDataVrf = tagData
    end

    return string.format(
        JsonUtilities.TAG_FORMAT,
        fileName,
        tag.name,
        JsonUtilities.aniDirToStr(tag.aniDir),
        tagDataVrf,
        tag.fromFrame.frameNumber - 1,
        tag.toFrame.frameNumber - 1,
        tag.repeats)
end

---Formats the Aseprite version as a JSON string.
---@return string
---@nodiscard
function JsonUtilities.versionToJson()
    local v <const> = app.version
    return string.format(
        JsonUtilities.VERSION_FORMAT,
        app.apiVersion,
        v.major, v.minor, v.patch,
        v.prereleaseLabel,
        v.prereleaseNumber)
end

return JsonUtilities
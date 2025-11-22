dofile("../../support/aseutilities.lua")

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

---@param srcLayer Layer
---@param parent Layer|Sprite
---@param spriteColorMode ColorMode
---@return Layer trgLayer
local function copyLayer(
    srcLayer,
    parent,
    spriteColorMode)
    local trgLayer = nil
    if srcLayer.isGroup then
        trgLayer = activeSprite:newGroup()

        local useNewBlend = false
        local appPrefs <const> = app.preferences
        if appPrefs then
            local experimental <const> = appPrefs.experimental
            if experimental then
                useNewBlend = experimental.new_blend or false
            end
        end

        if useNewBlend then
            trgLayer.blendMode = srcLayer.blendMode or BlendMode.NORMAL
            trgLayer.opacity = srcLayer.opacity or 255
        end
        trgLayer.isCollapsed = srcLayer.isCollapsed

        local srcChildren <const> = srcLayer.layers
        if srcChildren then
            local lenChildren <const> = #srcChildren
            local i = 0
            while i < lenChildren do
                i = i + 1
                copyLayer(srcChildren[i], trgLayer, spriteColorMode)
            end -- End child layer loop.
        end     -- End children array exist.
    else
        trgLayer = activeSprite:newLayer()

        -- TODO: Might be able to assign duplicate properties as of
        -- https://github.com/aseprite/aseprite/commit/464781690e46b0c56906d178213f6daffdfcaee7 ?
        trgLayer.isContinuous = srcLayer.isContinuous
        trgLayer.blendMode = srcLayer.blendMode or BlendMode.NORMAL
        trgLayer.opacity = srcLayer.opacity or 255

        local frObjs <const> = activeSprite.frames
        local lenFrObjs <const> = #frObjs

        local srcIsTileMap <const> = srcLayer.isTilemap
        local srcTileSet = nil
        if srcIsTileMap then
            srcTileSet = srcLayer.tileset
        end

        local colorCopy <const> = AseUtilities.aseColorCopy
        local tileMapToImage <const> = AseUtilities.tileMapToImage

        local i = 0
        while i < lenFrObjs do
            i = i + 1
            local frObj <const> = frObjs[i]
            local srcCel <const> = srcLayer:cel(frObj)
            if srcCel then
                local srcImg = srcCel.image
                if srcIsTileMap then
                    srcImg = tileMapToImage(
                        srcCel.image,
                        srcTileSet,
                        spriteColorMode)
                end

                local trgCel <const> = activeSprite:newCel(
                    trgLayer, frObj, srcImg, srcCel.position)
                trgCel.color = colorCopy(trgCel.color, "")
                trgCel.data = trgCel.data
                trgCel.opacity = trgCel.opacity
                trgCel.zIndex = trgCel.zIndex
            end -- End source cel exists.
        end     -- End frame loop.
    end         -- End layer is group check.

    trgLayer.name = srcLayer.name .. " Copy"
    trgLayer.color = AseUtilities.aseColorCopy(srcLayer.color, "")
    trgLayer.data = srcLayer.data
    trgLayer.parent = parent

    trgLayer.isEditable = srcLayer.isEditable
    trgLayer.isVisible = srcLayer.isVisible

    return trgLayer
end

local activeLayer <const> = site.layer
    or activeSprite.layers[1]
local spriteSpec <const> = activeSprite.spec
local colorMode <const> = spriteSpec.colorMode

local includeLocked <const> = true
local includeHidden <const> = true
local includeTiles <const> = true
local includeBkg <const> = colorMode ~= ColorMode.INDEXED
local filtered <const> = AseUtilities.filterLayers(
    activeSprite, site.layer, "RANGE",
    includeLocked, includeHidden, includeTiles, includeBkg)
local lenFiltered <const> = #filtered

if lenFiltered > 1 then
    -- Layers in a range can be out of order.
    table.sort(filtered, function(a, b)
        if a.stackIndex == b.stackIndex then
            return a.name < b.name
        end
        return a.stackIndex < b.stackIndex
    end)

    app.transaction("Copy Range Layers", function()
        local parentInit <const> = filtered[1].parent
        local idInit <const> = parentInit.id
        local sameParent = true

        local i = 0
        while i < lenFiltered do
            i = i + 1
            -- Do you have to worry about sprite ID overlapping with layer IDs
            -- as a unique identifier, e.g., sprite id = 1, layer id = 1?
            sameParent = sameParent and filtered[i].parent.id == idInit
        end

        local copyParent <const> = sameParent
            and parentInit
            or activeSprite

        local j = 0
        while j < lenFiltered do
            j = j + 1
            copyLayer(filtered[j], copyParent, colorMode)
        end
    end)

    app.layer = activeLayer
else
    if activeLayer.isReference then return end
    if activeLayer.isGroup
        and (activeLayer.layers == nil
            or #activeLayer.layers <= 0) then
        return
    end
    if activeLayer.isBackground and (not includeBkg) then
        return
    end

    local name <const> = activeLayer.name
    app.transaction(
        string.format("Copy %s", #name > 0 and name or "Layer"),
        function()
            local trgLayer <const> = copyLayer(
                activeLayer,
                activeLayer.parent,
                activeSprite.colorMode)
            trgLayer.stackIndex = activeLayer.stackIndex + 1
            app.layer = trgLayer
        end)
end

app.refresh()
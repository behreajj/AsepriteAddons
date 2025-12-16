dofile("../../support/aseutilities.lua")

---@param srcSprite Sprite
---@param srcLayer Layer
---@param parent Layer|Sprite
---@param spriteColorMode ColorMode
---@return Layer trgLayer
local function copyLayer(
    srcSprite,
    srcLayer,
    parent,
    spriteColorMode)
    local trgLayer = nil

    local apiVersion <const> = app.apiVersion
    local canCopyProps <const> = apiVersion >= 38

    if srcLayer.isGroup then
        trgLayer = srcSprite:newGroup()

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
                copyLayer(srcSprite, srcChildren[i], trgLayer, spriteColorMode)
            end -- End child layer loop.
        end     -- End children array exist.
    else
        trgLayer = srcSprite:newLayer()

        trgLayer.blendMode = srcLayer.blendMode or BlendMode.NORMAL
        trgLayer.opacity = srcLayer.opacity or 255
        trgLayer.isContinuous = srcLayer.isContinuous

        local frObjs <const> = srcSprite.frames
        local lenFrObjs <const> = #frObjs

        -- TODO: Post an app alert to ask how to handle duplicating tile set
        -- vs. referring to original tile set? See
        -- https://community.aseprite.org/t/making-changes-to-a-duplicate-tileset-also-changes-the-original/
        -- Problem is how to create a new tile map layer without an app.command.
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
                local srcImg <const> = srcCel.image
                local trgImg = srcImg
                if srcIsTileMap then
                    trgImg = tileMapToImage(
                        srcImg,
                        srcTileSet,
                        spriteColorMode)
                end

                local trgCel <const> = srcSprite:newCel(
                    trgLayer, frObj, trgImg, srcCel.position)
                trgCel.color = colorCopy(srcCel.color, "")
                trgCel.data = srcCel.data
                trgCel.opacity = srcCel.opacity
                trgCel.zIndex = srcCel.zIndex

                if canCopyProps then
                    trgCel.properties = srcCel.properties
                end
            end -- End source cel exists.
        end     -- End frame loop.
    end         -- End layer is group check.

    local srcLayerNameVerif <const> = #srcLayer.name <= 0
        and "Layer"
        or srcLayer.name .. " Copy"

    trgLayer.name = srcLayerNameVerif
    trgLayer.color = AseUtilities.aseColorCopy(srcLayer.color, "")
    trgLayer.data = srcLayer.data
    trgLayer.parent = parent

    trgLayer.isEditable = srcLayer.isEditable
    trgLayer.isVisible = srcLayer.isVisible

    if canCopyProps then
        trgLayer.properties = srcLayer.properties
    end

    return trgLayer
end

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

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
            copyLayer(activeSprite, filtered[j], copyParent, colorMode)
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
                activeSprite,
                activeLayer,
                activeLayer.parent,
                activeSprite.colorMode)
            trgLayer.stackIndex = activeLayer.stackIndex + 1
            app.layer = trgLayer
        end)
end

app.refresh()
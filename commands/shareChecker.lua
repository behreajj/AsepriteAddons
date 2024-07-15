dofile("../support/aseutilities.lua")

local site <const> = app.site
local srcSprite <const> = site.sprite
if not srcSprite then return end

local appTool <const> = app.tool
if appTool then
    if appTool.id == "slice" then
        app.tool = "hand"
    end
end

local appPrefs <const> = app.preferences
local getDocPrefs <const> = appPrefs.document
local hexToAseColor <const> = AseUtilities.hexToAseColor

-- https://github.com/aseprite/aseprite/blob/main/data/pref.xml#L521
local typeCheck = 5
local useZoom = false
local wCheck = 8
local hCheck = 8
local aHex = 0xff1c1c1c
local bHex = 0xff0a0a0a

local srcDocPrefs <const> = getDocPrefs(srcSprite)
if srcDocPrefs then
    local srcBgPref <const> = srcDocPrefs.bg
    if srcBgPref then
        local typePref <const> = srcBgPref.type --[[@as integer]]
        if typePref ~= nil then
            typeCheck = typePref
        end

        local zoomPref <const> = srcBgPref.zoom --[[@as boolean]]
        if zoomPref ~= nil then
            useZoom = zoomPref
        end

        -- Depending on the checker type, the size may not be valid. E.g., if
        -- it is an 8x8 preset, not custom, and the size is 20x20, the size
        -- will be ignored.
        local checkSize <const> = srcBgPref.size --[[@as Size]]
        if checkSize ~= nil then
            wCheck = math.max(1, math.abs(checkSize.width))
            hCheck = math.max(1, math.abs(checkSize.height))
        end

        local bgPrefColor1 <const> = srcBgPref.color1 --[[@as Color]]
        if bgPrefColor1 ~= nil then
            aHex = 0xff000000 | AseUtilities.aseColorToHex(
                bgPrefColor1, ColorMode.RGB)
        end

        local bgPrefColor2 <const> = srcBgPref.color2 --[[@as Color]]
        if bgPrefColor2 ~= nil then
            bHex = 0xff000000 | AseUtilities.aseColorToHex(
                bgPrefColor2, ColorMode.RGB)
        end
    end
end

local idSrcSprite <const> = srcSprite.id
local openSprites <const> = app.sprites
local lenOpenSprites <const> = #openSprites

local h = 0
while h < lenOpenSprites do
    h = h + 1
    local trgSprite <const> = openSprites[h]
    local idTrgSprite <const> = trgSprite.id
    if idSrcSprite ~= idTrgSprite then
        local trgDocPrefs <const> = getDocPrefs(trgSprite)
        if trgDocPrefs then
            local trgBgPref <const> = trgDocPrefs.bg
            if trgBgPref then
                trgBgPref.color2 = hexToAseColor(bHex)
                trgBgPref.color1 = hexToAseColor(aHex)
                trgBgPref.size = Size(wCheck, hCheck)
                trgBgPref.zoom = useZoom
                trgBgPref.type = typeCheck
            end
        end
    end
end

app.sprite = srcSprite
app.refresh()
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

local wCheck <const>,
hCheck <const>,
aAse <const>,
bAse <const> = AseUtilities.getBkgChecker(srcSprite)

local a = 0xff000000 | AseUtilities.aseColorToHex(aAse, ColorMode.RGB)
local b = 0xff000000 | AseUtilities.aseColorToHex(bAse, ColorMode.RGB)

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
                trgBgPref.color1 = hexToAseColor(a)
                trgBgPref.color2 = hexToAseColor(b)
                trgBgPref.size = Size(wCheck, hCheck)
                trgBgPref.type = 5
            end
        end
    end
end

app.sprite = srcSprite
app.refresh()
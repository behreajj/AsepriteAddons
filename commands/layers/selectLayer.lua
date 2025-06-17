dofile("../../support/aseutilities.lua")

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local activeFrame <const> = site.frame
if not activeFrame then return end

local xMouse <const>, yMouse <const> = AseUtilities.getMouse()

if xMouse < 0 or yMouse < 0 then return end

local specSprite <const> = activeSprite.spec
local wSprite <const> = specSprite.width
local hSprite <const> = specSprite.height
local colorMode <const> = specSprite.colorMode

if xMouse >= wSprite or yMouse >= hSprite then return end

local palettes <const> = activeSprite.palettes

local keepSelection = false
local selectOnClick = false
local appPrefs <const> = app.preferences
if appPrefs then
    local tlPrefs <const> = appPrefs.timeline
    if tlPrefs then
        local keepSelPref <const> = tlPrefs.keep_selection --[[@as boolean]]
        if keepSelPref then keepSelection = true end
        local selOnClkPref <const> = tlPrefs.select_on_click --[[@as boolean]]
        if selOnClkPref then selectOnClick = true end
    end
end
local makeRange <const> = (not keepSelection)
    and selectOnClick
    and app.range.sprite == activeSprite

local a01 <const>, candidate <const> = AseUtilities.layerUnderPoint(
    activeSprite, activeFrame, xMouse, yMouse, 1.0,
    palettes, colorMode)

if a01 > 0.0 then
    app.layer = candidate
    if makeRange then app.range.layers = { candidate } end
end
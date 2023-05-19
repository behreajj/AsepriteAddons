--[[
To download some profiles:
https://ninedegreesbelow.com/photography/lcms-make-icc-profiles.html
https://github.com/ellelstone/elles_icc_profiles

For specific conversions (Adobe RGB, P3)
https://stackoverflow.com/questions/40017741/
mathematical-conversion-srgb-and-adobergb
https://www.w3.org/TR/css-color-4/#color-conversion-code
--]]
local colorSpaceTypes = { "FILE", "NONE", "SRGB" }
local continuityOps = { "NUMERIC", "VISUAL" }

local defaults = {
    colorSpaceType = "SRGB",
    continuityOp = "VISUAL",
    pullFocus = false
}

local dlg = Dialog { title = "Set Color Profile" }

dlg:combobox {
    id = "colorSpaceType",
    label = "Profile:",
    option = defaults.colorSpaceType,
    options = colorSpaceTypes,
    onchange = function()
        local state = dlg.data.colorSpaceType
        dlg:modify {
            id = "profilePath",
            visible = state == "FILE"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "profilePath",
    filetypes = { "icc" },
    open = true,
    visible = defaults.colorSpaceType == "FILE"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "continuity",
    label = "Continuity:",
    option = defaults.continuityOp,
    options = continuityOps
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local args = dlg.data
        local csType = args.colorSpaceType
            or defaults.colorSpaceType --[[@as string]]

        local newColorSpace = nil
        if csType == "FILE" then
            local profilePath = args.profilePath --[[@as string]]
            if profilePath and #profilePath > 0 then
                local isFile = app.fs.isFile(profilePath)
                if isFile then
                    newColorSpace = ColorSpace { fromFile = profilePath }
                else
                    app.alert {
                        title = "Error",
                        text = "The color profile could not be found."
                    }
                    return
                end
            end

            if not newColorSpace then
                newColorSpace = ColorSpace()
            end
        elseif csType == "SRGB" then
            newColorSpace = ColorSpace { sRGB = true }
        elseif csType == "NONE" then
            newColorSpace = ColorSpace()
        end

        -- app.preferences.color_bar.wheel_model
        -- is 2 when normal map is activated.
        -- Normal wheel maps are adversely impacted
        -- by color models other than None or SRGB.
        local formerColorSpace = activeSprite.colorSpace
        local continuity = args.continuity or defaults.continuity

        -- Yes is 1, no is 2.
        local confirm = 1
        if formerColorSpace == newColorSpace then
            confirm = app.alert {
                title = "Warning",
                text = { "The sprite already uses this color profile.",
                    "Do you wish to proceed anyway?" },
                buttons = { "&YES", "&CANCEL" }
            }
        end

        if confirm and confirm == 1 then
            if continuity == "VISUAL" then
                activeSprite:convertColorSpace(newColorSpace)
            else
                activeSprite:assignColorSpace(newColorSpace)
            end
            app.refresh()
            app.alert {
                title = "Success",
                text = "Color profile applied."
            }
        end
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
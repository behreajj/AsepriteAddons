--[[ To download some profiles:
 https://ninedegreesbelow.com/photography/lcms-make-icc-profiles.html
 https://github.com/ellelstone/elles_icc_profiles --]]

local colorSpaceTypes = { "FILE", "NONE", "SRGB" }
local continuityOps = { "NUMERIC", "VISUAL" }

local defaults = {
    colorSpaceType = "SRGB",
    continuityOp = "VISUAL",
    pullFocus = false
}

-- TODO: Move to AseUtilities.
local function fileExists(name)
    -- https://stackoverflow.com/questions/4990990/check-if-a-file-exists-with-lua
    local f = io.open(name,"r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
 end

local dlg = Dialog {
    title = "Set Color Profile"
}

dlg:combobox {
    id = "colorSpaceType",
    label = "Profile:",
    option = defaults.colorSpaceType,
    options = colorSpaceTypes,
    onchange = function()
        local state = dlg.data.colorSpaceType
        dlg:modify {
            id = "profilePath",
            visible = state == "FILE" }
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
        local args = dlg.data
        local activeSprite = app.activeSprite
        if activeSprite then
            local newColorSpace = nil
            local csType = args.colorSpaceType or defaults.colorSpaceType
            if csType == "FILE" then
                local profilePath = args.profilePath
                if profilePath and #profilePath > 0 then
                    local success = fileExists(profilePath)
                    if success then
                        newColorSpace = ColorSpace { fromFile = profilePath }
                    else
                        app.alert {
                            title = "File Not Found",
                            text = {
                                "The color profile could not be found."
                            }
                        }
                        dlg:close()
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

            local formerColorSpace = activeSprite.colorSpace
            local continuity = args.continuity or defaults.continuity
            if formerColorSpace ~= newColorSpace then
                if continuity == "VISUAL" then
                    activeSprite:convertColorSpace(newColorSpace)
                else
                    activeSprite:assignColorSpace(newColorSpace)
                end
            else
                local result = app.alert {
                    title = "Warning",
                    text = { "The sprite already uses this color profile.",
                             "Do you wish to proceed anyway?" },
                    buttons= { "&YES", "&CANCEL" } }

                if result == 1 then
                    if continuity == "VISUAL" then
                        activeSprite:convertColorSpace(newColorSpace)
                    else
                        activeSprite:assignColorSpace(newColorSpace)
                    end
                end
            end

            app.refresh()
            dlg:close()
        else
            app.alert("There is no active sprite.")
        end
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

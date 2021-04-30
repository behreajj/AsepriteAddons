-- To download some profiles
-- https://ninedegreesbelow.com/photography/lcms-make-icc-profiles.html
-- https://github.com/ellelstone/elles_icc_profiles

local dlg = Dialog { title = "Set Color Profile" }

dlg:file {
    id = "prf",
    label = "Profile",
    filetypes = { "icc" },
    open = true,
    visible = true
}

dlg:newrow { always = false }

dlg:combobox {
    id = "transfer",
    label = "TRANSFER:",
    option = "ASSIGN",
    options = { "ASSIGN", "CONVERT" }
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = app.activeSprite
            if sprite then
                local icc = ColorSpace { fromFile = args.prf }
                if icc then
                    local func = nil
                    local transfer = args.transfer
                    if transfer == "CONVERT" then
                        func = function(x)
                            sprite:convertColorSpace(x)
                        end
                    else
                        func = function(x)
                            sprite:assignColorSpace(x)
                        end
                    end

                    func(icc)
                    app.refresh()
                else
                    app.alert("File not found.")
                end
            else
                app.alert("There is no active sprite.")
            end
        else
        end
    end
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
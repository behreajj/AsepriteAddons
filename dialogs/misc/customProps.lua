dofile("../../support/aseutilities.lua")
dofile("../../support/jsonutilities.lua")

local targets <const> = {
    -- TODO: Support slice properties?
    -- TODO: Unset button.
    -- TODO: Option to choose integer format?
    "CEL",
    "FORE_TILE",
    "BACK_TILE",
    "LAYER",
    "SPRITE",
    "TAG",
    "TILE_SET"
}

local dataTypes <const> = {
    "BOOLEAN",
    "COLOR",
    "INTEGER",
    "NUMBER",
    "STRING",
}

local defaults <const> = {
    target = "SPRITE",
    dataType = "STRING",
    propName = "Property",
    boolValue = false,
    intValue = 0,
    numValue = 0.0,
    stringValue = "",
}

---@param target string
---@return table<string, any>|nil properties
---@return boolean success
---@return string errMsg
---@nodiscard
local function getProperties(target)
    if target == "CEL" then
        local activeCel <const> = app.cel
        if not activeCel then
            return nil, false, "There is no active cel."
        end
        return activeCel.properties, true, ""
    elseif target == "LAYER"
        or target == "TILE_SET"
        or target == "FORE_TILE"
        or target == "BACK_TILE" then
        local activeLayer <const> = app.layer
        if not activeLayer then
            return nil, false, "There is no active layer."
        end

        if target == "LAYER" then
            return activeLayer.properties, true, ""
        else
            if not activeLayer.isTilemap then
                return nil, false, "Active layer is not a tile map."
            end

            local tileSet <const> = activeLayer.tileset
            if not tileSet then
                return nil, false, "The active tile set could not be found."
            end

            if target == "TILE_SET" then
                return tileSet.properties, true, ""
            else
                local colorBarPrefs <const> = app.preferences.color_bar
                local tifCurr <const> = target == "BACK_TILE"
                    and colorBarPrefs["bg_tile"]
                    or colorBarPrefs["fg_tile"] --[[@as integer]]

                local tiCurr <const> = app.pixelColor.tileI(tifCurr)
                if tiCurr == 0 then
                    -- Tiles at index 0 have the same properties as the
                    -- tile sets that contain them.
                    return nil, false, "Tile set index 0 is reserved."
                end

                if tiCurr < 0 or tiCurr >= #tileSet then
                    return nil, false, string.format(
                        "The tile index %d is out of bounds.",
                        tiCurr)
                end

                local tile <const> = tileSet:tile(tiCurr)
                if not tile then
                    return nil, false, "The active tile could not be found."
                end
                return tile.properties, true, ""
            end
        end
    elseif target == "SPRITE" then
        local activeSprite <const> = app.sprite
        if not activeSprite then
            return nil, false, "There is no active sprite."
        end
        return activeSprite.properties, true, ""
    elseif target == "TAG" then
        local activeTag <const> = app.tag
        if not activeTag then
            return nil, false, "There is no active tag."
        end

        return activeTag.properties, true, ""
    end

    return nil, false, "Unrecognized target."
end


local dlg <const> = Dialog { title = "Custom Properties" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    focus = false,
}

dlg:combobox {
    id = "dataType",
    label = "Type:",
    option = defaults.dataType,
    options = dataTypes,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local dataType <const> = args.dataType --[[@as string]]

        local isBool <const> = dataType == "BOOLEAN"
        local isColor <const> = dataType == "COLOR"
        local isInt <const> = dataType == "INTEGER"
        local isNum <const> = dataType == "NUMBER"
        local isStr <const> = dataType == "STRING"

        dlg:modify { id = "boolValue", visible = isBool }
        dlg:modify { id = "colorValue", visible = isColor }
        dlg:modify { id = "intValue", visible = isInt }
        dlg:modify { id = "numValue", visible = isNum }
        dlg:modify { id = "stringValue", visible = isStr }
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "propName",
    label = "Property:",
    text = defaults.propName,
    focus = true,
}

dlg:newrow { always = false }

dlg:check {
    id = "boolValue",
    label = "Boolean:",
    selected = defaults.boolValue,
    visible = defaults.dataType == "BOOLEAN",
    focus = false
}

dlg:newrow { always = false }

dlg:color {
    id = "colorValue",
    label = "Color:",
    color = Color { r = 0, g = 0, b = 0, a = 0 },
    visible = defaults.dataType == "COLOR",
    focus = false
}

dlg:newrow { always = false }

dlg:number {
    id = "intValue",
    label = "Integer:",
    text = string.format("%d", defaults.intValue),
    decimals = 0,
    visible = defaults.dataType == "INTEGER",
    focus = false
}

dlg:newrow { always = false }

dlg:number {
    id = "numValue",
    label = "Number:",
    text = string.format("%.6f", defaults.numValue),
    decimals = 6,
    visible = defaults.dataType == "NUMBER",
    focus = false
}

dlg:newrow { always = false }

dlg:entry {
    id = "stringValue",
    label = "String:",
    text = defaults.stringValue,
    visible = defaults.dataType == "STRING",
    focus = false,
}

dlg:newrow { always = false }

dlg:button {
    id = "get",
    text = "&GET",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]
        local dataType <const> = args.dataType --[[@as string]]
        local propName <const> = args.propName --[[@as string]]

        local properties <const>,
        success <const>,
        errMsg <const> = getProperties(target)
        if (not properties) or (not success) then
            app.alert { title = "Error", text = errMsg }
            return
        end

        local query <const> = properties[propName]
        local typeQuery <const> = type(query)
        if typeQuery == "boolean" then
            dlg:modify { id = "dataType", option = "BOOLEAN" }

            dlg:modify { id = "boolValue", visible = true }
            dlg:modify { id = "colorValue", visible = false }
            dlg:modify { id = "intValue", visible = false }
            dlg:modify { id = "numValue", visible = false }
            dlg:modify { id = "stringValue", visible = false }

            dlg:modify { id = "boolValue", selected = query }
        elseif typeQuery == "number" then
            dlg:modify { id = "boolValue", visible = false }
            dlg:modify { id = "stringValue", visible = false }

            if math.type(query) == "integer" then
                dlg:modify { id = "numValue", visible = false }
                if dataType ~= "COLOR" or (query >> 0x20 ~= 0) then
                    dlg:modify { id = "dataType", option = "INTEGER" }

                    dlg:modify { id = "colorValue", visible = false }
                    dlg:modify { id = "intValue", visible = true }

                    dlg:modify {
                        id = "intValue",
                        text = string.format("%d", query)
                    }
                else
                    dlg:modify { id = "colorValue", visible = true }
                    dlg:modify { id = "intValue", visible = false }

                    dlg:modify {
                        id = "colorValue",
                        color = AseUtilities.hexToAseColor(query)
                    }
                end
            else
                dlg:modify { id = "dataType", option = "NUMBER" }

                dlg:modify { id = "colorValue", visible = false }
                dlg:modify { id = "intValue", visible = false }
                dlg:modify { id = "numValue", visible = true }

                dlg:modify {
                    id = "numValue",
                    text = string.format("%.6f", query)
                }
            end
        elseif typeQuery == "string" then
            dlg:modify { id = "dataType", option = "STRING" }

            dlg:modify { id = "boolValue", visible = false }
            dlg:modify { id = "colorValue", visible = false }
            dlg:modify { id = "intValue", visible = false }
            dlg:modify { id = "numValue", visible = false }
            dlg:modify { id = "stringValue", visible = true }

            dlg:modify { id = "stringValue", text = query }
        elseif typeQuery == "nil" then
            app.alert {
                title = "Error",
                text = string.format(
                    "The property \"%s\" in %s is nil.",
                    propName, target)
            }
            return
        else
            app.alert {
                title = "Error",
                text = "Unsupported data type."
            }
            return
        end
    end
}

dlg:button {
    id = "set",
    text = "&SET",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]
        local dataType <const> = args.dataType --[[@as string]]
        local propName <const> = args.propName --[[@as string]]

        if #propName <= 0 then
            app.alert {
                title = "Error",
                text = "The property name is empty."
            }
            return
        end

        local assignment = nil
        if dataType == "BOOLEAN" then
            assignment = args.boolValue --[[@as boolean]]
        elseif dataType == "COLOR" then
            local aseColor <const> = args.colorValue --[[@as Color]]
            assignment = AseUtilities.aseColorToHex(
                aseColor, ColorMode.RGB)
        elseif dataType == "INTEGER" then
            assignment = args.intValue --[[@as integer]]
        elseif dataType == "NUMBER" then
            assignment = args.numValue --[[@as number]]
        elseif dataType == "STRING" then
            assignment = args.stringValue --[[@as string]]
        else
            app.alert {
                title = "Error",
                text = "Unsupported data type."
            }
            return
        end

        local properties <const>,
        success <const>,
        errMsg <const> = getProperties(target)
        if (not properties) or (not success) then
            app.alert { title = "Error", text = errMsg }
            return
        end

        properties[propName] = assignment

        app.alert {
            title = "Success",
            text = string.format(
                "The property \"%s\" in %s has been set.",
                propName, target)
        }
    end
}

dlg:button {
    id = "unset",
    text = "&UNSET",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]
        local propName <const> = args.propName --[[@as string]]

        if #propName <= 0 then
            app.alert {
                title = "Error",
                text = "The property name is empty."
            }
            return
        end

        local properties <const>,
        success <const>,
        errMsg <const> = getProperties(target)
        if (not properties) or (not success) then
            app.alert { title = "Error", text = errMsg }
            return
        end

        properties[propName] = nil

        app.alert {
            title = "Success",
            text = string.format(
                "The property \"%s\" in %s has been unset.",
                propName, target)
        }
    end
}

dlg:button {
    id = "list",
    text = "&PRINT",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]

        local properties <const>,
        success <const>,
        errMsg <const> = getProperties(target)
        if (not properties) or (not success) then
            app.alert { title = "Error", text = errMsg }
            return
        end

        print(JsonUtilities.propsToJson(properties))
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = true,
    wait = false
}
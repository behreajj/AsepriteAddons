dofile("../../support/aseutilities.lua")
dofile("../../support/jsonutilities.lua")

local targets <const> = {
    "CEL",
    "FORE_TILE",
    "BACK_TILE",
    "LAYER",
    "RANGE",
    "SLICE",
    "SPRITE",
    "TAG",
    "TILE_SET",
    "TILES",
}

local dataTypes <const> = {
    "BOOLEAN",
    "COLOR",
    "INTEGER",
    "NIL",
    "NUMBER",
    "POINT",
    "STRING",
}

local defaults <const> = {
    target = "CEL",
    dataType = "STRING",
    propName = "property",
    boolValue = false,
    intValue = 0,
    numValue = 0.0,
    ptxValue = 0,
    ptyValue = 0,
    stringValue = "",
}

---@param x any
---@return integer
local function parseColorChannel(x)
    if type(x) == "number" then
        if math.type(x) == "integer" then
            return x
        end
        return math.floor(255.0 * x + 0.5)
    end
    return 0
end

---@param target string
---@return table<string, any>[]|nil properties
---@return boolean success
---@return string errMsg
---@nodiscard
local function getProperties(target)
    if target == "CEL" then
        local activeCel <const> = app.cel
        if not activeCel then
            return nil, false, "There is no active cel."
        end
        return { activeCel.properties }, true, ""
    elseif target == "RANGE" then
        local activeSprite <const> = app.sprite
        if not activeSprite then
            return nil, false, "There is no active sprite."
        end

        local range <const> = app.range
        if range.sprite ~= activeSprite then
            return nil, false, "Range doesn't belong to sprite."
        end

        local rangeType <const> = range.type
        if rangeType == RangeType.CELS then
            local rangeImages <const> = range.images
            local lenRangeImages <const> = #rangeImages
            if lenRangeImages <= 0 then
                return nil, false, "No cels were selected."
            end

            ---@type table<string, any>[]
            local properties <const> = {}
            local i = 0
            while i < lenRangeImages do
                i = i + 1
                properties[i] = rangeImages[i].cel.properties
            end
            return properties, true, ""
        elseif rangeType == RangeType.FRAMES then
            local rangeFrames <const> = range.frames
            local lenRangeFrames <const> = #rangeFrames
            if lenRangeFrames <= 0 then
                return nil, false, "No frames were selected."
            end

            local leaves <const> = AseUtilities.getLayerHierarchy(
                activeSprite, true, true, true, true)
            local cels <const> = AseUtilities.getUniqueCelsFromLeaves(
                leaves, rangeFrames)
            local lenCels <const> = #cels
            if lenCels <= 0 then
                return nil, false, "No cels were selected."
            end

            ---@type table<string, any>[]
            local properties <const> = {}
            local i = 0
            while i < lenCels do
                i = i + 1
                properties[i] = cels[i].properties
            end
            return properties, true, ""
        elseif rangeType == RangeType.LAYERS then
            local rangeLayers <const> = range.layers
            local lenRangeLayers <const> = #rangeLayers
            if lenRangeLayers <= 0 then
                return nil, false, "No layers were selected."
            end

            ---@type table<string, any>[]
            local properties <const> = {}
            local i = 0
            while i < lenRangeLayers do
                i = i + 1
                properties[i] = rangeLayers[i].properties
            end
            return properties, true, ""
        end

        return nil, false, "No cels or layers were selected."
    elseif target == "SLICE" then
        local activeSprite <const> = app.sprite
        if not activeSprite then
            return nil, false, "There is no active sprite."
        end

        local oldTool <const> = app.tool.id
        app.tool = "slice"

        local range <const> = app.range
        if range.sprite ~= activeSprite then
            app.tool = oldTool
            return nil, false, "Range doesn't belong to sprite."
        end

        local rangeSlices <const> = range.slices
        local lenRangeSlices <const> = #rangeSlices
        if lenRangeSlices <= 0 then
            app.tool = oldTool
            return nil, false, "No slices were selected."
        end

        local properties <const> = rangeSlices[1].properties
        app.tool = oldTool
        return { properties }, true, ""
    elseif target == "SPRITE" then
        local activeSprite <const> = app.sprite
        if not activeSprite then
            return nil, false, "There is no active sprite."
        end
        return { activeSprite.properties }, true, ""
    elseif target == "TAG" then
        local activeTag <const> = app.tag
        if not activeTag then
            return nil, false, "There is no active tag."
        end
        return { activeTag.properties }, true, ""
    elseif target == "LAYER"
        or target == "TILE_SET"
        or target == "TILES"
        or target == "FORE_TILE"
        or target == "BACK_TILE" then
        local activeLayer <const> = app.layer
        if not activeLayer then
            return nil, false, "There is no active layer."
        end

        if target == "LAYER" then
            return { activeLayer.properties }, true, ""
        end

        if not activeLayer.isTilemap then
            return nil, false, "Active layer is not a tile map."
        end

        local tileSet <const> = activeLayer.tileset
        if not tileSet then
            return nil, false, "Tile set could not be found."
        end

        if target == "TILE_SET" then
            return { tileSet.properties }, true, ""
        end

        -- TODO: Tiles as a getter now works.
        local lenTileSet <const> = #tileSet
        if target == "TILES" then
            ---@type table<string, any>[]
            local properties <const> = {}
            local lenProperties = 0
            local i = 1
            while i < lenTileSet do
                local tile <const> = tileSet:tile(i)
                if tile then
                    lenProperties = lenProperties + 1
                    properties[lenProperties] = tile.properties
                end
                i = i + 1
            end
            return properties, true, ""
        end

        local tifCurr <const> = target == "BACK_TILE"
            and app.bgTile
            or app.fgTile

        local tiCurr <const> = app.pixelColor.tileI(tifCurr)
        if tiCurr == 0 then
            -- Tiles at index 0 have the same properties as the
            -- tile sets that contain them.
            return nil, false, "Tile index 0 is reserved."
        end

        if tiCurr < 0 or tiCurr >= lenTileSet then
            return nil, false, string.format(
                "Tile index %d is out of bounds.",
                tiCurr)
        end

        local tile <const> = tileSet:tile(tiCurr)
        if not tile then
            return nil, false, "Tile could not be found."
        end

        return { tile.properties }, true, ""
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
        local isPt <const> = dataType == "POINT"
        local isStr <const> = dataType == "STRING"
        local notNil <const> = dataType ~= "NIL"

        dlg:modify { id = "boolValue", visible = isBool and notNil }
        dlg:modify { id = "colorValue", visible = isColor and notNil }
        dlg:modify { id = "intValue", visible = isInt and notNil }
        dlg:modify { id = "hexLabel", visible = isInt and notNil }
        dlg:modify { id = "numValue", visible = isNum and notNil }
        dlg:modify { id = "ptxValue", visible = isPt and notNil }
        dlg:modify { id = "ptyValue", visible = isPt and notNil }
        dlg:modify { id = "stringValue", visible = isStr and notNil }
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
    text = "&True",
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
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local intValue <const> = args.intValue --[[@as integer]]
        dlg:modify { id = "hexLabel", text = string.format("0x%X", intValue) }
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "hexLabel",
    label = "Hex:",
    text = string.format("0x%X", defaults.intValue),
    visible = defaults.dataType == "INTEGER"
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

dlg:number {
    id = "ptxValue",
    label = "Point:",
    text = string.format("%d", defaults.ptxValue),
    decimals = 0,
    visible = defaults.dataType == "POINT",
    focus = false
}

dlg:number {
    id = "ptyValue",
    text = string.format("%d", defaults.ptyValue),
    decimals = 0,
    visible = defaults.dataType == "POINT",
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

        dlg:modify { id = "boolValue", visible = false }
        dlg:modify { id = "colorValue", visible = false }
        dlg:modify { id = "intValue", visible = false }
        dlg:modify { id = "hexLabel", visible = false }
        dlg:modify { id = "numValue", visible = false }
        dlg:modify { id = "ptxValue", visible = false }
        dlg:modify { id = "ptyValue", visible = false }
        dlg:modify { id = "stringValue", visible = false }

        local query <const> = properties[1][propName]
        local typeQuery <const> = type(query)
        if typeQuery == "boolean" then
            dlg:modify { id = "dataType", option = "BOOLEAN" }
            dlg:modify { id = "boolValue", visible = true }
            dlg:modify { id = "boolValue", selected = query }
        elseif typeQuery == "nil" then
            dlg:modify { id = "dataType", option = "NIL" }
        elseif typeQuery == "number" then
            if math.type(query) == "integer" then
                dlg:modify { id = "dataType", option = "INTEGER" }
                dlg:modify { id = "intValue", visible = true }
                dlg:modify { id = "hexLabel", visible = true }
                dlg:modify {
                    id = "intValue",
                    text = string.format("%d", query)
                }
                dlg:modify {
                    id = "hexLabel",
                    text = string.format("0x%X", query)
                }
            else
                dlg:modify { id = "dataType", option = "NUMBER" }
                dlg:modify { id = "numValue", visible = true }
                dlg:modify {
                    id = "numValue",
                    text = string.format("%.6f", query)
                }
            end
        elseif typeQuery == "string" then
            dlg:modify { id = "dataType", option = "STRING" }
            dlg:modify { id = "stringValue", visible = true }
            dlg:modify { id = "stringValue", text = query }
        elseif typeQuery == "table" then
            if dataType == "COLOR" then
                local rQuery <const> = (query["r"] or query[1]) or 0
                local gQuery <const> = (query["g"] or query[2]) or 0
                local bQuery <const> = (query["b"] or query[3]) or 0
                local aQuery <const> = (query["a"] or query[4]) or 0

                local r8 <const> = parseColorChannel(rQuery)
                local g8 <const> = parseColorChannel(gQuery)
                local b8 <const> = parseColorChannel(bQuery)
                local a8 <const> = parseColorChannel(aQuery)

                dlg:modify { id = "colorValue", visible = true }
                dlg:modify {
                    id = "colorValue",
                    color = Color { r = r8, g = g8, b = b8, a = a8 }
                }
            elseif dataType == "POINT" then
                local xQuery <const> = (query["x"] or query[1]) or 0
                local yQuery <const> = (query["y"] or query[2]) or 0

                local x <const> = type(xQuery) == "number" and xQuery or 0
                local y <const> = type(yQuery) == "number" and yQuery or 0

                dlg:modify { id = "ptxValue", visible = true }
                dlg:modify { id = "ptyValue", visible = true }
                dlg:modify { id = "ptxValue", text = string.format("%d", x) }
                dlg:modify { id = "ptyValue", text = string.format("%d", y) }
            else
                dlg:modify { id = "dataType", option = "STRING" }
                dlg:modify { id = "stringValue", visible = true }
                dlg:modify {
                    id = "stringValue",
                    text = JsonUtilities.propsToJson(query)
                }
            end
        else
            dlg:modify { id = "dataType", option = "NIL" }
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

        local propNameVerif <const> = Utilities.validateFilename(propName)
        local propNameWarn <const> = propNameVerif ~= propName
        local confirm = 1
        if propNameWarn then
            confirm = app.alert {
                title = "Warning",
                text = {
                    string.format(
                        "The property name \"%s\" will be changed to \"%s\".",
                        propName, propNameVerif),
                    "Do you wish to proceed?"
                },
                buttons = { "&YES", "&NO" }
            }
        end

        if (not confirm) or confirm == 2 then
            return
        end

        local assignment = nil
        if dataType == "BOOLEAN" then
            assignment = args.boolValue --[[@as boolean]]
        elseif dataType == "COLOR" then
            local aseColor <const> = args.colorValue --[[@as Color]]
            assignment = {
                r = aseColor.red,
                g = aseColor.green,
                b = aseColor.blue,
                a = aseColor.alpha
            }
        elseif dataType == "INTEGER" then
            assignment = args.intValue --[[@as integer]]
        elseif dataType == "NUMBER" then
            assignment = args.numValue --[[@as number]]
        elseif dataType == "NIL" then
            assignment = nil
        elseif dataType == "POINT" then
            assignment = {
                x = args.ptxValue --[[@as integer]],
                y = args.ptyValue --[[@as integer]]
            }
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

        local lenProperties <const> = #properties
        local i = 0
        while i < lenProperties do
            i = i + 1
            properties[i][propNameVerif] = assignment
        end

        app.alert {
            title = "Success",
            text = string.format(
                "The property \"%s\" in %s has been set.",
                propNameVerif, target)
        }
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "openConsole",
    text = "CO&NSOLE",
    focus = false,
    onclick = function()
        local activeSprite <const> = app.sprite
        AseUtilities.preserveForeBack()
        app.command.DeveloperConsole()
        if activeSprite then app.sprite = activeSprite end
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

        ---@type string[]
        local strArr <const> = {}
        local lenProperties <const> = #properties
        local i = 0
        while i < lenProperties do
            i = i + 1
            strArr[i] = JsonUtilities.propsToJson(properties[i])
        end
        strArr[1 + i] = ""
        print(table.concat(strArr, "\n"))
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
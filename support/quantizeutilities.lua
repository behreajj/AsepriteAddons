QuantizeUtilities = {}
QuantizeUtilities.__index = QuantizeUtilities

---Default bits for alphachannel.
QuantizeUtilities.BITS_DEFAULT_A = 8

---Default bits for RGB channels.
QuantizeUtilities.BITS_DEFAULT_RGB = 4

---Maximum bits per color channel.
QuantizeUtilities.BITS_MAX = 8

---Minimum bits per color channel.
QuantizeUtilities.BITS_MIN = 1

---Default display uniformity.
QuantizeUtilities.INPUT_DEFAULT = "UNIFORM"

---Channel display uniformity presets.
QuantizeUtilities.INPUTS = { "NON_UNIFORM", "UNIFORM" }

---Default levels for alpha channel.
QuantizeUtilities.LEVELS_DEFAULT_A = 256

---Default levels for RGB channels.
QuantizeUtilities.LEVELS_DEFAULT_RGB = 16

---Maximum levels per color channel.
QuantizeUtilities.LEVELS_MAX = 256

---Minimum levels per color channel.
QuantizeUtilities.LEVELS_MIN = 2

---Default quantization method.
QuantizeUtilities.METHOD_DEFAULT = "UNSIGNED"

---Quantization method presets.
QuantizeUtilities.METHODS = { "SIGNED", "UNSIGNED" }

---Default channel unit of measure.
QuantizeUtilities.UNIT_DEFAULT = "BITS"

---Channel unit of measure presets.
QuantizeUtilities.UNITS = { "BITS", "INTEGERS" }

setmetatable(QuantizeUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Generates the dialog widgets shared across color quantization dialogs.
---Places a new row at the end of the widgets.
---@param dlg Dialog dialog
---@param isVisible boolean visible by default
---@param enableAlpha boolean enable alpha channel
function QuantizeUtilities.dialogWidgets(dlg, isVisible, enableAlpha)
    dlg:combobox {
        id = "method",
        label = "Method:",
        option = QuantizeUtilities.METHOD_DEFAULT,
        options = QuantizeUtilities.METHODS,
        focus = false,
        visible = isVisible,
    }

    dlg:newrow { always = false }

    dlg:combobox {
        id = "levelsInput",
        label = "Channels:",
        option = QuantizeUtilities.INPUT_DEFAULT,
        options = QuantizeUtilities.INPUTS,
        focus = false,
        visible = isVisible,
        onchange = function()
            local args <const> = dlg.data

            local md <const> = args.levelsInput --[[@as string]]
            local isu <const> = md == "UNIFORM"
            local isnu <const> = md == "NON_UNIFORM"

            local unit <const> = args.unitsInput --[[@as string]]
            local isbit <const> = unit == "BITS"
            local isint <const> = unit == "INTEGERS"

            dlg:modify { id = "rBits", visible = isnu and isbit }
            dlg:modify { id = "gBits", visible = isnu and isbit }
            dlg:modify { id = "bBits", visible = isnu and isbit }
            dlg:modify { id = "aBits", visible = isnu and isbit }
            dlg:modify {
                id = "bitsUni",
                visible = isu and isbit
            }

            dlg:modify { id = "rLevels", visible = isnu and isint }
            dlg:modify { id = "gLevels", visible = isnu and isint }
            dlg:modify { id = "bLevels", visible = isnu and isint }
            dlg:modify { id = "aLevels", visible = isnu and isint }
            dlg:modify {
                id = "levelsUni",
                visible = isu and isint
            }
        end
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "levelsUni",
        label = "Levels:",
        min = QuantizeUtilities.LEVELS_MIN,
        max = QuantizeUtilities.LEVELS_MAX,
        value = QuantizeUtilities.LEVELS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "INTEGERS",
        onchange = function()
            local args <const> = dlg.data
            local uni <const> = args.levelsUni --[[@as integer]]
            dlg:modify { id = "rLevels", value = uni }
            dlg:modify { id = "gLevels", value = uni }
            dlg:modify { id = "bLevels", value = uni }
            if enableAlpha then
                dlg:modify { id = "aLevels", value = uni }
            end
        end
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "rLevels",
        label = "Red:",
        min = QuantizeUtilities.LEVELS_MIN,
        max = QuantizeUtilities.LEVELS_MAX,
        value = QuantizeUtilities.LEVELS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "INTEGERS"
    }

    dlg:slider {
        id = "gLevels",
        label = "Green:",
        min = QuantizeUtilities.LEVELS_MIN,
        max = QuantizeUtilities.LEVELS_MAX,
        value = QuantizeUtilities.LEVELS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "INTEGERS"
    }

    dlg:slider {
        id = "bLevels",
        label = "Blue:",
        min = QuantizeUtilities.LEVELS_MIN,
        max = QuantizeUtilities.LEVELS_MAX,
        value = QuantizeUtilities.LEVELS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "INTEGERS"
    }

    dlg:slider {
        id = "aLevels",
        label = "Alpha:",
        min = QuantizeUtilities.LEVELS_MIN,
        max = QuantizeUtilities.LEVELS_MAX,
        value = QuantizeUtilities.LEVELS_DEFAULT_A,
        focus = false,
        enabled = enableAlpha,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "INTEGERS"
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "bitsUni",
        label = "Bits:",
        min = QuantizeUtilities.BITS_MIN,
        max = QuantizeUtilities.BITS_MAX,
        value = QuantizeUtilities.BITS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "BITS",
        onchange = function()
            local args <const> = dlg.data
            local bd <const> = args.bitsUni --[[@as integer]]
            dlg:modify { id = "rBits", value = bd }
            dlg:modify { id = "gBits", value = bd }
            dlg:modify { id = "bBits", value = bd }
            if enableAlpha then
                dlg:modify { id = "aBits", value = bd }
            end

            local lv <const> = 1 << bd
            dlg:modify { id = "levelsUni", value = lv }
            dlg:modify { id = "rLevels", value = lv }
            dlg:modify { id = "gLevels", value = lv }
            dlg:modify { id = "bLevels", value = lv }
            if enableAlpha then
                dlg:modify { id = "aLevels", value = lv }
            end
        end
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "rBits",
        label = "Red:",
        min = QuantizeUtilities.BITS_MIN,
        max = QuantizeUtilities.BITS_MAX,
        value = QuantizeUtilities.BITS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "BITS",
        onchange = function()
            local args <const> = dlg.data
            local rBits <const> = args.rBits --[[@as integer]]
            local lv <const> = 1 << rBits
            dlg:modify { id = "rLevels", value = lv }
        end
    }

    dlg:slider {
        id = "gBits",
        label = "Green:",
        min = QuantizeUtilities.BITS_MIN,
        max = QuantizeUtilities.BITS_MAX,
        value = QuantizeUtilities.BITS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "BITS",
        onchange = function()
            local args <const> = dlg.data
            local gBits <const> = args.gBits --[[@as integer]]
            local lv <const> = 1 << gBits
            dlg:modify { id = "gLevels", value = lv }
        end
    }

    dlg:slider {
        id = "bBits",
        label = "Blue:",
        min = QuantizeUtilities.BITS_MIN,
        max = QuantizeUtilities.BITS_MAX,
        value = QuantizeUtilities.BITS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "BITS",
        onchange = function()
            local args <const> = dlg.data
            local bBits <const> = args.bBits --[[@as integer]]
            local lv <const> = 1 << bBits
            dlg:modify { id = "bLevels", value = lv }
        end
    }

    dlg:slider {
        id = "aBits",
        label = "Alpha:",
        min = QuantizeUtilities.BITS_MIN,
        max = QuantizeUtilities.BITS_MAX,
        value = QuantizeUtilities.BITS_DEFAULT_A,
        focus = false,
        enabled = enableAlpha,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "BITS",
        onchange = function()
            if enableAlpha then
                local args <const> = dlg.data
                local aBits <const> = args.aBits --[[@as integer]]
                local lv <const> = 1 << aBits
                dlg:modify { id = "aLevels", value = lv }
            end
        end
    }

    dlg:newrow { always = false }

    dlg:combobox {
        id = "unitsInput",
        label = "Units:",
        option = QuantizeUtilities.UNIT_DEFAULT,
        options = QuantizeUtilities.UNITS,
        focus = false,
        visible = isVisible,
        onchange = function()
            local args <const> = dlg.data

            local md <const> = args.levelsInput --[[@as string]]
            local isnu <const> = md == "NON_UNIFORM"
            local isu <const> = md == "UNIFORM"

            local unit <const> = args.unitsInput --[[@as string]]
            local isbit <const> = unit == "BITS"
            local isint <const> = unit == "INTEGERS"

            dlg:modify { id = "rBits", visible = isnu and isbit }
            dlg:modify { id = "gBits", visible = isnu and isbit }
            dlg:modify { id = "bBits", visible = isnu and isbit }
            dlg:modify { id = "aBits", visible = isnu and isbit }
            dlg:modify {
                id = "bitsUni",
                visible = isu and isbit
            }

            dlg:modify { id = "rLevels", visible = isnu and isint }
            dlg:modify { id = "gLevels", visible = isnu and isint }
            dlg:modify { id = "bLevels", visible = isnu and isint }
            dlg:modify { id = "aLevels", visible = isnu and isint }
            dlg:modify {
                id = "levelsUni",
                visible = isu and isint
            }
        end
    }

    dlg:newrow { always = false }
end

return QuantizeUtilities
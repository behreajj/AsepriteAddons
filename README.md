# Aseprite Add-ons

## References

To learn more about scripting add-ons for Aseprite, see:

1. [Scripting API](https://github.com/aseprite/api)
2. [Running Aseprite in Debug Mode](https://www.aseprite.org/docs/debug/)
3. [Aseprite Command Line Interface](https://www.aseprite.org/docs/cli/)
4. [Community Script Examples](https://community.aseprite.org/t/aseprite-script-examples/2611)

For Lua scripting in general, see:

 1. [Lua](http://www.lua.org/)

## Notes

### Lua

Two hyphens, `--`, designate a single line comment. There are no shortcuts for decrementing or incrementing numbers by one (`++i`, `--i`).

Lua is dynamically typed, like Python and JavaScript. The `type` method can be used to find a variable's type as a `string`.

`nil`  (not `null`) is the unique, absent value.

`boolean`s (not `bool`s) are `false` or `true` (lower case).

Inequality is signified with `~=` (not `!=`).

`tables`, not arrays, are the fundamental collection in Lua. `tables` have borders and so care must be taken when using the length operator, `#`. See the reference [section 3.4.7](https://www.lua.org/manual/5.4/manual.html#3).

Multi-line `string`s are demarcated with double square brackets, for example, `[[The quick brown fox]]`. Strings are concatenated with `..`, for example, `"a" .. "b"` yields `"ab"`.

Array subscript accesses start at an index of `1`. When using them to represent closed loops, either cache a `prev` variable outside the loop or use `%` like so:

```lua
local arr = { 1, 2, 3, 4, 5 }
local lenArr = #arr
for i = 0, lenArr - 1, 1 do
    local prev = arr[1 + (i - 1) % lenArr]
    local curr = arr[1 + i]
    local next = arr[1 + (i + 1) % lenArr]
    print(i.." "..prev.." "..curr.." "..next)
end
```

`for` loops follow a tripartite structure similar to programming languages like C#, Java and JavaScript. The comparison in the second portion and increment in the third are implied. In Lua, the comparison is upper bound _inclusive_, not exclusive. A loop is initiated by `do` and concluded with `end`.

Conditional blocks are structured as in the following example,

```lua
if a > b then
    -- do work
elseif a < b then
    -- do work
else
    -- do work
end
```

`elseif` (not `elif`) is one word. Conditions are followed by `then`. The entire block concludes with `end`.

For [object oriented](http://lua-users.org/wiki/ObjectOrientationTutorial) programming, I follow the template below.

```lua
Vec2 = {}
Vec2.__index = Vec2

-- Allow Vec2(3, 4) syntax without new.
setmetatable(Vec2, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

function Vec2.new(x, y)
    local inst = {}
    setmetatable(inst, Vec2)
    inst.x = x or 0.0
    inst.y = y or inst.x
    return inst
end

-- Define metamethods (:__)
-- Define instance methods (:)
-- Define static methods (.)

return Vec2
```

Methods called with `:` implicitly pass `self` as the first parameter. Methods called with `.` do not. I use colons to distinguish instance methods from static methods. If you see a `nil` error at a method call, check for this error. See discussion [here](https://stackoverflow.com/questions/3779671/why-cant-i-use-setunion-instead-of-set-union).

Metamethods allow for operator overloading. Bitwise operators are

| Operator | Metamethod | Note                                                           |
| :------: | :--------- | :------------------------------------------------------------- |
|   `&`    | `__band`   | [AND gate](https://www.wikiwand.com/en/AND_gate).              |
|   `~`    | `__bnot`   | [NOT gate](https://www.wikiwand.com/en/Inverter_(logic_gate)). |
|   `\|`   | `__bor`    | [OR gate](https://www.wikiwand.com/en/OR_gate).                |
|   `~`    | `__bxor`   | [XOR gate](https://www.wikiwand.com/en/XOR_gate).              |
|   `<<`   | `__shl`    | Left bit shift.                                                |
|   `>>`   | `__shr`    | Right bit shift.                                               |

Comparison operators are

| Operator | Metamethod |
| :------: | :--------- |
|   `==`   | `__eq`     |
|   `<=`   | `__le`     |
|   `<`    | `__lt`     |

 The operators `>` and `>=` are inferred from `<` (`__lt`) and `<=` (`__le`).
 
 Arithmetic operators are

| Operator | Metamethod | Note                                                          |
| :------: | :--------- | :------------------------------------------------------------ |
|   `+`    | `__add`    |                                                               |
|   `/`    | `__div`    |                                                               |
|   `//`   | `__idiv`   | Floor division.                                               |
|   `%`    | `__mod`    | [Floor modulo](https://www.wikiwand.com/en/Modulo_operation). |
|   `*`    | `__mul`    |                                                               |
|   `^`    | `__pow`    | Exponentiation.                                               |
|   `-`    | `__sub`    |                                                               |
|   `-`    | `__unm`    | Unary negation.                                               |

Other operators are

| Operator | Metamethod   |
| :------: | :----------- |
|   `..`   | `__concat`   |
|   `#`    | `__len`      |
|          | `__tostring` |

Metamethods are preceded by two underscores.

### Aseprite

`require("myclass")` is [not supported](https://community.aseprite.org/t/can-you-import-lua-libraries-from-a-script-solved/3528) in Aseprite; instead use `dofile("./myclass.lua")`.

As in Processing, working with colors in bulk involves packing and unpacking integers. Color integer channels are ordered ABGR. Given four numbers in the range [0, 255], the packed integer would arise from `ca << 0x18 | cb << 0x10 | cg << 0x8 | cr`. To unpack, use `ca = (c >> 0x18) & 0xff` and so on. To print an integer as hex, use `string.format("%x", 0xaabbccdd)`.

For certain API classes, more information can be gleened directly from the source code than from the docs:
 - [Color](https://github.com/aseprite/aseprite/blob/6c4621a26a2acf70e184aa247a5cd40be2e652ef/src/app/script/color_class.cpp)
 - [Point](https://github.com/aseprite/aseprite/blob/6c4621a26a2acf70e184aa247a5cd40be2e652ef/src/app/script/point_class.cpp)

HSV color is in the range [0.0, 360.0] for hue, [0.0, 1.0] for saturation, [0.0, 1.0] for value. RGBA color is in [0, 255].
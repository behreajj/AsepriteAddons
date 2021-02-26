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

Two hyphens, `--`, designate a single line comment.

`nil`  (not `null`) is the unique, absent value.

`boolean`s (not `bool`s) are `false` or `true` (lower case).

Inequality is signified with `~=` (not `!=`).

The `^` operator is for exponentiation, e.g., `3 ^ 4` yields `81`.

The `//` is for floor division, e.g., `5 // 2` yields `2`.

The `#` operator finds the length of a `table`.

`tables`, not arrays, are the fundamental collection in Lua. `tables` have borders and so care must be taken when using the length operator. See the reference [section 3.4.7](https://www.lua.org/manual/5.4/manual.html#3).

The `%` operator designates [floor modulo](https://www.wikiwand.com/en/Modulo_operation). This is similar to Python; it is different from C#, Java and JavaScript.

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

`for` loops follow the same tripartite structure as programming languages like C#, Java and JavaScript. The comparison in the second portion and increment in the third are implied. However, the comparison is upper bound _inclusive_, not exclusive. A loop is initiated by `do` and concluded with `end`.

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

For custom classes, method syntax uses the colon `:` while field syntax uses the period `.`. If you're encountering a `nil` error at a method call, double-check check for this error.

### Aseprite

`require("myclass")` is [not supported](https://community.aseprite.org/t/can-you-import-lua-libraries-from-a-script-solved/3528) in Aseprite; instead use `dofile("./myclass.lua")`.

As in Processing, working with colors in bulk involves packing and unpacking integers. To print an integer as hex, use `string.format("%x", 0xaabbccdd)`.

Color integer channels are ordered ABGR. Given four numbers in the range [0, 255], the packed integer would arise from `ca << 0x18 | cb << 0x10 | cg << 0x8 | cr`. To unpack, use `ca = (c >> 0x18) & 0xff` and so on.

For certain API classes, more information can be gleened from the source code:
 - [Color](https://github.com/aseprite/aseprite/blob/6c4621a26a2acf70e184aa247a5cd40be2e652ef/src/app/script/color_class.cpp)
 - [Point](https://github.com/aseprite/aseprite/blob/6c4621a26a2acf70e184aa247a5cd40be2e652ef/src/app/script/point_class.cpp)

HSV color is in the range [0.0, 360.0] for hue, [0.0, 1.0] for saturation, [0.0, 1.0] for value.
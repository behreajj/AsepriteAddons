Unlike `dialog` scripts, it's not always apparent what `commands` scripts do. Nor can their purpose easily be explained with a still image. For that reason, this document attempts a brief explanation of each, including differences with standard Aseprite behavior.

- `appendFrame`: Adds a new empty frame after the active frame. The active frame *remains* active.

- `bakeChecker`: Creates a layer that replicates the size and color of a sprite's background checker. Ignores the checker zoom preference.

- `brushFromMask`: Creates a brush from a selection. If snap to grid is enabled, sets the brush center to top-left; otherwise, uses the selection pivot. If a tile map is active, sets the brush alignment.

- `collapseGroups`: Collapses all group layers in the timeline. If the active layer is a child, sets its top-level ancestor to the active layer.

- `correctPalette`: Prepends `0x00000000`, clear black, to a palette at index 0 if it doesn't already exist. Removes duplicate palette entries. Converts a sprite to and from RGB color mode and sets its `transparentColor` to `0`. This is to avoid a number of issues in indexed color mode, e.g., with the outline tool or with exporting.

- `correctTags`: Removes tags with out-of-bounds frames. Tags with duplicate names have a number appended to the end of the name.

- `correctTilesets`: Checks tile set names for empty strings, invalid characters in file paths, and duplicates. Renames tile sets as needed. Assigns a unique ID to each set's `properties`.

- `cycleCelLeft`: Moves a cel to the previous frame. If the previous frame is occupied by another cel, swaps the other cel into the active cel's frame. Loops around at the first and last frame. Ignores reference layers.

- `cycleCelRight`: Moves a cel to the next frame. If the next frame is occupied by another cel, swaps the other cel into the active cel's frame. Loops around at the first and last frame. Ignores reference layers.

- `cycleStackDown`: Moves a layer down the stack. Ignores background layers. If the layer is at the bottom of the stack and its parent does not contain a background layer, moves it to the top.

- `cycleStackUp`: Moves a layer up the stack. Ignores background layers. If the layer is at the top of the stack and its parent does not contain a background layer, moves it to the bottom.

- `cycleSwatchLeft`: If the foreground color has an exact palette match, moves the palette swatch to the left. Does not trigger a palette remap.
 
- `cycleSwatchRight`: If the foreground color has an exact palette match, moves the palette swatch to the right. Does not trigger a palette remap.

- `expandGroups`: Opens all group layers in the timeline.

- `dereference`: Converts a reference layer to a normal layer. Transfers the reference layer's parent to the new layer.

- `findLikeImages`: Assigns a signed 64 bit integer hash of an image to the key "hash" in non empty cels' [property](https://github.com/aseprite/api/blob/main/api/properties.md). Cels that contain duplicate images according to the hash are highlighted in red.

- `flattenGroup`: Flattens a group layer. Includes locked layers, but excludes hidden layers.

- `groupLayers`: Places layers in the active range into a new group layer. If all child layers have the same parent, the group is placed under the parent. Does not group background layers.

- `growRangeFrames`: Expands the existing range to include more frames. If there is no frame range, then creates one for either the active tag or the active frame.

- `growRangeLayers`: Expands the existing range to include more layers. If the layer is a group, selects its children. Then, selects the layer's neighbors. Then selects its parents. Treats reference layers as a boundary.

- `nextFrame`: Moves the active frame to the next frame index. Preserves timeline ranges of `RangeType.LAYERS`. If play once is false, then returns to the first frame after reaching the last.

- `nextLayer`: Moves the active layer to the next layer up the stack. Preserves timeline ranges of `RangeType.FRAMES`. Stops when the top of the sprite layer stack is reached.

- `nextSwatchBack`: Moves the active background color to the next palette index. If the tile map mode is `TilemapMode.TILES`, then moves the active tile.

- `nextSwatchFore`: Moves the active foreground color to the next palette index. If the tile map mode is `TilemapMode.TILES`, then moves the active tile.

- `nextTab`: Moves the active sprite to the next tab. Converts the fore- and background colors to RGB. If the slice tool is active, switches to the hand tool.

- `prevFrame`: Moves the active frame to the previous frame index. Preserves timeline ranges of `RangeType.LAYERS`. If play once is false, then returns to the last frame after reaching the first.

- `prevLayer`: Moves the active layer to the previous layer down the stack. Preserves timeline ranges of `RangeType.FRAMES`. Stops when the bottom of the sprite layer stack is reached.

- `prevSwatchBack`: Moves the active background color to the previous palette index. If the tile map mode is `TilemapMode.TILES`, then moves the active tile.

- `prevSwatchFore`: Moves the active foreground color to the previous palette index. If the tile map mode is `TilemapMode.TILES`, then moves the active tile.

- `prevTab`: Moves the active sprite to the previous tab. Converts the fore- and background colors to RGB. If the slice tool is active, switches to the hand tool.

- `shareChecker`: Shares the background checker preferences for the active sprite across other open sprites. Ignores zoom preference.

- `selectCelsRange`: Creates a selection based on the timeline range, or the active cel if the range is empty. Finds the union of images in the range. Ignores reference layers. Selects tile map layers based on non-empty tiles. Equivalent to holding down `Ctrl` and clicking on an inactive layer in the timeline.

- `selectLayer`: Makes the topmost non-transparent layer beneath the mouse cursor active.

- `toggleGroups`: Toggles the collapsed or expanded state of group folders in the timeline. The active layer's hierarchy remains expanded.

- `toggleVisible`: Toggles the visibility of layers in a timeline range. If the range is empty or is `RangeType.FRAMES`, then refers to the active layer.

- `ungroupLayers`: Sets the parent of layers in the active layer to their grandparent, if any.
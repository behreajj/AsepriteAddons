Unlike `dialog` scripts, it's not always apparent what `commands` scripts do. Nor can their purpose easily be explained with a still image. For that reason, this document attempts a brief explanation of each, including differences with standard Aseprite behavior.

## Cels

- `cycleCelLeft`: Moves a cel to the previous frame. If the previous frame is occupied by another cel, swaps the other cel into the active cel's frame. Loops around at the first and last frame. Ignores reference layers.

- `cycleCelRight`: Moves a cel to the next frame. If the next frame is occupied by another cel, swaps the other cel into the active cel's frame. Loops around at the first and last frame. Ignores reference layers.

- `fillEmptyCels`: Duplicates the active cel to empty frames before and after it on the active layer. If there is no cel and the layer is a regular layer, creates a cel with an empty image.

- `findLikeImages`: Assigns a signed 64 bit integer hash of an image to the key "hash" in non empty cels' [properties](https://github.com/aseprite/api/blob/main/api/properties.md). Cels that contain duplicate images according to the hash are highlighted in red.

- `selectCelsRange`: Creates a selection based on the timeline range, or the active cel if the range is empty. Finds the union of images in the range. Ignores reference layers. Selects tile map layers based on non-empty tiles. Equivalent to holding down `Ctrl` and clicking on an inactive layer in the timeline.

## Frames

- `appendFrame`: Adds a new empty frame after the active frame. The active frame *remains* active.

- `deleteFrame`: Deletes frames in the timeline range. Sets active frame to earliest prior to deleted range.

- `growRangeFrames`: Expands the existing range to include more frames. If there is no frame range, then creates one for either the active tag or the active frame.

- `nextFrame`: Moves the active frame to the next frame index. Preserves timeline ranges of `RangeType.LAYERS`. If play once is 
false, then returns to the first frame after reaching the last.

- `prependFrame`: Adds a new empty frame before the active frame. The active frame *remains* active.

- `prevFrame`: Moves the active frame to the previous frame index. Preserves timeline ranges of `RangeType.LAYERS`. If play once is false, then returns to the last frame after reaching the first.

## Layers

- `appendLayer`: Appends a new layer to the active parent, either sprite or group layer. The layer is appended to the top of the layer stack. If the active layer is a group, does *not* child the new layer to the group. The new layer becomes the active layer. 

- `copyLayer`: Duplicates a layer, including group opacity and blend mode. Ignores reference layers. Ignores background layers in indexed color mode. Ignores empty group layers. Tile map layers are copied to regular layers (to avoid ambiguities with tile set reference vs. copy by value). For ranges, group layers are ignored and duplicates are parented to the sprite.

- `cycleStackDown`: Moves a layer down the stack. Ignores background layers. If the layer is at the bottom of the stack and its parent does not contain a background layer, moves it to the top.

- `cycleStackUp`: Moves a layer up the stack. Ignores background layers. If the layer is at the top of the stack and its parent does not contain a background layer, moves it to the bottom.

- `deleteLayer`: Deletes layers in the timeline range. Children of group layers will be unparented. Creates a new layer if all existing layers are deleted. Does not delete tile set if layer is a tile map layer and is the only one using the tile set.

- `dereference`: Converts a reference layer to a normal layer. Transfers the reference layer's parent to the new layer.

- `flattenGroup`: Flattens a group layer. Includes locked layers, but excludes hidden layers.

- `groupLayers`: Places layers in the active range into a new group layer. If all child layers have the same parent, the group is placed under the parent. Does not group background layers.

- `growRangeLayers`: Expands the existing range to include more layers. If the layer is a group, selects its children. Then, selects the layer's neighbors. Then selects its parents. Treats reference layers as a boundary.

- `nextLayer`: Moves the active layer to the next layer up the stack. Preserves timeline ranges of `RangeType.FRAMES`. Stops when the top of the sprite layer stack is reached.

- `prependLayer`: Prepends a new layer to the active parent, either sprite or group layer. The layer is prepended to the bottom of the layer stack. If the active layer is a group, does *not* child the new layer to the group. The new layer becomes the active layer.

- `prevLayer`: Moves the active layer to the previous layer down the stack. Preserves timeline ranges of `RangeType.FRAMES`. Stops when the bottom of the sprite layer stack is reached.

- `selectLayer`: Makes the topmost non-transparent layer beneath the mouse cursor active.

- `toggleGroups`: Toggles the collapsed or expanded state of group folders in the timeline. The active layer's hierarchy remains expanded.

- `toggleVisible`: Toggles the visibility of layers in a timeline range. If the range is empty or is `RangeType.FRAMES`, then refers to the active layer.

- `toreference`: Converts a layer to a reference layer. Group layers are not supported, and should be flattened prior.

- `ungroupLayers`: Sets the parent of layers in the active layer to their grandparent, if any.

## Palette

- `cycleSwatchLeft`: If the foreground color has an exact palette match, moves the palette swatch to the left. Does not trigger a palette remap.

- `cycleSwatchRight`: If the foreground color has an exact palette match, moves the palette swatch to the right. Does not trigger a palette remap.

- `nextSwatchBack`: Moves the active background color to the next palette index. If the tile map mode is `TilemapMode.TILES`, then moves the active tile.

- `nextSwatchFore`: Moves the active foreground color to the next palette index. If the tile map mode is `TilemapMode.TILES`, then moves the active tile.

- `prevSwatchBack`: Moves the active background color to the previous palette index. If the tile map mode is `TilemapMode.TILES`, then moves the active tile.

- `prevSwatchFore`: Moves the active foreground color to the previous palette index. If the tile map mode is `TilemapMode.TILES`, then moves the active tile.

## Sprites

- `bakeChecker`: Creates a layer that replicates the size and color of a sprite's background checker. Ignores the checker zoom preference.

- `correctAlpha`: If a sprite contains palette swatches or images with zero alpha, sets the remainder of their color channels to zero, so that the colors are recognized as 'mask' colors.

- `correctPalette`: Prepends `0x00000000`, clear black, to a palette at index 0 if it doesn't already exist. Removes duplicate palette entries. Converts a sprite to and from RGB color mode and sets its `transparentColor` to `0`. This is to avoid a number of issues in indexed color mode, e.g., with the outline tool or with exporting.

- `correctTags`: Removes tags with out-of-bounds frames. Tags with duplicate names have a number appended to the end of the name.

- `correctTilesets`: Checks tile set names for empty strings, invalid characters, and duplicates. Renames tile sets as needed. Assigns a unique ID to each set's `properties`.

- `flattenSprite`: Flattens a sprite's layers to one layer. Deletes all layers other than the flattened layer, including references.

- `nextTab`: Moves the active sprite to the next tab. Converts the fore- and background colors to RGB. If the slice tool is active, switches to the hand tool.

- `prevTab`: Moves the active sprite to the previous tab. Converts the fore- and background colors to RGB. If the slice tool is active, switches to the hand tool.

- `shareChecker`: Shares the background checker preferences for the active sprite across other open sprites. Ignores zoom preference.

## Miscellaneous

- `brushFromMask`: Creates a brush from a selection. If snap to grid is enabled, sets the brush center to top-left; otherwise, uses the selection pivot. With no selection, creates a custom square or line brush.

- `brushFromTile`: Creates a brush from the active foreground tile.

- `copyTileset`: If the active layer is a tile map, duplicates the tile set referred to by the layer. Assigns an ID to the duplicate's `properties` and names the duplicate based on that ID. Prompts the user as to whether the layer should update its reference to the duplicate tile set.
Unlike `dialog` scripts, it's not always apparent what `commands` scripts do. Nor can their purpose easily be explained with a still image. For that reason, this document attempts a brief explanation of each, including differences with standard Aseprite behavior.

- `appendFrame`: Adds a new empty frame after the active frame. The active frame *remains* active.

- `bakeChecker`: Creates a layer that replicates the size and color of Aseprite's background checker. In most cases, this will be the background layer. Ignores the checker zoom preference.

- `correctPalette`: Prepends `0x00000000`, which is clear black, to a palette at index 0 if it doesn't already exist. Removes duplicate palette entries. Converts a sprite to and from RGB color mode and sets its `transparentColor` to `0`. This is to avoid a number of issues in indexed color mode, e.g., with the outline tool or with exporting.

- `cycleCelLeft`: Moves a cel to the previous frame. If the previous frame is occupied by another cel, swaps the other cel into the active cel's frame. Loops around at the first and last frame. Ignores background and reference layers.

- `cycleCelRight`: Moves a cel to the next frame. If the next frame is occupied by another cel, swaps the other cel into the active cel's frame. Loops around at the first and last frame. Ignores background and reference layers.

- `cycleStackDown`: Moves a layer down the stack. Ignores background layers. If the layer is at the bottom of the stack and its parent does not contain a background layer, moves it to the top.

- `cycleStackUp`: Moves a layer up the stack. Ignores background layers. If the layer is at the top of the stack and its parent does not contain a background layer, moves it to the top.

- `dereference`: Converts a reference layer to a normal layer. Transfers the reference layer's parent to the new layer but the new layer remains at the top of the stack.

- `nextFrame`: Moves the active frame to the next frame index. Preserves timeline ranges of `RangeType.LAYERS`. If play once is false, then returns to the first frame after reaching the last.

- `nextLayer`: Moves the active layer to the next layer up the stack. Preserves timeline ranges of `RangeType.FRAMES`. Stops when the top of the sprite layer stack is reached. 

- `nextTab`: Moves the active sprite to the next tab. Converts the fore- and background colors to RGB.

- `prevFrame`: Moves the active frame to the previous frame index. Preserves timeline ranges of `RangeType.LAYERS`. If play once is false, then returns to the last frame after reaching the first.

- `prevLayer`: Moves the active layer to the previous layer down the stack. Preserves timeline ranges of `RangeType.FRAMES`. Stops when the bottom of the sprite layer stack is reached.

- `prevTab`: Moves the active sprite to the previous tab. Converts the fore- and background colors to RGB.

- `selectCelsRange`: Creates a selection based on the timeline range, or the active cel if the range is empty. Finds the union of images in the range. Equivalent to holding down `Ctrl` and clicking on a non-active layer in the timeline.
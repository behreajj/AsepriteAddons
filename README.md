# Aseprite Add-ons

An appendix to the Medium article, ["How To Script Aseprite Tools in Lua"](https://behreajj.medium.com/how-to-script-aseprite-tools-in-lua-8f849b08733).

To install, click on the green `Code` button above. For those unfamiliar with Git, select `Download ZIP`, then unzip the file after it has finished downloading. In Aseprite, go to `File > Scripts > Open Scripts Folder`. Copy `dialog` and `support` folders from the unzipped download into the folder that Aseprite has opened. Return to Aseprite, go to `File > Scripts > Rescan Scripts Folder`.

To use, go to `File > Scripts` and choose from entries in the `dialogs` folder.

## References

For more information, see

- [Aseprite Scripting API](https://github.com/aseprite/api)
- [Aseprite CPP source that receives Lua inputs](https://github.com/aseprite/aseprite/tree/main/src/app/script)
- [Aseprite General Documentation](https://www.aseprite.org/docs/)
  - [Run Aseprite in Debug Mode](https://www.aseprite.org/docs/debug/)
  - [Aseprite Command Line Interface](https://www.aseprite.org/docs/cli/)
- [Example Scripts](https://github.com/aseprite/Aseprite-Script-Examples)
- [Aseprite Forum](https://community.aseprite.org/)
- [Lua Documentation](http://www.lua.org/docs.html)

## Gallery

This repo includes

- An arc (mesh).

  ![Arc](screencaps/arc.png)

- A brick maker.

  ![Bricks](screencaps/bricks.png)

- Color curve presets. ([Test image source](https://en.wikipedia.org/wiki/File:Fire_breathing_2_Luc_Viatour.jpg).)

  ![Color Curve](screencaps/colorCurve.png)

- An LCh Color Wheel.

  ![Color Wheel](screencaps/colorWheel.png)

- A conic gradient.

  ![Conic Gradient](screencaps/conicGradient.png)

- A Floyd-Steinberg filter ([Test model source](https://www.myminifactory.com/object/3d-print-horseman-at-maria-theresia-platz-152331).)

  ![FS Dither](screencaps/dither.png)

- A hexagon grid generator.

  ![Hexagon Grid](screencaps/hexGrid.png)

- A custom GPL exporter.

  ![GPL Export](screencaps/exportgpl.png)

- An animated infinity loop.

  ![Infinity Loop](screencaps/infinityLoop.png)

- A text insertion dialog.

  ![Insert Text](screencaps/insertText.png)

- A pixel art isometric (dimetric) grid.

  ![Dimetric Grid](screencaps/isoGrid.png)

- LCh color picker.

  ![LCh Color Picker](screencaps/lchPicker.png)

- A linear gradient.
 
  ![Linear Gradient](screencaps/linearGradient.png)

- Luminance (grayscale) remapping. ([Test image source](https://en.wikipedia.org/wiki/File:Fire_breathing_2_Luc_Viatour.jpg).)

  ![Luminance remapping](screencaps/lumRemap.png)

- Custom New Sprite

  ![New Sprite](screencaps/newSpritePlus.png)

- Palette Coverage.

  ![Palette Coverage](screencaps/paletteCoverage.png)

- Palette Manifest.

  ![Palette Manifest](screencaps/paletteManifest.png)

- Palette To Cel Assignment.

  ![Palette To Cel](screencaps/paletteToCel.png)

- RGB channel separation.

  ![Separate RGB](screencaps/sepRgb.png)

- A regular convex polygon.

  ![Polygon](screencaps/polygon.png)

- A polar grid.

  ![Polar Grid](screencaps/polarGrid.png)

- A radial gradient.

  ![Radial Gradient](screencaps/radialGradient.png)

- A rounded rectangle.

  ![Rounded Rectangle](screencaps/roundedRect.png)

Appearances may vary as features are added to or removed from underlying scripts.
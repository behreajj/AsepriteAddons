# Aseprite Add-ons

This repository developed out of the Medium article, ["How To Script Aseprite Tools in Lua"](https://behreajj.medium.com/how-to-script-aseprite-tools-in-lua-8f849b08733). Short demonstrations for some the scripts here can be found in this [Youtube playlist](https://www.youtube.com/playlist?list=PLK6A984Cb4MVaYKSGIn9SalpD9EVrfvUi).

## Installation

To install, click on the green `Code` button above. Select `Download ZIP` from the pop-up menu. Unzip the file after it has finished downloading. In Aseprite, go to `File > Scripts > Open Scripts Folder`. Copy `commands`, `dialogs` and `support` folders from the unzipped download into the folder that Aseprite has opened. Return to Aseprite, go to `File > Scripts > Rescan Scripts Folder`.

There is a [known issue](https://community.aseprite.org/t/script-folder-path-cannot-open-no-such-file-or-directory/16818/) when Aseprite's script folder is on a file path that includes characters such as 'é' (e acute) or 'ö' (o umlaut).

## Usage

Aseprite version 1.3.16 is the minimum supported version to run these scripts.

To use, go to `File > Scripts` and choose from entries in the `dialogs` or `commands` folder.

Scripts can be assigned shortcuts in `Edit > Keyboard Shortcuts`. Dialog buttons can be called by holding down the `Alt` key and pressing the underlined letter of the button's label. For example, `Alt+C` will close dialogs, per the 'C' in "CANCEL".

Most scripts dealing with color assume [standard RGB](https://en.wikipedia.org/wiki/SRGB) is the working color profile. The window profile is set under `Edit > Preferences > Color`. The sprite profile is set under `Sprite > Properties`.

## References

For more resources, see

- [Aseprite Type Definition](https://github.com/behreajj/aseprite-type-definition)
- [Aseprite CPP source that receives Lua inputs](https://github.com/aseprite/aseprite/tree/main/src/app/script)
- [Aseprite Scripting API](https://github.com/aseprite/api)
- [Lua Documentation](http://www.lua.org/docs.html)
- [Aseprite General Documentation](https://www.aseprite.org/docs/)
  - [Run Aseprite in Debug Mode](https://www.aseprite.org/docs/debug/)
  - [Aseprite Command Line Interface](https://www.aseprite.org/docs/cli/)
- [Aseprite Forum](https://community.aseprite.org/)

## Gallery

This repo includes

- Export Tile Maps and Sets to [Tiled](https://www.mapeditor.org/). ([Test image source](https://opengameart.org/content/more-nes-like-tiles).)

  ![Export Tiles](screencaps/exportTiles.png)

- Color curves. ([Test image source](https://en.wikipedia.org/wiki/File:Fire_breathing_2_Luc_Viatour.jpg).)

  ![Color Curve](screencaps/colorCurve.png)
  
- A sweep gradient.

  ![Sweep Gradient](screencaps/conicGradient.png)

- A dither filter. ([Test image source](https://en.wikipedia.org/wiki/File:David_-_The_Death_of_Socrates.jpg).)

  ![Dither](screencaps/dither.png)

- Interlaced layers. ([Test image source](https://en.wikipedia.org/wiki/File:David_-_The_Death_of_Socrates.jpg).)

  ![Interlaced](screencaps/interlaced.png)

- LCh color picker.

  ![LCh Color Picker](screencaps/lchPicker.png)

- A linear gradient.
 
  ![Linear Gradient](screencaps/linearGradient.png)

- Gradient map. ([Test image source](https://en.wikipedia.org/wiki/File:Fire_breathing_2_Luc_Viatour.jpg).)

  ![Luminance remapping](screencaps/lumRemap.png)

- Custom New Sprite

  ![New Sprite](screencaps/newSpritePlus.png)

- Custom Open Sprite

  ![Open Sprite](screencaps/openSpritePlus.png)

- Normal color picker.

  ![Normal Map](screencaps/normalMap.png)

- Normal from height.

  ![Normal From Height](screencaps/normalFromHeight.png)

- Outline Gradient.

  ![Outline Gradient](screencaps/outlineGradient.png)

- Palette Manifest.

  ![Palette Manifest](screencaps/paletteManifest.png)

- A radial gradient.

  ![Radial Gradient](screencaps/radialGradient.png)

- RGB channel separation.

  ![Separate RGB](screencaps/sepRgb.png)

- Cel transformation.

  ![Cel Transformation](screencaps/transformCel.png)

Appearances may vary as features are added to or removed from underlying scripts.

🇹🇼 🇺🇦
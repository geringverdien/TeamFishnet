## 1.3.5

* made script sharing enabled by default
* fixed script share gui not containing players or containing duplicate players

## 1.3.4

* partially switched over to Socks player API
* added a script share menu (top left) and `-sendscript [name]` chat command to share scripts with other Finapse users easily


## 1.3.3

* reverted a change that caused executing new scripts to break processing on previously run scripts

## 1.3.2

* manifest changes for the VSCode extension tutorial
* changed `print` color to be bright
* added an `error` and `warn` function (same as print but text is red and yellow)
* `extends Node` now gets stripped to add better VSCode support

## 1.3.1

* manifest updates

## 1.3.0

* Visual Studio Code support!!! Enable the websocket in the mod config (restart game for it to take effect), install the [Finapse Xecute extension](https://github.com/d29l/TeamFishnet/raw/refs/heads/main/Finapse%20X/finapse-xecute-0.0.1.vsix) and start executing code with a button in the bottom left or by setting an action shortcut in your settings :3
* ~~added a `wait(seconds)` function~~ i hate godot i hate godot i hate godot i h

## 1.2.6

* Added an icon.png and a homepage link for Tacklebox
* Fixed a bug replacing `print` with `customPrnt` in places where it shouldn't (ty Aym)
* Removed a line of code that spammed errors in the debug console (ty Kikin)

## 1.2.5

* Added a button to delete/stop all previously executed scripts
* Added more keywords to the syntax highlighting
* Clear button now adds `func _ready():` automatically
* Added an error message for parser errors in local chat

## 1.2.0

* Made the executor window resizable
* Added button to save code to a `.gd` file
* Arranged the buttons a bit more neatly

## 1.1.0

* Added button to open `*.gd` files in the editor
* Made executor window draggable
* `loadstring` function now strips starting and ending whitespaces
* Fixed version formatting for TackleBox metadata

## 1.0.1

* Added BlueberryWolfi's Keybinds and Player libraries to use from inside script
* Made the keybind to open F1 and customizable in the settings

## 1.0.0

* Working execution in full script environment
* Added default `localPlayer` variable
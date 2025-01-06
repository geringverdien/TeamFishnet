## 1.3.0

* Visual Studio Code support!!! Enable the websocket in the config, copy the [extension folder](https://github.com/d29l/TeamFishnet/blob/main/Finapse%20X/vsc%20extension.zip) into your vsc extensions folder, relaunch your game and start executing code with a button in the bottom left :3
* added a `wait(seconds)` function

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
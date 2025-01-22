# ModSync

Mod intended to make getting other peoples mods easier - brought to you by Team Fishnet 🐟🥅

![image](https://raw.githubusercontent.com/geringverdien/TeamFishnet/refs/heads/main/ModSync/screenshot.png)

## About

ModSync allows you to share and receive a list with all mods someone else has installed (or alternatively which ones you are missing)! When you are hosting a lobby, anybody who joins you that also has ModSync installed will receive a list of all your shared mods that gets automatically copied to their clipboard.

Use the `-modsync [player name]` command to request a modlist of someone who isn't the lobby's host.

### Features

* Automatically request modlists from the lobby host
* Get any user's modlist using the `-modsync [player name]` chat command
* Individually toggle which mods to share with others and which ones not
* Save modlists to a file for easier access
* Advertise your use of ModSync to other players to get more users to share mods with :3
* Real-time configuration, no game restarts required (see below for more details)

## Configuration
`Sync as host`: Players joining your lobby will receive your modlist and vice versa

`Sync via chat`: Toggles the ability for players to request your modlist via chat command and vice versa

`Ignore installed mods`: Ignores any mods which you are already using yourself

`Save list to file`: Opens a file prompt to save the modlist locally

`Copy as JSON`: Copies the modlist in a JSON format instead of a newline separated list

`Chat advertisement`: Sends a message to everyone in chat when you receive somebody's modlist

Below these settings you will see every mod you have installed (except for ModSync and its dependencies). Set their values to Disabled if you don't want a mod to show up for users receiving your modlist.
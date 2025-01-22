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
* Real-time configuration, no game restarts required (see below for more details)

## Configuration
![image](https://raw.githubusercontent.com/geringverdien/TeamFishnet/refs/heads/main/ModSync/config%20screenshot.png)
Your default configuration will look something like this. 

`Sync as host`: All joining players will automatically get your modlist

`Sync via chat`: Other players can use the chat command to get your modlist

`Ignore installed mods`: Dont' show/copy any mods which you are already using yourself

`Copy as JSON`: Copies the modlist in a JSON format instead of a newline separated list

Below these settings you will see every mod you have installed. Set their values to Disabled if you don't want a mod to show up for users receiving your modlist.
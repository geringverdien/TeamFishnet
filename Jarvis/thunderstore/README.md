# Jarvis, an AI admin assistant for WEBFISHING

## Usage

Simply start a chat message with "jarvis," followed by your request.

**Example:** `"jarvis, take me to the lighthouse"`

## Setup
To use Jarvis you need to get an API key off together.ai, you can get one [here](https://api.together.ai/settings/api-keys)

**Note:** Make sure you created an application key and not a "Together.ai user key"

After you copied the key to your clipboard, simply open up the Jarvis mod configuration in the TackleBox "mods" window and paste it as the `Api Key` field and hit `Save Changes`. If you wish you can also change the used model (Llama 3.3 free version by default) and various other settings.

### Features

Jarvis knows the usernames of other people in your lobby, as well as the person who is standing the closest to you and the last person you targeted with a command.
**Example:** `jarvis, punch the person next to me` or `jarvis, bring me to my last target`

## Commands

Below is a table with all the internal functions that Jarvis can call. Their names do not need to be explicitly named for the AI to understand what you're trying to do

| internal command | description             | example                          |
| :--------------- | :---------------------: | -------------------------------: |
| punch            | punches target player   | jarvis, give eli a slap          |
| goto             | teleports you to target | jarvis, bring me to eli          |
| warp             | warps you to a location | jarvis, take me to the dock      |
| speed*           | sets your walk speed    | jarvis, set my speed to 25       |
| *                | can also reset speed    | jarvis, reset my speed           |
| talk             | lets Jarvis talk        | jarvis, who are you?             |
| cmds             | lists commands in chat  | jarvis, what can you do?         |
| null             | does nothing            | jarvis, bake me a tasty pie      |

## Warp locations

These are all current warp locations: 
- spawn
- lake
- lighthouse
- docks
- small docks (docks at the scratch ticket shop)

## Dependencies
* [GDWeave](https://github.com/NotNite/GDWeave)
* [TackleBox](https://github.com/puppy-girl/TackleBox)
* [Socks](https://thunderstore.io/c/webfishing/p/toes/Socks/)
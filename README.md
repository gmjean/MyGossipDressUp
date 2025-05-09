# MyGossipDressUp for World of Warcraft (WotLK 3.3.5a)

Hello, adventurer! Welcome to **MyGossipDressUp**!

Ever been talking to an NPC, seen them link a cool piece of gear, and wished you could quickly see what it looks like? Now you can!

MyGossipDressUp is a simple addon that lets you instantly preview armor and weapons directly from the NPC dialogue (Gossip) windows.

## What It Does

When you're in a gossip window and see an item linked in the text or as an option:

*   Simply **press and hold the `CTRL` key**.
*   A preview window will pop up, showing your character मॉडल wearing the item!

This way, you can easily check out how that quest reward or vendor item will look on you before you commit.

## How to Use

1.  Install the addon like any other World of Warcraft addon.
2.  Log into the game.
3.  When you open an NPC gossip window that contains an item link:
    *   **Press and hold your `CTRL` key.**
    *   If your mouse is over an item link (in the main text or in one of the gossip options), a preview window will appear.
4.  The preview window:
    *   Can be moved by dragging its title bar.
    *   Can be closed by clicking the 'X' button, using the `/mgdu clear` command, or it will often close automatically when you close the gossip window (unless you've moved the preview window).
    *   Allows you to rotate the model by clicking and dragging on it.
    *   Allows you to zoom using the mouse wheel.
    *   Has buttons `<` and `>` to rotate the model, and a "Reset" button to reset the view.

## Slash Commands

You can control MyGossipDressUp with the following chat commands:

*   `/mgdu` or `/mgdu toggle`
    *   Turns the addon On or Off.
*   `/mgdu debug`
    *   Toggles debug messages in chat (useful for troubleshooting).
*   `/mgdu last`
    *   Tries to re-preview the last item the addon processed.
*   `/mgdu clear`
    *   Clears the current preview and closes the preview window.
*   `/mgdu delay <N>`
    *   Sets the item preview loading delay (in frames, from 1 to 10). Example: `/mgdu delay 5`.
    *   Type `/mgdu delay` to see the current setting. A higher delay might help if items sometimes don't load visually on slower systems.
*   `/mgdu resetframe`
    *   Resets the position of the preview window back to the center of your screen.
*   `/mgdu help`
    *   Shows a list of available commands.

*(The `/mgdu clickmode` and `/mgdu testmodel` commands are currently for experimental/debug purposes).*

## Requirements

*   This addon is designed for **World of Warcraft: Wrath of the Lich King (Patch 3.3.5a)**.

## Credits & Future

*   **Author:** Dudsz-us-Azralon
*   This addon was developed with the help and guidance of an AI assistant.
*   Future ideas include smoother rotation animations, more UI options, and potentially a click-to-preview mode. Feedback and suggestions are welcome!

---

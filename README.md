# ChainBuilder

ChainBuilder is an Ashita v4 addon for Final Fantasy XI that helps you
build and preview skillchains.

Choose your weapon and weapon skill, add additional steps, and
ChainBuilder will show the skillchain created at each stage. It also
includes support for Blue Magic skillchain closers and Automaton
skillchains.

## Install

Copy the `ChainBuilder` folder into your Ashita `addons` folder, then
load it in game with `/addon load chainbuilder`.

## Commands

-   `/sc`: open or close ChainBuilder.
-   `/sc show`: show the ChainBuilder window.
-   `/sc hide`: hide the ChainBuilder window.

You can also use `/chainbuilder` in place of `/sc`.

## Notes

-   The window header shows your character's name and jobs, so you can
    tell your characters apart.
-   ChainBuilder uses Segoe UI from your Windows Fonts folder. If it
    can't be loaded, the game's normal ImGui font is used.

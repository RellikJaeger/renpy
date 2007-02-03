# This demonstrates nvl_mode.rpy.

init:

    # Declare an nvl-version of eileen.
    $ nvle = NVLCharacter("Eileen",
                          color="#c8ffc8")


label demo_nvlmode:

    nvl clear
    nvl show dissolve

    nvle "NVL-style games are games that cover the full screen with text, rather then placing it in a file at the bottom of the screen."

    nvle "Ren'Py ships with a file, nvl_mode.rpy, that implements NVL-style games. You're seeing an example of NVL-mode at work."

    nvl clear
    
    nvle "To use NVL-mode, you need to define NVLCharacters instead of regular old Characters."

    nvle "You use 'nvl clear' to clear the screen when that becomes necessary."

    nvl hide dissolve
    nvl show dissolve

    nvle "The 'nvl show' and 'nvl hide' statements use transitions to show and hide the NVL window."
    
    # Doing this during the game isn't recommended, it's better to do
    # it in an init block. We have to do it here because we need to use
    # both kinds of menus.
    $ menu = nvl_menu
    
    menu:

        nvle "The nvl_mode also supports showing menus to the user, provided they are the last thing on the screen. Understand?"

        "Yes.":

            nvl clear

            nvle "Good!"

        "No.":

            nvl clear

            nvle "Well, it might help if you take a look at the demo code."

    $ menu = renpy.display_menu

    nvl hide dissolve
    
    return
        
    

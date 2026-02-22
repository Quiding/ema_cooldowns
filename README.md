# EMA Cooldowns

A Gemini-generated plugin for **EMA (Ebony's MultiBoxing Assistant)** [https://www.curseforge.com/wow/addons/ema](https://www.curseforge.com/wow/addons/ema). This addon provides persistent, team-wide cooldown tracking bars that automatically adapt to each character's class.

Looking for Shaman-specific totem management? Check out [EMA Totems](https://github.com/Quiding/ema_totembar).

## Key Features

*   **Persistent Cooldown Bars:** View all tracked spells for your entire team in one compact interface. Available spells are shown semi-transparently, while those on cooldown light up with circular animations and numeric timers.
*   **Automatic Class Detection:** Bars automatically populate with the correct spells based on each team member's class (e.g., Shaman spells for Shamans, Paladin spells for Paladins).
*   **Role-Based Sorting:** Keep your team organized with **RoleAsc** sorting (Tank > Healer > Damager > None), ensuring your vital roles are always at the top of the list.
*   **Independent Styling:** Fully customize your interface with separate background, border, and color selections for the **Whole UI Frame** and the **Individual Character Bars**.
*   **Robust Spell Discovery:** Includes a deep-scan engine that ensures talents like **Elemental Mastery** and common spells like **Frost Shock** are found by name regardless of your current character's class.
*   **Online Tracking:** Bars only display for team members who are currently online and in your group, keeping your screen clutter-free.
*   **EMA Synchronization:** Push your spell lists and layout settings from the master to the entire team with one click.

## Installation

1.  Download the repository.
2.  Save the folder as **"EMA_Cooldowns"** in your `Interface\AddOns` directory.
3.  Ensure **EMA** is installed and enabled.

## Usage

*   Open the EMA configuration menu and navigate to **Class > Cooldowns**.
*   Use **Select Class to Manage** to add or remove spells for each specific class.
*   Reorder spells using the **[Up]** and **[Dn]** controls to customize the bar layout.
*   Adjust the **Overall Scale**, **Alpha**, and **Spacing** to fit your UI layout.
*   Use the command `/ecd test` to verify your bar position and visibility.

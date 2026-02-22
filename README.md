# EMA Cooldowns

A Gemini-generated plugin for **EMA (Ebony's MultiBoxing Assistant)** [https://www.curseforge.com/wow/addons/ema](https://www.curseforge.com/wow/addons/ema). This addon provides persistent, team-wide cooldown tracking bars for all character classes.

Looking for other team-wide tracking? Check out [EMA Buffs](https://github.com/Quiding/ema_buffs) or Shaman-specific [EMA Totems](https://github.com/Quiding/ema_totems).

**Note:** This addon likely requires your team to be in the same guild and utilize **guild communications** for settings synchronization, however, all timers are tracked via the **combat log** for high-precision updates.

Is this AI slop? probably, but it seems to work

## Key Features

*   **Persistent Cooldown Tracking:** View all tracked spells for your entire team in one compact interface. Available spells are shown semi-transparently, while those on cooldown light up with circular animations and numeric timers.
*   **Independent UI Styling:** Fully customize your interface with separate background, border, and color selections for the **Whole UI Frame** and the **Individual Character Bars**.
*   **Customizable Spell Lists:** Easily add, remove, and reorder spells for every class in the game to match your team's needs.
*   **Instant Visual Feedback:** High-precision timers and circular cooldown progress ensure you always know exactly when your team's abilities are ready.
*   **Team Synchronization:** Push your spell lists and layout settings from the master to the entire team with a single click.

## Installation

1.  Download the repository.
2.  Save the folder as **"EMA_Cooldowns"** in your `Interface\AddOns` directory.
3.  Ensure **EMA** is installed and enabled.

## Usage

*   Open the EMA configuration menu and navigate to **Class > Cooldowns**.
*   Use **Select Class to Manage** to customize spells for specific classes.
*   Adjust the **Overall Scale**, **Alpha**, and **Spacing** to fit your UI layout.
*   Use the command `/ecd test` to verify your bar position and visibility.

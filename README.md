# EMA Cooldowns

A Gemini-generated plugin for **EMA (Ebony's MultiBoxing Assistant)** [https://www.curseforge.com/wow/addons/ema](https://www.curseforge.com/wow/addons/ema). This addon provides persistent, team-wide cooldown tracking bars for all character classes.

Looking for other team-wide tracking? Check out [EMA Buffs](https://github.com/Quiding/ema_buffs) or Shaman-specific [EMA Totems](https://github.com/Quiding/ema_totems).

**Note:** This addon likely requires your team to be in the same guild and utilize **guild communications** for settings synchronization, however, all timers are tracked via the **combat log** for high-precision updates.

![ezgif-8bfe5fb2f2e656b7](https://github.com/user-attachments/assets/d510f737-f1ca-4f12-a113-81b4167a5414)




**Disclaimer:** These addons are early-stage Gemini-generated prototypes and have not undergone extensive bug testing. Please use with caution and report any issues you find.

## Key Features

*   **Persistent Cooldown Tracking:** View all tracked spells for your entire team in one compact interface. Available spells are shown semi-transparently, while those on cooldown light up with circular animations and numeric timers.
*   **Independent UI Styling:** Fully customize your interface with separate background, border, and color selections for the **Whole UI Frame** and the **Individual Character Bars**.
*   **Customizable Tracking Lists:** Easily add, remove, and reorder **spells, trinkets, and consumables** for every class in the game.
*   **Team-Wide Support:** Automatically detects and tracks abilities across your entire team using high-precision combat log monitoring.
*   **Instant Visual Feedback:** High-precision timers and circular cooldown progress ensure you always know exactly when your team's abilities are ready.
*   **Team Synchronization:** Push your tracking lists and layout settings from the master to the entire team with a single click.

## Installation

1.  Download the repository.
2.  Save the folder as **"EMA_Cooldowns"** in your `Interface\AddOns` directory.
3.  Ensure **EMA** is installed and enabled.

## Usage

*   Open the EMA configuration menu and navigate to **Class > Cooldowns**.
*   Use **Select Class to Manage** to customize tracking for specific classes.
*   **Tracking Trinkets & Consumables:** You can add trinkets (e.g., "Earthstrike") or consumables (e.g., "Super Mana Potion") to any class list by typing their exact name or Item ID into the "Add Spell Name/ID" box.
*   Adjust the **Overall Scale**, **Alpha**, and **Spacing** to fit your UI layout.
*   Use the command `/ecd test` to verify your bar position and visibility.


## More Images of settings
<img width="704" height="664" alt="image" src="https://github.com/user-attachments/assets/a27b0583-f746-4f81-bbc4-f6df86c9f514" />
<img width="703" height="731" alt="image" src="https://github.com/user-attachments/assets/aa85bd50-7706-46e1-a0d3-7b61bba1039c" />
<img width="713" height="732" alt="image" src="https://github.com/user-attachments/assets/24971a79-b9d9-4264-bd74-6fc273973abd" />


## Export example
*  Tracked Spells List (Avenging Wrath, Divine Shield, Adamantine Figurine for Paladin -  Elemental Mastery, Earth Shock, Chain Lightning for Shamans )```^1^T^SHUNTER^T^t^SWARRIOR^T^t^SPALADIN^T^N1^T^Sid^N0^Sduration^N180^Sname^SAvenging~`Wrath^Sicon^N135875^t^N2^T^Sid^N1020^Sduration^N240^Sname^SDivine~`Shield^Sicon^N135896^t^N3^T^Stype^Sitem^Sname^SAdamantine~`Figurine^Sid^N27891^Sduration^N120^Sicon^N134907^t^t^SMAGE^T^t^SPRIEST^T^t^SGLOBAL^T^t^SWARLOCK^T^t^SROGUE^T^t^SDRUID^T^t^SDEATHKNIGHT^T^t^SSHAMAN^T^N1^T^Sid^N16166^Sduration^N180^Sname^SElemental~`Mastery^Sicon^N136115^t^N2^T^Sid^N8042^Sduration^N5.8^Sname^SEarth~`Shock^Sicon^N136026^t^N3^T^Sid^N421^Sduration^N6^Sname^SChain~`Lightning^Sicon^N136015^t^t^t^^```
*  Settings & Positions
```^1^T^SlockBars^B^SglowColorB^N1^SbarMargin^N0^SglowColorG^N1^SbarBorderStyle^SNone^SframeBackgroundColourG^N0^SbarBorderColourR^F4521261069762560^f-53^SframeBorderColourR^N0.5^StimerFontSize^N14^Sglobal^T^t^SbreakUpBars^b^SreadyAlpha^N0.3^SrunningAlpha^N1^SbarBackgroundColourA^N1^SborderStyle^SNone^SbarScale^N1.4^SfontSize^N12^SframeBorderStyle^SNone^SframeBorderColourG^N0.5^SbarBorderColourG^N0^SbarBackgroundColourG^F5510286811332608^f-53^StimerColorR^N1^SbarBackgroundStyle^SNone^SiconSize^N36^SfontStyle^SArial~`Narrow^SframeBackgroundColourA^N1^SshowNames^b^SbarBorderColourB^F5722220898811904^f-54^StimerColorG^N1^SshowBars^B^SbarOrder^SRoleAsc^SglowAnimated^B^SbarBackgroundColourR^N1^SframeBorderColourA^N1^SbarBorderColourA^N1^SbarBackgroundColourB^N0^SbackgroundStyle^SBlizzard~`Dialog~`Background~`Dark^SshowTimers^b^SframeBackgroundColourB^F4521261069762560^f-58^SframeBackgroundStyle^SNone^SglowColorR^N0^SglowColorA^N1^SframeBorderColourB^N0.5^SbarLayout^SHorizontal^SiconMargin^N0^SframeBackgroundColourR^F7347049439690755^f-56^StimerColorB^N1^StrackedTrinkets^T^SPALADIN^T^N1^T^Stype^Sitem^Sname^SScryer's~`Bloodgem^Sid^N29132^Sduration^N90^Sicon^N134085^t^N2^T^Stype^Sitem^Sname^SAdamantine~`Figurine^Sid^N27891^Sduration^N120^Sicon^N134907^t^t^t^SbarAlpha^N1^SglowIfBuffActive^B^t^^```

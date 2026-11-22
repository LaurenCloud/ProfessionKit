# ProfessionKit

A compact professions window for **WoW Forever**, with recipe rankings based on the materials in your bags. Uses native WoW artwork, item icons, coin icons, and crafting controls.

Early development release. Targets Forever interface **16001** and the English client.

## Using the addon

Open a profession normally, press **K**, use the professions menu button, click the minimap icon, or type `/professionkit`.

Drag the bottom-right grip up or down to choose a window height. A taller window shows more recipe rows. ProfessionKit remembers your height across reloads and makes extra room for taller recipe details or an active batch while needed. The width is fixed.

- **Skill-ups** ranks estimated skill gains; **Prices** ranks recorded auction value.
- **× Quantity**, checked by default, ranks the whole craftable batch. Uncheck it to rank one craft's skill gain or output value, including every item that craft produces. The choice is remembered. Rows keep showing your available quantity, total skillup estimate, and total/each prices.
- Equal scores sort by available craft quantity, highest first, then alphabetically. Quantity is green when materials are available and red at zero; recipe-name colors show skill-up difficulty separately.
- Skill-up estimates align left and total/each prices align right below the icon, quantity, and recipe name. The selected recipe connects to its detail panel like a tab. The sort buttons only change ordering; both values stay visible.
- All learned recipes remain visible unless excluded by the search, which matches recipe names and categories.
- Select a recipe and click **Pin** in its details to keep it in **Pinned** at the top of that profession. Pinned regular and Camping recipes rank together using the current sort and **× Quantity** setting. Click **Unpin** to return a recipe to **Recipes** or **Camping**. Pins are saved across reloads.
- Recipe details show owned/required materials, vendor purchase prices, auction prices, and the resulting item.
- Hover a recipe in the list to see the crafted item's native tooltip. Equipment enchants show the spell tooltip.
- A gold wheel around the recipe icon marks the active craft. It fills clockwise over the batch, or spins when the client has no duration.
- **Create** crafts the entered quantity; **Create all** uses the available quantity, capped by remaining recipe charges. Recipes that allow only one craft hide batch controls. Cooldowns display their remaining duration, and client-disabled recipes show their reason.
- Square **+ / −** buttons adjust the quantity. You can browse professions and recipes while crafting. A separate, gold-bordered panel at the bottom right always names the active recipe and shows its icon. A gold progress bar shows remaining time in white, with batch count and estimated total time beside it. Its layout stays the same as you change selections. Timing follows the live cast when available. Only one batch runs at a time; Create becomes available again when it ends.
- **Enchanting:** click the target item slot to open your bags, then drag an eligible item into the slot. **Equipped…** lets you choose eligible worn gear without unequipping it. Right-click the slot to clear it. **Enchant** applies one enchant; the target stays selected for repeat casts. WoW's overwrite confirmation remains in place. The effect description replaces output prices, since an equipment enchant is not an auctionable item.
- Missing tools or stations replace the craft controls with a requirement such as **Requires: Forge**.
- Small station icons beside profession ranks light up with a green border when a relevant station is nearby. Hover for individual station names and states, including specialized stations from learned recipes. Dim icons mean unavailable or not yet known; the tooltip distinguishes these. Individual recipes still check their own tools and stations.

Right-click the minimap icon to configure **Replace the normal professions window**, enabled by default. Left-click always opens ProfessionKit. **Original window**, or `/professionkit native`, opens Blizzard's window for the current session.

## Installation

Place the `ProfessionKit` folder inside `World of Warcraft/_forever_/Interface/AddOns/`. The resulting path should contain `ProfessionKit/ProfessionKit.toc` directly, without an extra enclosing folder. Restart WoW after the initial installation; `/reload` is enough for updates to an existing installation.

**Upgrading from ProfessionPro or Professionator.** Exit WoW normally so it saves your latest settings. The repository installer below archives both previous addon folders and carries over each account's settings, including pinned recipes and vendor prices.

For a manual upgrade, move any `ProfessionPro` and `Professionator` folders from `Interface/AddOns` to a backup location outside `AddOns`, then install `ProfessionKit`. In each account's `WTF/Account/<account>/SavedVariables` folder, keep any existing `ProfessionKit.lua`. If it is missing, copy `ProfessionPro.lua` to `ProfessionKit.lua` (use `Professionator.lua` if it is the only previous file). In the copy, change only the opening variable name from `ProfessionProDB` or `ProfessionatorDB` to `ProfessionKitDB`. Keep the original as a backup, then start WoW.

No other addon is required. **Auctionator** is optional and supplies locally recorded auction prices. Scan or search the auction house to populate its database. ProfessionKit does not query current listings remotely or change Auctionator settings.

## Ranking and price details

Skill-up estimates use recipe difficulty weights: orange 1, yellow 0.5, green 0.2, gray 0. They multiply available crafts by points per successful skill-up and cap the result at the trained skill limit and recipe gray threshold when available. These are ranking heuristics, not exact probabilities. Displayed estimates round down; sorting retains fractional values. Inventory and skill changes recalculate the estimates.

Prices use `available crafts × minimum output quantity × recorded auction price per item`. This is gross output value, not profit. Each recipe is an alternative use of the same materials; the list is not a combined crafting plan. Unknown prices sort last within each section and display as a dash. The header shows the actual recorded output price's age when available. Vendor purchase prices are learned when visiting a merchant; they are distinct from vendor sale values.

Craftability counts materials directly in your bags. It does not plan intermediate crafts or purchases. **Original window** remains available for trade-window enchants on another player's gear, disenchanting/salvage, gathering journals, and recipes requiring reagent choices. Crafting always requires an explicit click and rechecks the live profession, inventory, requirements, cooldown, allowed quantity, target item, and combat state. Nothing buys materials, posts auctions, or sends messages.

## Diagnostics and limitations

Local diagnostics are currently enabled and bounded to the latest 160 entries in `ProfessionKitDB.craftDiagnostics`. They record craft requests, client calls/events, recipe/material/session data, and nearby errors. Blocked or forbidden addon actions are captured even outside crafting, preserving the addon/action named by WoW and whether combat or the custom window was active. The named addon can be unknown; a record does not by itself establish the root cause. Diagnostics do not read chat or upload data. `/professionkit report` captures an additional diagnostic; `/reload` saves it to disk. Review captured data before sharing it with a bug report.

The addon has been exercised through full-addon simulated workflows and live personal use. Protected API behavior, client artwork, station proximity, and native queue survival when switching professions during crafting still require in-game verification. Camping grouping currently recognizes the English client category name.

Report issues through [GitHub Issues](https://github.com/LaurenCloud/ProfessionKit/issues), with the addon version, profession/recipe, expected behavior, and what happened. Mention whether the same craft works in **Original window**.

## Development

The source is plain Lua; no compilation is needed. The workflow runner uses Python, Lua 5.1 through `lupa`, and Pillow. Its preview renderer currently expects Windows fonts.

```powershell
python -m pip install lupa Pillow
python scripts/validate.py --run
.\scripts\deploy.ps1 -Install -GameDirectory 'C:\Program Files (x86)\World of Warcraft\_forever_'
python scripts/package.py --build
```

Validation loads every addon Lua file and drives its actual UI/event callbacks with simulated frames, recipes, inventory, and prices. It covers cold opens, profession changes, ranking and search, camping sections, scrolling, missing data, crafting, timing, interrupted/blocked requests, native fallback, preferences, and reload persistence. Enchanting scenarios exercise bag opening, invalid drops, equipped selection, item movement/removal, locked items, overwrite accept/cancel, and single casts. Cooldown, charge, single-craft, disabled-recipe and station-proximity scenarios use native-shaped API data. It writes an inspectable report and layout previews under `artifacts/`. Previews approximate game artwork and use placeholder item icons; they are not game screenshots.

For an optional read-only Auctionator replay, pass both `--auctionator-directory` and `--auctionator-settings` to `scripts/validate.py`, pointing to your installed addon directory and its saved `Auctionator.lua` file. No saved settings are bundled or committed.

The installer and package builder require a passing validation report whose source hashes match the current addon. Installation backs up existing files and verifies the copied hashes. Packaging includes only the addon, this README, and the MIT license. Downloaded references, local tools, backups, and captured data are excluded.

API reference: [Forever UI source](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated). Auctionator integration uses its public read-only API.

## License

[MIT](LICENSE), copyright 2026 LaurenCloud. Referenced WoW artwork remains Blizzard's; game textures are loaded from the client and are not bundled in this repository or addon package.

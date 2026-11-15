# Professionator

A compact professions window for **WoW Forever**, with recipe rankings based on the materials in your bags. Uses native WoW artwork, item icons, coin icons, and crafting controls.

Early development release. Targets Forever interface **16001** and the English client.

## Using the addon

Open a profession normally, press **K**, use the professions menu button, click the minimap icon, or type `/professionator`.

- **Skill-ups** ranks the estimated skill gains from all crafts your current materials can supply.
- **Prices** ranks the recorded auction value of that whole batch. Rows show total value and price per output item.
- **Have materials** filters to recipes you can currently craft. Search matches recipe names and categories.
- **Camping** recipes appear in their own section below regular recipes in both sorts. Camping can be selected automatically when it is the only search/filter result.
- Recipe details show owned/required materials, vendor purchase prices, auction prices, and the resulting item.
- **Create** crafts the entered quantity; **Create all** uses the available quantity. Square **+ / −** buttons adjust the quantity. During confirmed crafting, a gold progress bar tracks the whole batch beside its estimated total and remaining time; it uses live cast timing when available.
- Missing tools or stations replace the craft controls with a requirement such as **Requires: Forge**.

Right-click the minimap icon to configure **Replace the normal professions window**, enabled by default. Left-click always opens Professionator. **Original window**, or `/professionator native`, opens Blizzard's window for the current session.

## Installation

Place the `Professionator` folder inside `World of Warcraft/_forever_/Interface/AddOns/`. The resulting path should contain `Professionator/Professionator.toc` directly, without an extra enclosing folder. Restart WoW after the initial installation; `/reload` is enough for updates to an existing installation.

No other addon is required. **Auctionator** is optional and supplies locally recorded auction prices. Scan or search the auction house to populate its database. Professionator does not query current listings remotely or change Auctionator settings.

## Ranking and price details

Skill-up estimates use recipe difficulty weights: orange 1, yellow 0.5, green 0.2, gray 0. They multiply available crafts by points per successful skill-up and cap the result at the trained skill limit and recipe gray threshold when available. These are ranking heuristics, not exact probabilities. Displayed estimates round down; sorting retains fractional values. Inventory and skill changes recalculate the estimates.

Prices use `available crafts × minimum output quantity × recorded auction price per item`. This is gross output value, not profit. Each recipe is an alternative use of the same materials; the list is not a combined crafting plan. Unknown prices sort last within each section and display as a dash. The header shows the actual recorded output price's age when available. Vendor purchase prices are learned when visiting a merchant; they are distinct from vendor sale values.

Craftability counts materials directly in your bags. It does not plan intermediate crafts or purchases. Gathering journals and recipes requiring reagent choices can use **Original window**. Crafting always requires an explicit click and rechecks the live profession, inventory, requirements, and combat state. Nothing buys materials, posts auctions, or sends messages.

## Diagnostics and limitations

Local diagnostics are currently enabled and bounded to the latest 160 entries in `ProfessionatorDB.craftDiagnostics`. They record craft requests, client calls/events, recipe/material/session data, and nearby errors. Blocked or forbidden addon actions are captured even outside crafting, preserving the addon/action named by WoW and whether combat or the custom window was active. The named addon can be unknown; a record does not by itself establish the root cause. Diagnostics do not read chat or upload data. `/professionator report` captures an additional diagnostic; `/reload` saves it to disk. Review captured data before sharing it with a bug report.

The addon has been exercised through full-addon simulated workflows and live personal use. Protected API behavior, client artwork, and station proximity still require in-game verification. Camping grouping currently recognizes the English client category name.

Report issues through [GitHub Issues](https://github.com/LaurenCloud/Professionator/issues), with the addon version, profession/recipe, expected behavior, and what happened. Mention whether the same craft works in **Original window**.

## Development

The source is plain Lua; no compilation is needed. The workflow runner uses Python, Lua 5.1 through `lupa`, and Pillow. Its preview renderer currently expects Windows fonts.

```powershell
python -m pip install lupa Pillow
python scripts/validate.py --run
.\scripts\deploy.ps1 -Install -GameDirectory 'C:\Program Files (x86)\World of Warcraft\_forever_'
python scripts/package.py --build
```

Validation loads every addon Lua file and drives its actual UI/event callbacks with simulated frames, recipes, inventory, and prices. It covers cold opens, profession changes, sorting/filtering, camping sections, scrolling, missing data, crafting, timing, interrupted/blocked requests, native fallback, preferences, and reload persistence. It writes an inspectable report and layout previews under `artifacts/`. Previews approximate game artwork and use placeholder item icons; they are not game screenshots.

For an optional read-only Auctionator replay, pass both `--auctionator-directory` and `--auctionator-settings` to `scripts/validate.py`, pointing to your installed addon directory and its saved `Auctionator.lua` file. No saved settings are bundled or committed.

The installer and package builder require a passing validation report whose source hashes match the current addon. Installation backs up existing files and verifies the copied hashes. Packaging includes only the addon, this README, and the MIT license. Downloaded references, local tools, backups, and captured data are excluded.

API reference: [Forever UI source](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated). Auctionator integration uses its public read-only API.

## License

[MIT](LICENSE), copyright 2026 LaurenCloud. Referenced WoW artwork remains Blizzard's; game textures are loaded from the client and are not bundled in this repository or addon package.

# Professionator

WoW Forever addon, interface 16001. User's sketch defines the layout: left profession navigation, middle recipe list with search/filter/sort, right inputs → requirements → output and crafting controls.

The sketch defines structure, not a flat visual theme. Use WoW's native frame/button templates, game textures, gold headings and standard fonts. Harness previews approximate spacing and must not be presented as screenshots of native artwork.

Keep the layout compact and content-sized. Recipe rows are one line with native item/recipe icons, skill-up icons, count and estimate, or total/each coin prices. No footer or slogan. Show actual known auction-price age in the detail header over the price columns. No cost-per-craft or margin line. A native gold minimap quest arrow, rotated downward, links materials to output without a hammer or requirement label; unmet station/tool requirements replace crafting controls with one red message and disappear when controls return.

Use equal horizontal and vertical padding: a shared 12-unit inset around panel contents and tile content, with content-sized row heights. Recipe tiles have smaller 6-unit gaps. The compact search uses a 6-unit inset and an internal placeholder. Sort choices are small inset buttons labelled Sort; filtering uses a distinct Have materials checkbox. Keep the columns compact; long recipe lists should scroll sooner on smaller screens instead of shrinking the text. Use `est.` for estimates, not a tilde, which renders poorly in the game's font.

Camping recipes belong in a separate Camping section below regular recipes under both sorts. Default to the first regular recipe when available; camping can be selected automatically when it is the only search/filter result. Preserve explicit selections on refresh. Use the client's Camping category, not item-name guesses.

Keep Blizzard's trade-skill session alive while hiding its visual window. Craft only on an explicit user click, revalidate profession, recipe, materials, requirements and combat at that moment. Never auto-buy, post or share messages. Preserve native window fallback.

Craft through a direct C_TradeSkillUI.CraftRecipe(recipeID, count) call on the hardware-click path, matching the user's formerly installed ProfessionBuddy 2.1.1 Forever implementation. Do not wrap the action in pcall/xpcall or schedule it. Observe rejection via client events; only spellcast-start confirms crafting, and matching spellcast-success events complete a batch. Watchdog timers must be tied to their request and must never craft.

Left-clicking the minimap icon always opens Professionator. Right-click opens settings with a persistent replace-normal-window checkbox, defaulting on only when unset. Changes apply to the next normal profession open; an explicit original-window fallback lasts for that session only.

Use live C_TradeSkillUI data and Auctionator read-only APIs. Unknown prices are not zero. Vendor purchase prices and vendor sale values are distinct. Label skill ranking as heuristic when no exact chance is available. Show Create all total duration from spell cast time; refine total and remaining time from the live matching cast timestamps. Omit unknown timing rather than inventing a duration.

K and the menu button share ToggleProfessionsBook. Route that entry point to the remembered profession when replacement is enabled, including the first use after reload before any profession data is open. Preserve disabled replacement and explicit native fallback. Validate cold opens with Blizzard_Professions unloaded.

No unit tests. Validate full addon loading and user workflows with the integration runner and retain its report. Actual client behavior must be reported separately. Deploy with scripts/deploy.ps1, which backs up existing addon files. Source here is authoritative; do not edit only the installed copy.

Default update guidance: keep playing while files are edited, then `/reload` after deployment. Do not ask for a full restart for updates to this existing addon, including diagnostics or added files in its manifest. A new addon folder needs a full restart. SavedVariables edits require the game to be closed; code edits do not.

Display estimated skillups rounded down to whole numbers; retain fractional scores internally for sorting. Diagnostics are automatic, local, bounded and read-only observers of client calls/events. Capture blocked/forbidden actions from any addon even outside crafting; preserve WoW's attribution and do not infer blame from a generic warning. Preserve the previous capture across reload so it can be inspected after a failed custom craft and a successful native craft. Do not claim a live bug is fixed based only on the simulated workflow.

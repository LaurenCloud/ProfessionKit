"""Run full-addon workflows in Lua 5.1 and render the actual emitted frame tree."""
import argparse
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from datetime import datetime, timezone

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / ".tools"))
from lupa.lua51 import LuaRuntime
from PIL import Image, ImageDraw, ImageFont


def plain(value):
    if hasattr(value, "items"):
        entries = list(value.items())
        if entries and all(isinstance(key, int) for key, _ in entries):
            return [plain(value[index]) for index in range(1, len(entries) + 1)]
        return {str(key): plain(item) for key, item in entries}
    return value


def render_scene(scene, destination):
    widgets = {widget["identifier"]: widget for widget in scene}
    positions = {}

    def rectangle(widget):
        identifier = widget["identifier"]
        if identifier in positions:
            return positions[identifier]
        width, height = widget["width"], widget["height"]
        if widget.get("name") == "UIParent":
            result = (0, 0, width, height)
        else:
            point = (widget.get("points") or [["TOPLEFT", widget.get("parent"), "TOPLEFT", 0, 0]])[0]
            anchor, parent_identifier, relative_anchor, offset_x, offset_y = point
            parent = widgets.get(parent_identifier)
            parent_x, parent_y, parent_width, parent_height = rectangle(parent) if parent else (0, 0, 1440, 900)
            def factor(anchor):
                return (0 if "LEFT" in anchor else 1 if "RIGHT" in anchor else 0.5,
                        0 if "TOP" in anchor else 1 if "BOTTOM" in anchor else 0.5)
            relative_horizontal, relative_vertical = factor(relative_anchor)
            horizontal, vertical = factor(anchor)
            if widget["kind"] == "EditBox":
                opposite_point = widget["points"][1]
                width = parent_width - offset_x + opposite_point[3]
                height = parent_height + offset_y - opposite_point[4]
            result = (parent_x + parent_width * relative_horizontal + offset_x - width * horizontal,
                      parent_y + parent_height * relative_vertical - offset_y - height * vertical, width, height)
        positions[identifier] = result
        return result

    image = Image.new("RGB", (1440, 900), (29, 37, 42))
    draw = ImageDraw.Draw(image)
    font_path = Path("C:/Windows/Fonts/georgia.ttf")
    def color(channels, default):
        return tuple(round(channel * 255) for channel in channels[:3]) if channels else default

    for widget in scene:
        x, y, width, height = rectangle(widget)
        if widget.get("backgroundColor"):
            background = color(widget["backgroundColor"], (30, 40, 50))
            backdrop = widget.get("backdrop", {})
            if "UI-Background-Marble" in backdrop.get("bgFile", ""):
                background = tuple(round(channel * .23) for channel in background)
            border = color(widget.get("borderColor"), (60, 70, 80))
            if backdrop and not backdrop.get("edgeFile"):
                border = None
            if len(widget.get("borderColor", [])) == 4 and widget["borderColor"][3] == 0:
                border = (105, 88, 59)
            draw.rectangle((x, y, x + width, y + height), fill=background, outline=border)
        if widget.get("template") == "BasicFrameTemplate":
            draw.rectangle((x, y, x + width, y + 24), fill=(48, 39, 27), outline=(130, 115, 80))
        if widget["kind"] == "StatusBar":
            minimum, maximum = widget.get("minimum", 0), widget.get("maximum", 1)
            progress = max(0, min(1, (widget.get("value", 0) - minimum) / (maximum - minimum)))
            if progress > 0:
                draw.rectangle((x + 2, y + 2, x + 2 + (width - 4) * progress, y + height - 2), fill=color(widget.get("statusBarColor"), (255, 184, 31)))
        if widget.get("checked"):
            draw.line((x + 5, y + 13, x + 11, y + 19, x + 22, y + 6), fill=(255, 209, 0), width=3)
        if widget["kind"] == "Line":
            start_parent, start_x, start_y = widget["startPoint"]
            end_parent, end_x, end_y = widget["endPoint"]
            origin_x, origin_y, _, _ = rectangle(widgets[start_parent])
            draw.line((origin_x + start_x, origin_y - start_y, origin_x + end_x, origin_y - end_y), fill=color(widget.get("lineColor"), (255, 209, 0)), width=widget["thickness"])
        if widget["kind"] == "Texture" and widget.get("atlas", "").startswith("Professions-Icon-Skill-"):
            atlas = widget["atlas"]
            levels = 3 if atlas.endswith("High") else 2 if atlas.endswith("Medium") else 1
            for level in range(levels):
                top = y + 2 + level * 4
                draw.line((x + 3, top + 4, x + width / 2, top, x + width - 3, top + 4), fill=(218, 197, 147), width=2)
        elif widget["kind"] == "Texture" and "MiniMap-QuestArrow" in str(widget.get("texture", "")):
            texture_path = PROJECT / "reference/arrows/MiniMap-QuestArrow.PNG"
            if texture_path.exists():
                texture = Image.open(texture_path).convert("RGBA")
                left, right, top, bottom = widget.get("textureCoordinates", [0, 1, 0, 1])
                texture = texture.crop((left * texture.width, top * texture.height, right * texture.width, bottom * texture.height))
                texture = texture.rotate(math.degrees(widget.get("rotation", 0)))
                texture = texture.resize((round(width), round(height)), Image.Resampling.LANCZOS)
                image.paste(texture, (round(x), round(y)), texture)
            else:
                draw.polygon((x + width / 2, y + height, x, y + height / 3, x + width, y + height / 3), fill=(196, 179, 132))
        elif widget["kind"] == "Texture" and width:
            draw.rounded_rectangle((x, y, x + width, y + height), radius=4, fill=(82, 106, 116), outline=(137, 157, 153))
            draw.line((x + width * .2, y + height * .7, x + width * .7, y + height * .2), fill=(193, 211, 199), width=3)
        if not widget.get("text"):
            continue
        text = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", str(widget["text"]))
        # The game uses its own coin textures; preserve their inline space in this approximation.
        coin_matches = list(re.finditer(r"\|T[^|]*UI-(Gold|Silver|Copper)Icon[^|]*\|t", text))
        coin_metals = [match.group(1) for match in coin_matches]
        text = re.sub(r"\|T[^|]*\|t", "● ", text)
        font = ImageFont.truetype(str(font_path), int(widget.get("fontSize", 13)))
        lines = []
        for paragraph in text.splitlines():
            line = ""
            for word in paragraph.split(" "):
                candidate = (line + " " + word).strip()
                if draw.textlength(candidate, font=font) > width and line and widget.get("wrap") is not False:
                    lines.append(line); line = word
                else:
                    line = candidate
            lines.append(line)
        for line_number, line in enumerate(lines):
            if widget.get("wrap") is False:
                while line and draw.textlength(line, font=font) > width:
                    line = line[:-1]
            remaining_width = max(0, width - draw.textlength(line, font=font))
            text_x = x + (remaining_width / 2 if widget.get("justify") == "CENTER" else remaining_width if widget.get("justify") == "RIGHT" else 0)
            shade = color(widget.get("textColor"), (232, 235, 230))
            if widget.get("shadowColor"):
                shadow_x, shadow_y = widget.get("shadowOffset", [1, -1])
                draw.text((text_x + shadow_x, y + line_number * (font.size + 2) - 2 - shadow_y), line, font=font, fill=color(widget["shadowColor"], (0, 0, 0)))
            draw.text((text_x, y + line_number * (font.size + 2) - 2), line, font=font, fill=shade)
            for coin_match in re.finditer("●", line):
                if not coin_metals:
                    break
                metal = coin_metals.pop(0)
                coin_x = text_x + draw.textlength(line[:coin_match.start()], font=font)
                coin_y = y + line_number * (font.size + 2) + 2
                coin_color = {"Gold": (235, 188, 54), "Silver": (192, 203, 212), "Copper": (195, 117, 64)}[metal]
                draw.ellipse((coin_x, coin_y, coin_x + 10, coin_y + 10), fill=coin_color, outline=(70, 49, 29))
    draw.text((160, 835), "LAYOUT PREVIEW · Native artwork approximated · Placeholder item icons · Simulated inventory and prices", font=ImageFont.truetype(str(font_path), 12), fill=(170, 185, 190))
    image.save(destination)


def load_addon(replace_native=None, saved_variables=None):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.execute((PROJECT / "validation/client.lua").read_text(encoding="utf-8"))
    runtime.execute("ProfessionatorAddon = {}")
    if saved_variables is not None:
        runtime.globals().ProfessionatorDB = runtime.table_from(saved_variables, recursive=True)
    elif replace_native is not None:
        runtime.globals().ProfessionatorDB = runtime.table_from({"replaceNative": replace_native})
    addon = runtime.globals().ProfessionatorAddon
    manifest = (PROJECT / "Professionator/Professionator.toc").read_text(encoding="utf-8")
    for filename in manifest.splitlines():
        if filename.endswith(".lua"):
            source = (PROJECT / "Professionator" / filename).read_text(encoding="utf-8")
            runtime.execute("return function(...)\n" + source + "\nend")("Professionator", addon)
    return runtime


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true", help="Run the workflow and write the report and previews.")
    parser.add_argument("--output-directory", type=Path, default=PROJECT / "artifacts")
    parser.add_argument("--auctionator-directory", type=Path, help="Also replay the installed Auctionator API and database code (read-only).")
    parser.add_argument("--auctionator-settings", type=Path, help="Auctionator.lua settings to read for the real database replay.")
    arguments = parser.parse_args()
    if not arguments.run:
        parser.print_help()
        return 0
    if bool(arguments.auctionator_directory) != bool(arguments.auctionator_settings):
        parser.error("Provide both --auctionator-directory and --auctionator-settings for the read-only replay.")
    arguments.output_directory.mkdir(parents=True, exist_ok=True)
    runtime = load_addon()
    preferences_runtime = load_addon(replace_native=False)
    camping_runtime = load_addon()
    recipe_ranking_runtime = load_addon()
    recipe_controls_runtime = load_addon(saved_variables={"replaceNative": True})
    background_runtime = load_addon()
    success = True
    error = None
    try:
        runtime.execute((PROJECT / "validation/workflow.lua").read_text(encoding="utf-8"))
        runtime.execute((PROJECT / "validation/craft_lifecycle.lua").read_text(encoding="utf-8"))
        runtime.execute((PROJECT / "validation/batch_timing.lua").read_text(encoding="utf-8"))
        runtime.execute((PROJECT / "validation/craft_diagnostics.lua").read_text(encoding="utf-8"))
        preferences_runtime.execute((PROJECT / "validation/preferences.lua").read_text(encoding="utf-8"))
        camping_runtime.execute((PROJECT / "validation/camping.lua").read_text(encoding="utf-8"))
        recipe_ranking_runtime.execute((PROJECT / "validation/recipe_ranking.lua").read_text(encoding="utf-8"))
        recipe_controls_runtime.execute((PROJECT / "validation/recipe_controls.lua").read_text(encoding="utf-8"))
        quantity_reload_runtime = load_addon(saved_variables=plain(recipe_controls_runtime.globals().ProfessionatorDB))
        quantity_reload_runtime.execute("""
            Harness.Event("ADDON_LOADED", "Professionator")
            ProfessionatorAddon.Open(186); Harness.Advance(1)
            Harness.Check("Reload restores the unchecked quantity preference to state and UI", ProfessionatorAddon.state.multiplyByQuantity == false and not ProfessionatorAddon.UI.multiplyByQuantity:GetChecked())
        """)
        for check in plain(quantity_reload_runtime.globals().Harness.checks):
            runtime.globals().Harness.Check(check["name"], check["passed"], check["detail"])
        background_runtime.execute((PROJECT / "validation/background_crafting.lua").read_text(encoding="utf-8"))
        for open_from_menu in (False, True):
            first_open_runtime = load_addon()
            first_open_runtime.globals().Harness.openFromMenu = open_from_menu
            first_open_runtime.execute((PROJECT / "validation/first_open.lua").read_text(encoding="utf-8"))
            for check in plain(first_open_runtime.globals().Harness.checks):
                runtime.globals().Harness.Check(check["name"], check["passed"], check["detail"])
        saved_variables = plain(runtime.globals().ProfessionatorDB)
        reload_runtime = load_addon(saved_variables=saved_variables)
        reload_runtime.execute("""
            local before = #ProfessionatorDB.craftDiagnostics.entries
            Harness.Event("ADDON_LOADED", "Professionator")
            Harness.Check("Reload preserves the previous craft comparison", #ProfessionatorDB.craftDiagnostics.entries == before + 1
                and ProfessionatorDB.craftDiagnostics.entries[before].kind == "saved")
            for index = 1, 170 do ProfessionatorAddon.Diagnostics.Record("bounded-capture", {index = index}) end
            Harness.Check("Craft diagnostics have a fixed retention limit", #ProfessionatorDB.craftDiagnostics.entries == 160)
        """)
        for check in plain(reload_runtime.globals().Harness.checks):
            runtime.globals().Harness.Check(check["name"], check["passed"], check["detail"])
        if arguments.auctionator_directory and arguments.auctionator_settings:
            runtime.globals().AuctionatorDirectory = arguments.auctionator_directory.as_posix()
            runtime.globals().AuctionatorSettingsPath = arguments.auctionator_settings.as_posix()
            runtime.execute((PROJECT / "validation/auctionator.lua").read_text(encoding="utf-8"))
    except Exception as exception:
        success = False
        error = str(exception)
    harness = runtime.globals().Harness
    report = plain(harness.result) if success else {"checks": plain(harness.checks), "error": error}
    # Include partial workflow results on failure so the report cannot say every
    # check passed while omitting the session that actually failed.
    for session in (preferences_runtime, camping_runtime, recipe_ranking_runtime, recipe_controls_runtime, background_runtime):
        report["checks"].extend(plain(session.globals().Harness.checks))
    report["timestamp"] = datetime.now(timezone.utc).isoformat()
    report["passed"] = success
    report["sourceHashes"] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in (PROJECT / "Professionator").iterdir() if path.is_file()}
    (arguments.output_directory / "integration-report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    for session in (harness, preferences_runtime.globals().Harness, camping_runtime.globals().Harness, recipe_ranking_runtime.globals().Harness, recipe_controls_runtime.globals().Harness):
        for name, scene in session.snapshots.items():
            converted = plain(scene)
            (arguments.output_directory / f"{name}.json").write_text(json.dumps(converted, indent=2, ensure_ascii=False), encoding="utf-8")
            render_scene(converted, arguments.output_directory / f"{name}.png")
    passed = sum(check["passed"] for check in report["checks"])
    print(f"{passed}/{len(report['checks'])} workflow checks passed. Report: {arguments.output_directory / 'integration-report.json'}")
    if error:
        print(error)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())

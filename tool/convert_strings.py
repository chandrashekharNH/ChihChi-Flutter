#!/usr/bin/env python3
"""Converts the iOS app's AppText.xcstrings into assets/i18n/<code>.json (key -> text) and copies
the letter packs. Run from the Flutter project root:
    python3 tool/convert_strings.py ../ChihChi
"""
import json, os, shutil, sys

ios = sys.argv[1] if len(sys.argv) > 1 else "../ChihChi"
catalog = json.load(open(os.path.join(ios, "ChihChi/Core/Localization/AppText.xcstrings"), encoding="utf-8"))
tables = {}
for key, entry in catalog["strings"].items():
    for code, loc in entry.get("localizations", {}).items():
        unit = loc.get("stringUnit")
        if unit and unit.get("value"):
            tables.setdefault(code, {})[key] = unit["value"]
os.makedirs("assets/i18n", exist_ok=True)
for code, table in tables.items():
    with open("assets/i18n/%s.json" % code, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(table.items())), f, ensure_ascii=False, indent=0)
packs = os.path.join(ios, "ChihChi/Data/LanguagePacks")
os.makedirs("assets/language_packs", exist_ok=True)
for name in os.listdir(packs):
    shutil.copy(os.path.join(packs, name), "assets/language_packs/" + name)
print("languages:", len(tables), "keys:", len(catalog["strings"]), "packs:", len(os.listdir(packs)))

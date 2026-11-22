"""Builds Ashen Build's game-data JSON from the downloaded sources.

Usage (from AshenBuild/GameData):  python3 -I ../../scripts/build_data.py <sources-dir> .

<sources-dir> holds: data.json and calc.js from heyobi/ds3-frame-dps (docs/),
armor_3dots.json from 3dots/ds3optimizer, and wiki_*.txt extracts from the
Fextralife wiki (shields, catalysts, weights, spells). Sources are not committed.
"""
import json, re, sys, os
SRC, OUT = sys.argv[1], sys.argv[2]
p = lambda f: os.path.join(SRC, f)
def key(n): return re.sub(r"[^a-z0-9]", "", n.lower())
def slug(n): return re.sub(r"_+", "_", re.sub(r"[^a-z0-9]+", "_", n.lower())).strip("_")

data = json.load(open(p("data.json")))
weights = {key(l.split("|")[0]): float(l.split("|")[1]) for l in open(p("wiki_weights.txt")) if l.strip()}
wiki_names = {key(l.split("|")[0]): l.split("|")[0] for l in open(p("wiki_weights.txt")) if l.strip()}

# ---- melee weapons (heyobi regulation 1.35) ----
INF = {"-": "Normal"}
melee = {}
missing_w = []
for w in data["weapons"]:
    k = key(w["n"])
    name = wiki_names.get(k, w["n"])
    e = melee.setdefault(k, {"id": slug(name), "name": name, "kind": "melee", "category": w["c"].replace(" (Paired)", "").replace(" (Unique)", ""),
                             "paired": "(Paired)" in w["c"], "weight": weights.get(k, 1.0), "variants": []})
    if e["weight"] is None and w["n"] not in missing_w: missing_w.append(w["n"])
    e["variants"].append({"infusion": INF.get(w["i"], w["i"]), "req": w["req"], "sat": w["sat"],
                          "lv": [[round(x, 3) for x in L] for L in w["lv"]], "nb": bool(w.get("nb"))})
for e in melee.values():
    e["maxUpgrade"] = len(e["variants"][0]["lv"]) - 1
print("melee", len(melee), "missing weights:", missing_w)

# ---- catalysts (heyobi cats) ----
cat_weight = {key(l.split("|")[0]): float(l.split("|")[1]) for l in open(p("wiki_catalysts.txt")) if l.strip()}
def cat_category(n):
    if "Chime" in n or "Bellvine" in n: return "Sacred Chime"
    if "Talisman" in n: return "Talisman"
    if "Flame" in n: return "Pyromancy Flame"
    if "Spear" in n: return "Spear"
    return "Staff"
cats = []
for c in data["cats"]:
    info = {"schools": c["school"], "curves": c["g"], "spellBuff": c["cl"]}
    k = key(c["n"])
    if k in melee:
        melee[k]["catalyst"] = info
        continue
    cats.append({"id": slug(c["n"]), "name": c["n"], "kind": "catalyst", "category": cat_category(c["n"]),
                 "weight": cat_weight.get(k, 0.5), "maxUpgrade": c["up"], "req": [c["req"][0], 0, c["req"][1], c["req"][2]],
                 "catalyst": info})
print("catalysts", len(cats), [c["name"] for c in cats if key(c["name"]) not in cat_weight])

# ---- shields and ranged (wiki) ----
others = []
for l in open(p("wiki_shields.txt")):
    if not l.strip(): continue
    c, n, wt, s, d, i, f, ab, stab, atk = [x.strip() for x in l.split("|")]
    kind = {"Bow": "bow", "Greatbow": "greatbow", "Crossbow": "crossbow"}.get(c, "shield")
    o = {"id": slug(n), "name": n, "kind": kind, "category": c, "weight": float(wt), "maxUpgrade": 10,
         "req": [int(s), int(d), int(i), int(f)], "baseAttack": float(atk)}
    if kind == "shield": o.update(absorption=float(ab), stability=float(stab))
    others.append(o)

weapons = sorted(melee.values(), key=lambda e: e["name"]) + sorted(cats, key=lambda e: e["name"]) + sorted(others, key=lambda e: e["name"])
ids = [w["id"] for w in weapons]; dup = {i for i in ids if ids.count(i) > 1}
assert not dup, dup
json.dump(weapons, open(os.path.join(OUT, "Weapons.json"), "w"), separators=(",", ":"))
json.dump({k: [round(x, 3) for x in v] for k, v in data["sats"].items()}, open(os.path.join(OUT, "Curves.json"), "w"), separators=(",", ":"))
print("weapons total", len(weapons))

# ---- armor (3dots/ds3optimizer) ----
arm = json.load(open(p("armor_3dots.json")))
SLOT = {"Head": "head", "Chest": "chest", "Arms": "hands", "Legs": "legs"}
armor, seen = [], set()
for s, slot in SLOT.items():
    for a in arm[s]:
        if a["Name"] == "None": continue
        i = slug(a["Name"])
        if i in seen: i = f"{i}_{slot}"
        seen.add(i)
        armor.append({"id": i, "name": a["Name"], "slot": slot, "weight": a["Weight"], "poise": a["Poise"],
                      "physicalDefense": {"standard": a["Physical"], "strike": a["Strike"], "slash": a["Slash"], "thrust": a["Thrust"]},
                      "elementalDefense": {"magic": a["Magic"], "fire": a["Fire"], "lightning": a["Lightning"], "dark": a["Dark"]},
                      "resistances": {"bleed": a["Bleed"], "poison": a["Poison"], "frost": a["Frost"], "curse": a["Curse"]}})
json.dump(armor, open(os.path.join(OUT, "Armor.json"), "w"), separators=(",", ":"))
print("armor", len(armor))

# ---- spells and buffs ----
BUFF = {"Magic Weapon": ("magic", 75), "Great Magic Weapon": ("magic", 85), "Crystal Magic Weapon": ("magic", 95),
        "Lightning Blade": ("lightning", 95), "Darkmoon Blade": ("magic", 95), "Dark Blade": ("dark", 85),
        "Carthus Flame Arc": ("fire", 80)}
spells = []
for l in open(p("wiki_spells.txt")):
    if not l.strip(): continue
    sc, n, fp, sl, i, f, t, el = [x.strip() for x in l.split("|")]
    s = {"id": slug(n), "name": n, "school": sc.lower(), "fp": int(fp), "slots": int(sl), "int": int(i), "fth": int(f),
         "type": t, "element": el}
    if n in BUFF: s["buff"] = {"element": BUFF[n][0], "percentOfSpellBuff": BUFF[n][1]}
    if n == "Blessed Weapon": s["buff"] = {"element": "physical", "physicalMultiplier": 1.075}
    spells.append(s)
for n, el, add in [("Charcoal Pine Resin", "fire", 85), ("Gold Pine Resin", "lightning", 95),
                   ("Pale Pine Resin", "magic", 90), ("Human Pine Resin", "dark", 95)]:
    spells.append({"id": slug(n), "name": n, "school": "item", "fp": 0, "slots": 0, "int": 0, "fth": 0,
                   "type": "weapon-buff", "element": el, "buff": {"element": el, "flat": add}})
json.dump(spells, open(os.path.join(OUT, "Spells.json"), "w"), indent=1)
print("spells", len(spells))

# ---- starting classes ----
wid = {key(w["name"]): w["id"] for w in weapons}; aid = {(a["slot"], key(a["name"])): a["id"] for a in armor}
sid = {key(s["name"]): s["id"] for s in spells}
G = {
 "knight": (["Longsword"], ["Knight Shield"], ["Knight Helm", "Knight Armor", "Knight Gauntlets", "Knight Leggings"], [], []),
 "mercenary": (["Sellsword Twinblades"], ["Wooden Shield"], ["Sellsword Helm", "Sellsword Armor", None, "Sellsword Trousers"], [], []),
 "warrior": (["Battle Axe"], ["Round Shield"], ["Northern Helm", "Northern Armor", "Northern Gloves", "Northern Trousers"], [], []),
 "herald": (["Spear"], ["Kite Shield", "Talisman"], ["Herald Helm", "Herald Armor", "Herald Gloves", "Herald Trousers"], ["Heal Aid"], []),
 "thief": (["Bandit's Knife", "Short Bow"], ["Iron Round Shield"], ["Thief Mask", "Deserter Armor", None, "Deserter Trousers"], [], []),
 "assassin": (["Estoc"], ["Target Shield", "Sorcerer's Staff"], ["Assassin Hood", "Assassin Armor", "Assassin Gloves", "Assassin Trousers"], ["Spook"], []),
 "sorcerer": (["Mail Breaker"], ["Leather Shield", "Sorcerer's Staff"], ["Sorcerer Hood", "Sorcerer Robe", "Sorcerer Gloves", "Sorcerer Trousers"], ["Soul Arrow", "Heavy Soul Arrow"], ["young_dragon_ring"]),
 "pyromancer": (["Hand Axe"], ["Caduceus Round Shield", "Pyromancy Flame"], ["Pyromancer Crown", "Pyromancer Garb", "Pyromancer Wrap", "Pyromancer Trousers"], ["Fireball"], ["great_swamp_ring"]),
 "cleric": (["Mace"], ["Blue Wooden Shield", "Cleric's Sacred Chime"], [None, "Cleric Blue Robe", "Cleric Gloves", "Cleric Trousers"], ["Heal", "Force"], []),
 "deprived": (["Club"], ["Plank Shield"], [None, None, None, "Loincloth"], [], []),
}
cls = json.load(open(os.path.join(OUT, "StartingClasses.json")))
problems = []
for c in cls:
    r, lft, armn, sp, rings = G[c["id"]]
    look = lambda n: wid.get(key(n)) or problems.append(("weapon", c["id"], n))
    c["rightHand"] = [look(n) for n in r]; c["leftHand"] = [look(n) for n in lft]
    arm_ids = []
    for slot, n in zip(["head", "chest", "hands", "legs"], armn):
        if n is None: continue
        a = aid.get((slot, key(n)))
        if not a:
            a = next((v for (s2, k2), v in aid.items() if k2 == key(n)), None)
        arm_ids.append(a) if a else problems.append(("armor", c["id"], n))
    c["startingArmorIDs"] = arm_ids
    c["spellIDs"] = [sid.get(key(n)) or problems.append(("spell", c["id"], n)) for n in sp]
    c["ringIDs"] = rings
    c.pop("startingWeaponIDs", None)
json.dump(cls, open(os.path.join(OUT, "StartingClasses.json"), "w"), indent=1)
print("class gear problems:", problems)

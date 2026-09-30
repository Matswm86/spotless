class_name Levels
extends RefCounted

## Level data: which object, which room, which tools in which order, and which kind of dirt.

## How each material reacts once clean: roughness when clean, roughness before polish, metallic.
const ROLES := {
	"fabric": [0.85, 0.95, 0.0],
	"wood": [0.45, 0.8, 0.0],
	"metal": [0.25, 0.65, 0.85],
	"metaldark": [0.35, 0.7, 0.3],
	"appliance": [0.22, 0.65, 0.1],
	"plant": [0.6, 0.8, 0.0],
	"chrome": [0.08, 0.55, 1.0],
	"ceramic": [0.1, 0.6, 0.0],
	"plastic": [0.3, 0.75, 0.0],
	"carpaint": [0.18, 0.7, 0.25],
	"glass": [0.05, 0.5, 0.0],
	"rubber": [0.75, 0.9, 0.0],
	"stone": [0.2, 0.7, 0.0],
	"sign": [0.3, 0.7, 0.2],
	"signpaint": [0.3, 0.7, 0.3],
	"boxpaint": [0.25, 0.7, 0.3],
	"kettlepaint": [0.15, 0.6, 0.2],
	"framepaint": [0.2, 0.65, 0.3],
}

const DIRT := {
	"mud": [Color(0.42, 0.31, 0.19), Color(0.25, 0.18, 0.1)],
	"dust": [Color(0.66, 0.63, 0.58), Color(0.5, 0.48, 0.44)],
	"soot": [Color(0.24, 0.22, 0.2), Color(0.12, 0.11, 0.1)],
	"sand": [Color(0.72, 0.6, 0.42), Color(0.55, 0.44, 0.3)],
}

## Grime colours plus its roughness.
const GRIME := {
	"moss": [Color(0.47, 0.56, 0.16), Color(0.22, 0.31, 0.1), 0.9],
	"rust": [Color(0.66, 0.34, 0.12), Color(0.36, 0.17, 0.07), 0.95],
	"grease": [Color(0.42, 0.31, 0.13), Color(0.2, 0.14, 0.07), 0.45],
	"stain": [Color(0.66, 0.53, 0.27), Color(0.42, 0.32, 0.16), 0.8],
	"limescale": [Color(0.86, 0.83, 0.7), Color(0.66, 0.62, 0.48), 0.9],
	"tarnish": [Color(0.3, 0.25, 0.14), Color(0.14, 0.12, 0.08), 0.85],
	"mould": [Color(0.3, 0.33, 0.25), Color(0.12, 0.14, 0.1), 0.9],
}

## Stage kinds: display name, CleanMask op, tool, brush radius (fraction of the object), strength.
const STAGES := {
	"trash": {"name": "Tidy up", "op": -1, "tool": "hand", "hint": "Tap the rubbish to throw it away"},
	"spray": {"name": "Wash", "op": CleanMask.Op.DIRT, "tool": "washer", "radius": 0.075, "power": 0.55, "hint": "Drag to blast the dirt away"},
	"vacuum": {"name": "Vacuum", "op": CleanMask.Op.DIRT, "tool": "vacuum", "radius": 0.07, "power": 0.5, "hint": "Drag to suck up the dust"},
	"foam": {"name": "Soap", "op": CleanMask.Op.FOAM, "tool": "foamer", "radius": 0.085, "power": 0.6, "hint": "Cover the grime in foam"},
	"rinse": {"name": "Rinse", "op": CleanMask.Op.RINSE, "tool": "washer", "radius": 0.08, "power": 0.5, "hint": "Rinse the foam off"},
	"scrub": {"name": "Scrub", "op": CleanMask.Op.GRIME, "tool": "sponge", "radius": 0.065, "power": 0.4, "hint": "Scrub the stains away"},
	"grind": {"name": "Sand", "op": CleanMask.Op.GRIME, "tool": "grinder", "radius": 0.06, "power": 0.45, "hint": "Grind off the rust"},
	"paint": {"name": "Paint", "op": CleanMask.Op.PAINT, "tool": "painter", "radius": 0.08, "power": 0.5, "hint": "Pick a colour and spray"},
	"polish": {"name": "Polish", "op": CleanMask.Op.POLISH, "tool": "polisher", "radius": 0.08, "power": 0.55, "hint": "Polish until it shines"},
}

const LIST := [
	{"name": "Bathroom sink", "obj": "furniture/bathroomSink", "room": "bathroom", "stages": ["spray", "scrub", "polish"],
		"dirt": "mud", "grime": "moss", "grime_roles": ["ceramic", "appliance"], "rot": 0.0, "size": 1.3},
	{"name": "Golden cup", "obj": "trophy", "room": "shelf", "stages": ["foam", "rinse", "polish"],
		"dirt": "dust", "grime": "tarnish", "grime_roles": ["metal"], "size": 1.3, "stand": true},
	{"name": "Armchair", "obj": "furniture/loungeChair", "room": "living", "stages": ["trash", "vacuum", "scrub", "paint"],
		"dirt": "dust", "grime": "stain", "grime_roles": ["fabric"], "paint_roles": ["fabric"], "rot": 0.0, "size": 1.8,
		"paints": [Color(0.25, 0.55, 0.75), Color(0.95, 0.75, 0.3), Color(0.35, 0.65, 0.45), Color(0.95, 0.5, 0.55)]},
	{"name": "Road sign", "obj": "sign", "room": "road", "stages": ["spray", "grind", "paint", "polish"],
		"dirt": "mud", "grime": "rust", "grime_roles": ["metal", "signpaint", "sign"], "paint_roles": ["signpaint"], "size": 2.4,
		"paints": [Color(0.88, 0.12, 0.1), Color(0.1, 0.35, 0.8), Color(0.98, 0.7, 0.05), Color(0.1, 0.6, 0.3)]},
	{"name": "Desk fan", "obj": "fan", "room": "living", "stages": ["vacuum", "scrub", "paint", "polish"],
		"dirt": "dust", "grime": "grease", "grime_roles": ["plastic", "chrome"], "paint_roles": ["plastic"], "size": 1.4, "stand": true,
		"paints": [Color(0.2, 0.62, 0.6), Color(0.95, 0.85, 0.7), Color(0.9, 0.35, 0.3), Color(0.35, 0.5, 0.8)]},
	{"name": "Toilet", "obj": "furniture/toilet", "room": "bathroom", "stages": ["trash", "spray", "scrub", "polish"],
		"dirt": "mud", "grime": "limescale", "grime_roles": ["ceramic", "appliance"], "rot": 0.0, "size": 1.6},
	{"name": "Muddy car", "obj": "car/sedan", "room": "garage", "stages": ["spray", "foam", "rinse", "polish"],
		"dirt": "mud", "grime": "grease", "grime_roles": ["carpaint"], "rot": 60.0, "size": 2.6},
	{"name": "Fridge", "obj": "furniture/kitchenFridge", "room": "kitchen", "stages": ["scrub", "paint", "polish"],
		"dirt": "dust", "grime": "grease", "grime_roles": ["appliance", "metaldark", "ceramic", "glass"], "paint_roles": ["appliance"], "rot": 0.0, "size": 2.2,
		"paints": [Color(0.55, 0.8, 0.75), Color(0.97, 0.62, 0.5), Color(0.98, 0.9, 0.55), Color(0.62, 0.75, 0.92)]},
	{"name": "Mailbox", "obj": "mailbox", "room": "garden", "stages": ["spray", "grind", "paint", "polish"],
		"dirt": "mud", "grime": "rust", "grime_roles": ["boxpaint", "metal", "chrome"], "paint_roles": ["boxpaint"], "rot": -35.0, "size": 2.0,
		"paints": [Color(0.18, 0.4, 0.75), Color(0.9, 0.2, 0.18), Color(0.2, 0.55, 0.35), Color(0.95, 0.75, 0.2)]},
	{"name": "Bathtub", "obj": "furniture/bathtub", "room": "bathroom", "stages": ["trash", "spray", "foam", "rinse", "polish"],
		"dirt": "mud", "grime": "mould", "grime_roles": ["ceramic", "appliance", "metaldark"], "rot": 0.0, "size": 2.3},
	{"name": "Old kettle", "obj": "kettle", "room": "kitchen", "stages": ["foam", "rinse", "paint", "polish"],
		"dirt": "soot", "grime": "grease", "grime_roles": ["kettlepaint", "metal"], "paint_roles": ["kettlepaint"], "size": 1.3, "stand": true,
		"paints": [Color(0.9, 0.3, 0.25), Color(0.3, 0.7, 0.75), Color(0.97, 0.8, 0.3), Color(0.95, 0.95, 0.93)]},
	{"name": "Stove", "obj": "furniture/kitchenStove", "room": "kitchen", "stages": ["spray", "foam", "rinse", "polish"],
		"dirt": "soot", "grime": "grease", "grime_roles": ["appliance", "metaldark", "ceramic", "wood", "glass"], "rot": 0.0, "size": 1.8},
	{"name": "Sofa", "obj": "furniture/loungeSofa", "room": "living", "stages": ["trash", "vacuum", "foam", "rinse", "paint"],
		"dirt": "dust", "grime": "stain", "grime_roles": ["fabric"], "paint_roles": ["fabric"], "rot": 0.0, "size": 2.6,
		"paints": [Color(0.3, 0.45, 0.7), Color(0.85, 0.55, 0.35), Color(0.45, 0.62, 0.42), Color(0.9, 0.85, 0.75)]},
	{"name": "Kick scooter", "obj": "bike", "room": "garden", "stages": ["spray", "grind", "paint", "polish"],
		"dirt": "mud", "grime": "rust", "grime_roles": ["framepaint", "chrome"], "paint_roles": ["framepaint"], "rot": 0.0, "size": 2.0,
		"paints": [Color(0.25, 0.7, 0.85), Color(0.95, 0.4, 0.3), Color(0.98, 0.8, 0.2), Color(0.4, 0.8, 0.45)]},
	{"name": "Retro TV", "obj": "furniture/televisionVintage", "room": "living", "stages": ["vacuum", "scrub", "polish"],
		"dirt": "dust", "grime": "grease", "grime_roles": ["wood", "appliance", "metaldark", "glass"], "rot": 0.0, "size": 1.5, "stand": true},
	{"name": "Washing machine", "obj": "furniture/washer", "room": "bathroom", "stages": ["spray", "scrub", "polish"],
		"dirt": "dust", "grime": "limescale", "grime_roles": ["ceramic", "appliance", "metaldark", "glass"], "rot": 0.0, "size": 1.7},
	{"name": "Tractor", "obj": "car/tractor", "room": "garden", "stages": ["spray", "foam", "rinse", "polish"],
		"dirt": "mud", "grime": "grease", "grime_roles": ["carpaint"], "rot": 55.0, "size": 2.6},
]


static func count() -> int:
	return LIST.size()


## Levels past the end of the list repeat with fresh dirt patterns.
static func get_level(index: int) -> Dictionary:
	var d: Dictionary = LIST[index % LIST.size()].duplicate(true)
	d["round"] = index / LIST.size()
	return d

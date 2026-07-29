class_name Vitals
extends RefCounted
## Safety bands for the vitals, and the colours the terminal reads them out in.
##
## Two axes of danger, not one. A vital can be lethal by being too low as easily
## as too high, and the terminal should say which -- an instrument that only ever
## shows "bad" is not telling the player what to do about it.
##
##   purple  hypo deadly     |  blue  hypo tolerable
##   green   comfortable
##   yellow  hyper tolerable |  red   hyper deadly
##
## Every band carries a text label as well as a colour. Colour alone would put
## the most important readout in the game out of reach of a red-green colourblind
## player, and this is a game whose entire premise is reading your own biometrics.

enum Band {
	HYPO_DEADLY,
	HYPO_TOLERABLE,
	COMFORTABLE,
	HYPER_TOLERABLE,
	HYPER_DEADLY,
}

const BAND_COLOR := {
	Band.HYPO_DEADLY: Color("a855f7"),
	Band.HYPO_TOLERABLE: Color("38bdf8"),
	Band.COMFORTABLE: Color("4ade80"),
	Band.HYPER_TOLERABLE: Color("facc15"),
	Band.HYPER_DEADLY: Color("f87171"),
}

const BAND_LABEL := {
	Band.HYPO_DEADLY: "CRITICAL LOW",
	Band.HYPO_TOLERABLE: "LOW",
	Band.COMFORTABLE: "NOMINAL",
	Band.HYPER_TOLERABLE: "ELEVATED",
	Band.HYPER_DEADLY: "CRITICAL",
}

## Each entry is {"until": upper bound (exclusive), "band": Band}. The last entry
## must use INF so classification always terminates.

## The gauge ENDS at collapse. Running out of bar is death, with no leftover
## track past the fatal point -- a marker with visible room ahead of it promises
## time the player does not have, and dying with bar to spare reads as the game
## cheating rather than as the player misjudging.
##
## The deadly band still opens well before the end (39.5) so there is a warning
## zone to act inside.
const CORE_TEMP := {
	"min": 30.0,
	"max": 41.0,
	"bands": [
		{"until": 30.0, "band": Band.HYPO_DEADLY},
		{"until": 35.0, "band": Band.HYPO_TOLERABLE},
		{"until": 37.9, "band": Band.COMFORTABLE},
		{"until": 39.5, "band": Band.HYPER_TOLERABLE},
		{"until": INF, "band": Band.HYPER_DEADLY},
	],
}

## Brain activity, and the only vital that is lethal at both ends: 100% is every
## circuit firing at once, 0% is silence. Roughly 10-30% is where a person
## actually functions, which makes this the narrowest safe band in the game.
##
## Expressed in PERCENT, not the 0..1 the sim stores, because that is how it is
## read out. Anything handing a value to this spec must scale it first.
const NEURAL_STATIC := {
	"min": 0.0,
	"max": 100.0,
	"bands": [
		{"until": 5.0, "band": Band.HYPO_DEADLY},
		{"until": 10.0, "band": Band.HYPO_TOLERABLE},
		{"until": 30.0, "band": Band.COMFORTABLE},
		{"until": 70.0, "band": Band.HYPER_TOLERABLE},
		{"until": INF, "band": Band.HYPER_DEADLY},
	],
}

## Water is a reserve, so its danger is entirely on the low side. It uses the
## hypo colours rather than red for the same reason: running dry is a different
## problem from overheating, and should not look like one.
##
## Bounds come from Tuning so the gauge cannot silently disagree with the tank --
## they did once, and a full canteen read as LOW at half the bar.
const WATER := {
	"min": 0.0,
	"max": float(Tuning.WATER_CAPACITY),
	"bands": [
		{"until": 1.0, "band": Band.HYPO_DEADLY},
		{"until": 3.0, "band": Band.HYPO_TOLERABLE},
		{"until": INF, "band": Band.COMFORTABLE},
	],
}


static func classify(value: float, spec: Dictionary) -> Band:
	for entry: Dictionary in spec.bands:
		if value < entry.until:
			return entry.band
	return Band.HYPER_DEADLY


static func color_for(value: float, spec: Dictionary) -> Color:
	return BAND_COLOR[classify(value, spec)]


static func label_for(value: float, spec: Dictionary) -> String:
	return BAND_LABEL[classify(value, spec)]

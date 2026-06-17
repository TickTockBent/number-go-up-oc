class_name NumberFormatter
extends RefCounted

## Notation modes (GDD §3.2). The mode is a gameplay-affecting choice: it
## determines which funny numbers are visible and therefore which achievements
## are practically obtainable.

const SUFFIXES: Array = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

## Format a number for display according to the given mode.
static func format(value: float, mode: String) -> String:
	if is_inf(value):
		return "Infinity"
	if is_nan(value):
		return "NaN"
	var negative := value < 0.0
	var abs_value := absf(value)
	var result: String = _format_positive(abs_value, mode)
	if negative:
		result = "-" + result
	return result

static func _format_positive(value: float, mode: String) -> String:
	match mode:
		"normal":
			if value < 10000.0:
				return _with_commas(int(floor(value)))
			return _abbreviated(value)
		"extended":
			if value < 10000000.0:
				return _with_commas(int(floor(value)))
			return _abbreviated(value)
		"unhinged":
			# Full digits, no commas, ever. (Font scaling handled by display.)
			return str(int(floor(value)))
		"nerd":
			if value < 10000.0:
				return _with_commas(int(floor(value)))
			return _scientific(value)
		_:
			return _with_commas(int(floor(value)))

static func _with_commas(integer_value: int) -> String:
	var negative := integer_value < 0
	var digits := str(absi(integer_value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		if count == 3:
			out = "," + out
			count = 0
		out = digits[i] + out
		count += 1
	if negative:
		out = "-" + out
	return out

static func _abbreviated(value: float) -> String:
	# Find the suffix tier.
	var tier := 0
	var scaled := value
	while scaled >= 1000.0 and tier < SUFFIXES.size() - 1:
		scaled /= 1000.0
		tier += 1
	if tier == 0:
		return _with_commas(int(floor(value)))
	# 2 significant decimals, trimmed of trailing zeros.
	var text := "%.2f" % scaled
	if "." in text:
		text = text.rstrip("0").trim_suffix(".")
	return text + SUFFIXES[tier]

static func _scientific(value: float) -> String:
	if value == 0.0:
		return "0"
	var exponent := int(floor(log(value) / log(10.0)))
	var mantissa := value / pow(10.0, exponent)
	var text := "%.2f" % mantissa
	if "." in text:
		text = text.rstrip("0").trim_suffix(".")
	return "%se%d" % [text, exponent]

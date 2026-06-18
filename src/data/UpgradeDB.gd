class_name UpgradeDB
extends RefCounted

## Static registry of all upgrades. New tiers are pure data.
## Effect types:
##   click_flat   - +N base click power (additive per purchase)
##   rate_flat    - +N per second (additive per purchase)
##   click_mult   - xN click power (multiplicative per purchase)
##   prod_mult    - xN all production (multiplicative per purchase)
##   click_eq_rate- click grants 1s of production (flag, set once)
##   rate_pct_current - +N% of current number per second (per purchase)
##   nothing      - no mechanical effect (red button, mystery)

enum Tier { T1, T2, T3, T4, T5, T6 }

const TIERS: Dictionary = {
	Tier.T1: {"name": "The Basics", "unlock_total": 0.0},
	Tier.T2: {"name": "Getting Suspicious", "unlock_total": 500.0},
	Tier.T3: {"name": "Commitment Issues", "unlock_total": 50000.0},
	Tier.T4: {"name": "Past the Point of No Return", "unlock_total": 1000000.0},
	Tier.T5: {"name": "Why Are You Still Here", "unlock_total": 100000000.0},
	Tier.T6: {"name": "Endgame Content (There Is No Endgame)", "unlock_total": 10000000000.0},
}

const COST_GROWTH := 1.15

# id -> {name, tier, base_cost, effect_type, effect_value, desc}
const UPGRADES: Dictionary = {
	# Tier 1
	"click_1": {"name": "CLICK HARDER", "tier": Tier.T1, "base_cost": 10.0, "effect_type": "click_flat", "effect_value": 1.0, "desc": "Makes number go up when you click"},
	"auto_1": {"name": "Number Watcher", "tier": Tier.T1, "base_cost": 15.0, "effect_type": "rate_flat", "effect_value": 1.0, "desc": "Watches the number. It goes up."},
	"auto_2": {"name": "Number Encourager", "tier": Tier.T1, "base_cost": 100.0, "effect_type": "rate_flat", "effect_value": 5.0, "desc": "Tells the number it's doing great"},
	"auto_3": {"name": "Number Therapist", "tier": Tier.T1, "base_cost": 1100.0, "effect_type": "rate_flat", "effect_value": 47.0, "desc": "Helps number process its feelings about going up"},
	# Tier 2
	"auto_4": {"name": "Number Influencer", "tier": Tier.T2, "base_cost": 12000.0, "effect_type": "rate_flat", "effect_value": 260.0, "desc": "Posts motivational quotes about going up"},
	"red": {"name": "RED BUTTON", "tier": Tier.T2, "base_cost": 666.0, "effect_type": "nothing", "effect_value": 0.0, "desc": "Does nothing. It's red though."},
	"slow": {"name": "SLOWER BUTTON", "tier": Tier.T2, "base_cost": 5000.0, "effect_type": "prod_mult", "effect_value": 0.9, "desc": "-10% speed. Permanent. You're paying for this."},
	# Tier 3
	"auto_5": {"name": "Number Philosopher", "tier": Tier.T3, "base_cost": 130000.0, "effect_type": "rate_flat", "effect_value": 1400.0, "desc": "Ponders the nature of up"},
	"click_2": {"name": "Click Multiplier", "tier": Tier.T3, "base_cost": 75000.0, "effect_type": "click_mult", "effect_value": 1.5, "desc": "Your clicks now have opinions"},
	"green": {"name": "GREEN BUTTON", "tier": Tier.T3, "base_cost": 100000.0, "effect_type": "prod_mult", "effect_value": 1.001, "desc": "Finally, a button that helps. Barely."},
	# Tier 4
	"auto_6": {"name": "Number Deity", "tier": Tier.T4, "base_cost": 1400000.0, "effect_type": "rate_flat", "effect_value": 7800.0, "desc": "Ascended past caring. Numbers still go up."},
	"mystery": {"name": "???", "tier": Tier.T4, "base_cost": 9999999.0, "effect_type": "nothing", "effect_value": 0.0, "desc": "???"},
	"anti_slow": {"name": "FASTER BUTTON", "tier": Tier.T4, "base_cost": 2000000.0, "effect_type": "prod_mult", "effect_value": 1.05, "desc": "Partially undoes the slower button. Costs 400x more."},
	# Tier 5
	"auto_7": {"name": "The Concept of Up", "tier": Tier.T5, "base_cost": 20000000.0, "effect_type": "rate_flat", "effect_value": 44000.0, "desc": "It's not a person. It's an idea. The number respects it."},
	"auto_8": {"name": "Number's Number", "tier": Tier.T5, "base_cost": 200000000.0, "effect_type": "rate_flat", "effect_value": 250000.0, "desc": "Your number hired a number. That number goes up too."},
	"void": {"name": "THE VOID BUTTON", "tier": Tier.T5, "base_cost": 500000000.0, "effect_type": "prod_mult", "effect_value": 1.25, "desc": "Sacrifices half your number. The other half is grateful."},
	# Tier 6
	"auto_9": {"name": "Number Singularity", "tier": Tier.T6, "base_cost": 5000000000.0, "effect_type": "rate_flat", "effect_value": 1400000.0, "desc": "All numbers are one number now. It goes up."},
	"recursive": {"name": "The Game Itself", "tier": Tier.T6, "base_cost": 50000000000.0, "effect_type": "rate_pct_current", "effect_value": 0.0001, "desc": "The game is playing itself. You can leave. You won't."},
	"click_3": {"name": "Click of God", "tier": Tier.T6, "base_cost": 100000000000.0, "effect_type": "click_eq_rate", "effect_value": 0.0, "desc": "Each click adds your full per-second rate. Why click when it's automatic? Because you can."},
}

## Red button escalating purchase messages (1-indexed).
const RED_BUTTON_MESSAGES: Array = [
	"You bought the red button. It does nothing. You knew this.",
	"Another red button. Still nothing.",
	"You keep buying red buttons. This says something about you.",
	"The red buttons are starting to notice you back.",
	"The red buttons have formed a union. Their demand: more red buttons.",
	"At this point the red buttons are buying YOU.",
]
const RED_BUTTON_ROTATING: Array = [
	"Red.", "Button.", "Red button.", "You.", "Red you.", "Button red you button.",
]

## Slow button penalty-tier messages. Takes a 0-1 penalty fraction.
static func slow_message(penalty_fraction: float) -> String:
	var pct := int(round(penalty_fraction * 100.0))
	if penalty_fraction < 0.20:
		return "Everything is now %d%% slower. You paid for this." % pct
	elif penalty_fraction < 0.40:
		return "%d%% slower. The number is starting to resent you." % pct
	elif penalty_fraction < 0.60:
		return "%d%% speed penalty. The number can barely move. It stares at you." % pct
	elif penalty_fraction < 0.80:
		return "%d%% slower. The number has filed a restraining order." % pct
	elif penalty_fraction < 0.90:
		return "%d%% slower. The number is technically still moving. Technically." % pct
	else:
		return "The number has stopped believing in movement."

## Mystery button rotating flavor (7 entries, cycling).
const MYSTERY_MESSAGES: Array = [
	"???",
	"Still nothing. Different nothing.",
	"You bought the mystery again. The mystery deepens. Into more nothing.",
	"Nothing happened. But a different nothing than last time.",
"The mystery is wearing a different hat today. Same nothing underneath.",
	"Nothing. But you feel watched.",
	"Seven. Why is it always seven?",
]

static func red_button_message(count: int) -> String:
	if count <= 6:
		return RED_BUTTON_MESSAGES[count - 1]
	return RED_BUTTON_ROTATING[(count - 7) % RED_BUTTON_ROTATING.size()]

static func mystery_message(count: int) -> String:
	return MYSTERY_MESSAGES[(count - 1) % MYSTERY_MESSAGES.size()]

static func cost(id: String, owned: int) -> float:
	var def: Dictionary = UPGRADES[id]
	return def.base_cost * pow(COST_GROWTH, owned)

static func tier_unlocked(tier: int, total_earned: float) -> bool:
	return total_earned >= TIERS[tier].unlock_total

static func is_trap(id: String) -> bool:
	return id in ["red", "slow", "mystery", "void", "anti_slow"]

## Sales milestone upgrades (GDD §17). These appear only if the game has sold
## enough copies. The sales count is a stub — in production it would be read
## from Steam stats or a backend. For now always returns 0.
static func get_sales_count() -> int:
	return 0

static func has_milestone_upgrade() -> bool:
	return get_sales_count() >= 100000

static func get_milestone_description() -> String:
	if get_sales_count() >= 1000000:
		return "Seriously?"
	return "100,000 people bought this game. This upgrade is for them. It does nothing."

class_name AchievementsDB
extends RefCounted

## All 67 achievements (GDD §10). Pure data; evaluation lives in SteamIntegration.
## The number 67 is chosen deliberately. api_id is the Steam API achievement string.

enum Category { PROGRESSION, FUNNY, TRAP, PRESTIGE, META }

# id -> {api_id, name, desc, hidden, category}
const ACHIEVEMENTS: Array = [
	# --- §10.1 Progression (9) ---
	{"api_id": "NGU_FIRST_NUMBER", "name": "The First Number", "desc": "The number went up.", "hidden": false, "category": Category.PROGRESSION},
	{"api_id": "NGU_THREE_DIGITS", "name": "Three Digits", "desc": "The number has opinions now.", "hidden": false, "category": Category.PROGRESSION},
	{"api_id": "NGU_KILO", "name": "Kilo", "desc": "One thousand numbers, standing on each other's shoulders.", "hidden": false, "category": Category.PROGRESSION},
	{"api_id": "NGU_THE_K_WORD", "name": "The K Word", "desc": "'K' appeared after your number. You've made it.", "hidden": false, "category": Category.PROGRESSION},
	{"api_id": "NGU_SIX_FIGURES", "name": "Six Figures", "desc": "Your number makes more than most people.", "hidden": false, "category": Category.PROGRESSION},
	{"api_id": "NGU_MILLIONAIRE", "name": "Millionaire", "desc": "The number is a millionaire. It will not share.", "hidden": false, "category": Category.PROGRESSION},
	{"api_id": "NGU_EIGHT_DIGITS", "name": "8 Digits", "desc": "Welcome to 'Number Enjoyer' territory. All the jokes live here.", "hidden": false, "category": Category.PROGRESSION},
	{"api_id": "NGU_BILLIONAIRE", "name": "Billionaire", "desc": "The number could buy Twitter. It chooses not to.", "hidden": false, "category": Category.PROGRESSION},
	{"api_id": "NGU_TRILLIONAIRE", "name": "Trillionaire", "desc": "Congress would like a word.", "hidden": false, "category": Category.PROGRESSION},
	# --- §10.2 Funny Number (15) ---
	{"api_id": "NGU_NICE", "name": "Nice", "desc": "The number hit 69. Nice.", "hidden": true, "category": Category.FUNNY},
	{"api_id": "NGU_IF_YOU_KNOW", "name": "If You Know", "desc": "67.", "hidden": true, "category": Category.FUNNY},
	{"api_id": "NGU_BLAZE_IT", "name": "Blaze It", "desc": "The number is enlightened.", "hidden": true, "category": Category.FUNNY},
	{"api_id": "NGU_CALCULATOR_HUMOR", "name": "Calculator Humor", "desc": "The number said boobs.", "hidden": true, "category": Category.FUNNY},
	{"api_id": "NGU_ADV_CALCULATOR_HUMOR", "name": "Advanced Calculator Humor", "desc": "The number said boobies.", "hidden": true, "category": Category.FUNNY},
	{"api_id": "NGU_FLIP_YOUR_PHONE", "name": "Flip Your Phone", "desc": "₈₀₀₈₅₁₃€", "hidden": true, "category": Category.FUNNY},
	{"api_id": "NGU_NUMBER_OF_THE_BEAST", "name": "Number of the Beast", "desc": "The number went to a dark place.", "hidden": true, "category": Category.FUNNY},
	{"api_id": "NGU_JACKPOT", "name": "Jackpot", "desc": "777. The number got lucky.", "hidden": true, "category": Category.FUNNY},
	{"api_id": "NGU_OVER_9000", "name": "What Does the Scouter Say", "desc": "IT'S OVER 9000", "hidden": true, "category": Category.FUNNY},
	{"api_id": "NGU_LEET", "name": "Leet", "desc": "1337 h4x0r", "hidden": true, "category": Category.FUNNY},
	{"api_id": "NGU_THE_ANSWER", "name": "The Answer", "desc": "42. But what's the question?", "hidden": true, "category": Category.FUNNY},
	{"api_id": "NGU_2319", "name": "WE GOT A 2319", "desc": "Put it back where it came from or so help me.", "hidden": true, "category": Category.FUNNY},
	{"api_id": "NGU_THE_FUSION", "name": "The Fusion", "desc": "42069. Two memes fused into one. The number has peaked.", "hidden": true, "category": Category.FUNNY},
	{"api_id": "NGU_YEAH_BABY", "name": "Yeah Baby", "desc": "1738. That's all we can legally say.", "hidden": true, "category": Category.FUNNY},
	{"api_id": "NGU_NOT_FOUND", "name": "Not Found", "desc": "404. The number went looking for itself and couldn't find it.", "hidden": true, "category": Category.FUNNY},
	# --- §10.3 Trap Upgrade (12) ---
	{"api_id": "NGU_ITS_RED", "name": "It's Red", "desc": "Bought the red button. It does nothing.", "hidden": false, "category": Category.TRAP},
	{"api_id": "NGU_RED_COLLECTION", "name": "Red Collection", "desc": "You own 5 red buttons. They do 5 nothings.", "hidden": false, "category": Category.TRAP},
	{"api_id": "NGU_RED_ENTHUSIAST", "name": "Red Enthusiast", "desc": "10 red buttons. Your number is red now.", "hidden": false, "category": Category.TRAP},
	{"api_id": "NGU_RED_IDENTITY", "name": "Red Identity", "desc": "25 red buttons. You don't remember what green looked like.", "hidden": true, "category": Category.TRAP},
	{"api_id": "NGU_ALL_RED_EVERYTHING", "name": "All Red Everything", "desc": "50 red buttons. There is only red.", "hidden": true, "category": Category.TRAP},
	{"api_id": "NGU_SELF_SABOTAGE", "name": "Self-Sabotage", "desc": "Bought the slower button. On purpose. With your own numbers.", "hidden": false, "category": Category.TRAP},
	{"api_id": "NGU_TERMINAL_VELOCITY_REVERSE", "name": "Terminal Velocity (Reverse)", "desc": "Reached 50% speed penalty. The number respects your commitment to suffering.", "hidden": true, "category": Category.TRAP},
	{"api_id": "NGU_ASYMPTOTIC_AGONY", "name": "Asymptotic Agony", "desc": "Reached 90% speed penalty. The number is technically still moving.", "hidden": true, "category": Category.TRAP},
	{"api_id": "NGU_ZENOS_PARADOX", "name": "Zeno's Paradox", "desc": "Reached 99% speed penalty. The number will never reach its destination.", "hidden": true, "category": Category.TRAP},
	{"api_id": "NGU_MYSTERY_1", "name": "???", "desc": "???", "hidden": false, "category": Category.TRAP},
	{"api_id": "NGU_MYSTERY_7", "name": "???????", "desc": "???????", "hidden": true, "category": Category.TRAP},
	{"api_id": "NGU_THE_SECRET", "name": "The Secret No One Knows", "desc": "You'll never see this description because you'll never earn this achievement.", "hidden": true, "category": Category.TRAP},
	# --- §10.4 Prestige (8) ---
	{"api_id": "NGU_SAMSARA", "name": "Samsara", "desc": "The cycle begins.", "hidden": false, "category": Category.PRESTIGE},
	{"api_id": "NGU_PRESTIGE_5", "name": "Prestige 5", "desc": "Five times the number has died and been reborn.", "hidden": false, "category": Category.PRESTIGE},
	{"api_id": "NGU_DOUBLE_DIGITS", "name": "Double Digits", "desc": "10 prestige levels. The percentage grows.", "hidden": false, "category": Category.PRESTIGE},
	{"api_id": "NGU_META_RESET", "name": "The Meta-Reset", "desc": "Ascended for the first time. Your prestiges are gone.", "hidden": false, "category": Category.PRESTIGE},
	{"api_id": "NGU_ASCENSION_5", "name": "Ascension 5", "desc": "The number has forgotten what ground level looks like.", "hidden": false, "category": Category.PRESTIGE},
	{"api_id": "NGU_BEYOND_BEYOND", "name": "Beyond Beyond", "desc": "Transcended for the first time. Why.", "hidden": true, "category": Category.PRESTIGE},
	{"api_id": "NGU_FULL_SPECTRUM", "name": "Full Spectrum", "desc": "Transcended 12 times. The hue rotated all the way around. You're back to green.", "hidden": true, "category": Category.PRESTIGE},
	{"api_id": "NGU_PRESTIGE_60S", "name": "Prestige Within 60 Seconds", "desc": "Reached the prestige threshold in under 60 seconds.", "hidden": true, "category": Category.PRESTIGE},
	# --- §10.5 Meta / Behavioral (16) ---
	{"api_id": "NGU_FIRST_CLICK", "name": "First Click", "desc": "You clicked the number. This is the whole game.", "hidden": false, "category": Category.META},
	{"api_id": "NGU_THOUSAND_CLICKS", "name": "Thousand Clicks", "desc": "Your finger is tired. The number is not.", "hidden": false, "category": Category.META},
	{"api_id": "NGU_TEN_THOUSAND_CLICKS", "name": "Ten Thousand Clicks", "desc": "Have you considered an auto-clicker? We won't judge.", "hidden": true, "category": Category.META},
	{"api_id": "NGU_IDLE_HANDS", "name": "Idle Hands", "desc": "Let the game run for 10 minutes without clicking.", "hidden": true, "category": Category.META},
	{"api_id": "NGU_IDLE_MASTER", "name": "Idle Master", "desc": "Let the game run for 1 hour without clicking.", "hidden": true, "category": Category.META},
	{"api_id": "NGU_ALT_TABBED", "name": "Alt-Tabbed", "desc": "The game was in the background for 8 hours (the offline cap).", "hidden": true, "category": Category.META},
	{"api_id": "NGU_THE_LONG_STARE", "name": "The Long Stare", "desc": "Stared at the stats page for 2 minutes straight.", "hidden": true, "category": Category.META},
	{"api_id": "NGU_CARD_COLLECTOR", "name": "Card Collector", "desc": "Viewed the trading cards tab. You can't actually collect them here.", "hidden": false, "category": Category.META},
	{"api_id": "NGU_NOTATION_NERD", "name": "Notation Nerd", "desc": "Switched to Scientific notation. The number is now less fun.", "hidden": true, "category": Category.META},
	{"api_id": "NGU_UNHINGED_MODE", "name": "Unhinged Mode", "desc": "Enabled 'Unhinged' notation. The number will consume your screen.", "hidden": true, "category": Category.META},
	{"api_id": "NGU_HEAVY_WALLET", "name": "Heavy Wallet", "desc": "Purchased the Heavy Wallet DLC. All numbers are now 0.001% worse. Forever.", "hidden": false, "category": Category.META},
	{"api_id": "NGU_CAUGHT_RED_HANDED", "name": "Caught Red-Handed", "desc": "Nice try.", "hidden": true, "category": Category.META},
	{"api_id": "NGU_TWO_BUTTONS", "name": "Two Buttons", "desc": "Bought both the slower button and the faster button. The net effect is almost nothing.", "hidden": true, "category": Category.META},
	{"api_id": "NGU_SPEEDRUN", "name": "Speedrun", "desc": "Reached 1 million in under 5 minutes.", "hidden": true, "category": Category.META},
	{"api_id": "NGU_FULL_EXPERIENCE", "name": "The Full Experience", "desc": "Bought every unique upgrade type at least once.", "hidden": true, "category": Category.META},
	{"api_id": "NGU_67_ACHIEVEMENTS", "name": "67 Achievements", "desc": "You've unlocked all 67 achievements. That number was chosen on purpose.", "hidden": true, "category": Category.META},
]

## Total count (should be 67 per GDD — the number is deliberate).
static func count() -> int:
	return ACHIEVEMENTS.size()

## Returns the achievement dict by api_id, or null.
static func get_by_api_id(api_id: String) -> Variant:
	for entry in ACHIEVEMENTS:
		if entry.api_id == api_id:
			return entry
	return null

## All api_ids as an array.
static func all_api_ids() -> Array:
	var ids: Array = []
	for entry in ACHIEVEMENTS:
		ids.append(entry.api_id)
	return ids

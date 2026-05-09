extends Node

# Autoload: canonical dialogue trees for major NPCs.
# Each tree has named lines with branching choices; gating uses SaveFlags.
# Built in code via `_make_dialogue` helper for readability over .tres bloat.

var dialogues: Dictionary = {}  # StringName npc_id -> Dialogue

func _ready() -> void:
	_register_storyteller()
	_register_belitu()
	_register_sanctum_mother()
	_register_high_magus()
	_register_general_sin_mushezib()
	_register_black_sail_first()
	_register_sahirum_witch_burner()
	_register_oracle_attendant()
	_register_lucifer()

func get_dialogue(npc_id: StringName) -> Dialogue:
	return dialogues.get(npc_id)

# ----------------------------------------------------------------
# Helper: build a Dialogue out of compact line dicts
# ----------------------------------------------------------------
func _make_dialogue(npc_id: StringName, entry: StringName, lines: Array) -> Dialogue:
	var d := Dialogue.new()
	d.id = StringName("dialogue_" + String(npc_id))
	d.npc_id = npc_id
	d.entry_line_id = entry
	d.lines_data = lines
	dialogues[npc_id] = d
	return d

# ----------------------------------------------------------------
# THE STORYTELLER (Belitu / wandering / always at Ashurim)
# Knows your face. Knows your name. Knows the cycle.
# ----------------------------------------------------------------
func _register_storyteller() -> void:
	var lines := [
		{
			"id": "intro",
			"speaker": "The Storyteller",
			"text": "Sit. The kettle is on. Your shoulders are tighter than they were this morning. Tell me what you saw on the road.",
			"choices": [
				{"label": "Who are you?", "next_id": "who"},
				{"label": "Why do you know my face?", "next_id": "face", "require_run_flag": "prologue_complete"},
				{"label": "Tell me about Tiamat.", "next_id": "tiamat"},
				{"label": "Tell me about Lucifer.", "next_id": "lucifer", "require_run_flag": "tiamat_defeated"},
				{"label": "What should I do next?", "next_id": "advice"},
				{"label": "Goodbye.", "next_id": "", "ends_dialogue": true}
			]
		},
		{
			"id": "who",
			"speaker": "The Storyteller",
			"text": "Many names. Few mine. The first cycle named me Belit-Tseri. The second named me other things. I have been here since before the marsh dried. I will be here when the next thing dries.",
			"choices": [
				{"label": "What are you?", "next_id": "what"},
				{"label": "Back.", "next_id": "intro"}
			]
		},
		{
			"id": "what",
			"speaker": "The Storyteller",
			"text": "Marduk made the world from Tiamat's body. Apsu was killed by Ea before that. There were others. Some of us did not get a body assigned to us. We were noted, and we were forgiven, and we were sent down. I am older than the language we are speaking and the language was older than dirt.",
			"choices": [
				{"label": "Back.", "next_id": "intro"}
			]
		},
		{
			"id": "face",
			"speaker": "The Storyteller",
			"text": "I have seen six of you arrive in Ashurim. Eight, with the Paladins. Each of you walks like you are still bleeding, even when you are not. Each of you sets your shoulders the same way when you walk into the Singing Goat. I know your face because I have learned to read these shoulders.",
			"choices": [
				{"label": "Have you seen me before?", "next_id": "seen_before"},
				{"label": "Back.", "next_id": "intro"}
			]
		},
		{
			"id": "seen_before",
			"speaker": "The Storyteller",
			"text": "Many times. The cycle resets. You return. The first time you arrive you do not believe me. The third time you do not need me to tell you. We are somewhere in the middle.",
			"choices": [
				{"label": "Back.", "next_id": "intro"}
			]
		},
		{
			"id": "tiamat",
			"speaker": "The Storyteller",
			"text": "The mother of wrong things. Marduk killed her with seven storms and four winds. The seven storms are still around; you have probably caused two of them. Tiamat is in the Black Citadel waiting. She has been waiting longer than the city beneath her has existed.",
			"choices": [
				{"label": "Back.", "next_id": "intro"}
			]
		},
		{
			"id": "lucifer",
			"speaker": "The Storyteller",
			"text": "He will offer first. He always offers. The offer is good. The offer is reasonable. The offer is the trap. Refuse it. Refuse it once for me, and once for yourself, and once for the version of you that the Storyteller met in the third cycle, who said yes.",
			"choices": [
				{"label": "What did the third-cycle me say yes to?", "next_id": "third_cycle"},
				{"label": "Back.", "next_id": "intro"}
			]
		},
		{
			"id": "third_cycle",
			"speaker": "The Storyteller",
			"text": "Drink your tea. Some questions cost a cup at a time.",
			"choices": [
				{"label": "Back.", "next_id": "intro"}
			]
		},
		{
			"id": "advice",
			"speaker": "The Storyteller",
			"text": "Walk west. The Iron Crown is open to you now. There is a man called Iddinu who runs a caravan; do not let him price you for cloth, he overcharges. The General will want to use you. Let him, but only twice.",
			"choices": [
				{"label": "Back.", "next_id": "intro"}
			]
		}
	]
	_make_dialogue(&"storyteller", &"intro", lines)

# ----------------------------------------------------------------
# BELITU - Ashurim innkeeper of the Singing Goat
# ----------------------------------------------------------------
func _register_belitu() -> void:
	var lines := [
		{
			"id": "intro",
			"speaker": "Belitu",
			"text": "Welcome to the Singing Goat. Bed upstairs, drinks down here. Anything else, ask Ulima two doors over.",
			"choices": [
				{"label": "I'd like a room.", "next_id": "room"},
				{"label": "Have you seen the Storyteller?", "next_id": "storyteller"},
				{"label": "Have you lost a ledger?", "next_id": "ledger", "require_run_flag": "talked_to_belitu_about_ledger"},
				{"label": "Just looking.", "next_id": "", "ends_dialogue": true}
			]
		},
		{
			"id": "room",
			"speaker": "Belitu",
			"text": "Two coppers a night. Bath extra. The cat will pick which room you sleep in; I cannot control her, do not try.",
			"choices": [
				{"label": "Thanks.", "next_id": "", "ends_dialogue": true}
			]
		},
		{
			"id": "storyteller",
			"speaker": "Belitu",
			"text": "She is upstairs. She is always upstairs. Whether she will see you depends on her, not you. Knock. Wait. The kettle being on does not always mean you are invited.",
			"choices": [
				{"label": "Back.", "next_id": "intro"}
			]
		},
		{
			"id": "ledger",
			"speaker": "Belitu",
			"text": "Yes. A copper-clasped book. Brown leather. A customer took it. I know which one. I will not tell you. If you bring it back without asking who, I will count you a friend.",
			"choices": [
				{"label": "Back.", "next_id": "intro"}
			]
		}
	]
	_make_dialogue(&"belitu", &"intro", lines)

# ----------------------------------------------------------------
# SANCTUM-MOTHER - druid hold matriarch
# ----------------------------------------------------------------
func _register_sanctum_mother() -> void:
	var lines := [
		{
			"id": "intro",
			"speaker": "The Sanctum-Mother",
			"text": "You smell of the Wound. Sit. There is mint tea, or there is silence; pick.",
			"choices": [
				{"label": "Tell me about the Wound.", "next_id": "wound"},
				{"label": "Tell me about the Inquisition.", "next_id": "inquisition"},
				{"label": "Is there a traitor among your druids?",
				 "next_id": "traitor",
				 "require_class": ["chaos_druid"]},
				{"label": "Goodbye.", "next_id": "", "ends_dialogue": true}
			]
		},
		{
			"id": "wound",
			"speaker": "The Sanctum-Mother",
			"text": "When Marduk's first arrow opened Tiamat's side, she bled. The blood ran. The trees took it up. The trees here remember. They are not enemies. They are not allies. They are wrong, and they know it, and they ask you to be careful with them.",
			"choices": [{"label": "Back.", "next_id": "intro"}]
		},
		{
			"id": "inquisition",
			"speaker": "The Sanctum-Mother",
			"text": "The Inquisition has hunted Tiamat-blooded since the Edict. They are doing what Marduk asked them to do. We are doing what our blood asks us to do. Both jobs are old. Neither is going to stop. Sahirum is the latest in a line that will outlive him.",
			"choices": [{"label": "Back.", "next_id": "intro"}]
		},
		{
			"id": "traitor",
			"speaker": "The Sanctum-Mother",
			"text": "Yes. There is one. They walk the Mother-Tree paths every morning, the way I taught them. They came twelve years ago. They are very good. I have not turned them out because I want you to be the one who finds them. The trees will tell you which one. The trees do not lie about this.",
			"choices": [
				{"label": "I will find them.", "next_id": "", "ends_dialogue": true,
				 "starts_quest_id": "druid_traitor_grove",
				 "faction_rep_changes": {"druids": 250, "inquisition": -100}},
				{"label": "Back.", "next_id": "intro"}
			]
		}
	]
	_make_dialogue(&"sanctum_mother", &"intro", lines)

# ----------------------------------------------------------------
# HIGH MAGUS IDDINU - arcane council
# ----------------------------------------------------------------
func _register_high_magus() -> void:
	var lines := [
		{
			"id": "intro",
			"speaker": "High Magus Iddinu",
			"text": "If you are not a Mage, this conversation will be brief. If you are, my time is also valuable. Be quick.",
			"choices": [
				{"label": "What can you teach me?", "next_id": "teach", "require_class": ["mage"]},
				{"label": "Tell me about Old Asaridu.", "next_id": "asaridu"},
				{"label": "What is the Silent Gate?", "next_id": "silent_gate"},
				{"label": "Goodbye.", "next_id": "", "ends_dialogue": true}
			]
		},
		{
			"id": "teach",
			"speaker": "High Magus Iddinu",
			"text": "I will teach you nothing. I will, however, allow you access to the Inkstone Library's lower stacks. Do not bend any of the spines. Do not skip lunch.",
			"choices": [{"label": "Back.", "next_id": "intro"}]
		},
		{
			"id": "asaridu",
			"speaker": "High Magus Iddinu",
			"text": "The greatest of the recent generation. Sealed himself in his own well to hold a breach. The well still speaks his voice on quiet days. We have tried to recover the page he left behind. We have not succeeded. You may have better luck. You will not. But you may.",
			"choices": [
				{"label": "I'll try anyway.", "next_id": "intro",
				 "starts_quest_id": "asaridu_legacy"}
			]
		},
		{
			"id": "silent_gate",
			"speaker": "High Magus Iddinu",
			"text": "It is not for mortal hands. The Edict was not for mortals. The fact that you can see the gate at all is concerning. I would prefer if you did not stand near it.",
			"choices": [{"label": "Back.", "next_id": "intro"}]
		}
	]
	_make_dialogue(&"high_magus", &"intro", lines)

# ----------------------------------------------------------------
# GENERAL SIN-MUSHEZIB - Crown commander
# ----------------------------------------------------------------
func _register_general_sin_mushezib() -> void:
	var lines := [
		{
			"id": "intro",
			"speaker": "General Sin-Mushezib",
			"text": "Adventurer. Do you fight? Or are you here to ask which way the wind is blowing.",
			"choices": [
				{"label": "I fight. What's the contract?", "next_id": "contract"},
				{"label": "Tell me about the wastes.", "next_id": "wastes"},
				{"label": "Goodbye.", "next_id": "", "ends_dialogue": true}
			]
		},
		{
			"id": "contract",
			"speaker": "General Sin-Mushezib",
			"text": "Reed Wastes. A demon called Mu-Ash, Throat of the Wastes. Crown wants it dead. Brigand camps thinning under its presence; the Crown does not love brigands but they are at least Crown citizens. Tomb's a city; Mu-Ash is what the city forgot to be.",
			"choices": [
				{"label": "I'll do it.", "next_id": "intro",
				 "starts_quest_id": "reed_failure",
				 "faction_rep_changes": {"crown": 250}},
				{"label": "Tell me more first.", "next_id": "wastes"}
			]
		},
		{
			"id": "wastes",
			"speaker": "General Sin-Mushezib",
			"text": "The marsh dried when Marduk salted Tiamat's blood. The Ash-Step clans range there. Demons trickle through cracked seals nightly. We patrol when we can. We cannot keep up. Bring me Mu-Ash's eye and I'll consider us square.",
			"choices": [{"label": "Back.", "next_id": "intro"}]
		}
	]
	_make_dialogue(&"general_sin", &"intro", lines)

# ----------------------------------------------------------------
# BLACK-SAIL THE FIRST - pirate king
# ----------------------------------------------------------------
func _register_black_sail_first() -> void:
	var lines := [
		{
			"id": "intro",
			"speaker": "Black-Sail the First",
			"text": "You climbed onto my keep. You are either an idiot or someone the Crown sent. The Crown does not pay this well. So which.",
			"choices": [
				{"label": "An idiot.", "next_id": "idiot",
				 "faction_rep_changes": {"black_sail": -200}},
				{"label": "Crown contract.", "next_id": "contract",
				 "faction_rep_changes": {"crown": 350, "black_sail": -500}},
				{"label": "Negotiating.", "next_id": "negotiate",
				 "faction_rep_changes": {"black_sail": -100}}
			]
		},
		{
			"id": "idiot",
			"speaker": "Black-Sail the First",
			"text": "Honest. I respect honest. I will kill you anyway. Stand up.",
			"choices": [{"label": "...", "next_id": "fight", "ends_dialogue": true}]
		},
		{
			"id": "contract",
			"speaker": "Black-Sail the First",
			"text": "Sin-Mushezib's signature. He pays well to have his enemies removed. He pays you. He used to pay me. You are the new contractor. Stand up.",
			"choices": [{"label": "...", "next_id": "fight", "ends_dialogue": true}]
		},
		{
			"id": "negotiate",
			"speaker": "Black-Sail the First",
			"text": "I am amused. I am not interested. Stand up.",
			"choices": [{"label": "...", "next_id": "fight", "ends_dialogue": true}]
		}
	]
	_make_dialogue(&"black_sail_first", &"intro", lines)

# ----------------------------------------------------------------
# SAHIRUM THE WITCH-BURNER - Inquisition prime
# ----------------------------------------------------------------
func _register_sahirum_witch_burner() -> void:
	var lines := [
		{
			"id": "intro",
			"speaker": "Sahirum the Witch-Burner",
			"text": "You are alive. Interesting. I burned your mother. You may not remember her. The Inquisition's records do.",
			"choices": [
				{"label": "I remember her.", "next_id": "remember",
				 "faction_rep_changes": {"inquisition": -400, "druids": 200}},
				{"label": "I will end you.", "next_id": "end",
				 "faction_rep_changes": {"inquisition": -800, "druids": 350}},
				{"label": "Why did you burn her?", "next_id": "why",
				 "faction_rep_changes": {"inquisition": -200}}
			]
		},
		{
			"id": "remember",
			"speaker": "Sahirum the Witch-Burner",
			"text": "Then she would be glad. Mothers are usually glad. Stand up.",
			"choices": [{"label": "...", "next_id": "fight", "ends_dialogue": true}]
		},
		{
			"id": "end",
			"speaker": "Sahirum the Witch-Burner",
			"text": "You will try. Stand up.",
			"choices": [{"label": "...", "next_id": "fight", "ends_dialogue": true}]
		},
		{
			"id": "why",
			"speaker": "Sahirum the Witch-Burner",
			"text": "Marduk's edict. The blood was wrong. The blood is still wrong. Yours included. Stand up.",
			"choices": [{"label": "...", "next_id": "fight", "ends_dialogue": true}]
		}
	]
	_make_dialogue(&"sahirum_witch_burner", &"intro", lines)

# ----------------------------------------------------------------
# ORACLE ATTENDANT - feeds chalk to the blind oracle
# ----------------------------------------------------------------
func _register_oracle_attendant() -> void:
	var lines := [
		{
			"id": "intro",
			"speaker": "Oracle Attendant",
			"text": "She has not eaten since dawn. She also has not stopped writing. The pillar is full again. We are out of chalk.",
			"choices": [
				{"label": "I'll bring chalk.", "next_id": "chalk", "starts_quest_id": "oracle_chalk"},
				{"label": "What did she write today?", "next_id": "today"},
				{"label": "Back.", "next_id": "", "ends_dialogue": true}
			]
		},
		{
			"id": "today",
			"speaker": "Oracle Attendant",
			"text": "She wrote your name. And: 'the cycle begins, the cycle ends, eat the bread.' We do not always understand. The bread is, however, on the table.",
			"choices": [{"label": "Back.", "next_id": "intro"}]
		},
		{
			"id": "chalk",
			"speaker": "Oracle Attendant",
			"text": "Salt-and-Stone Apothecary. The blue stick. Not the white. Not the green. The blue.",
			"choices": [{"label": "Back.", "next_id": "intro"}]
		}
	]
	_make_dialogue(&"oracle_attendant", &"intro", lines)

# ----------------------------------------------------------------
# LUCIFER - secret final boss, dialogue check
# ----------------------------------------------------------------
func _register_lucifer() -> void:
	var lines := [
		{
			"id": "intro",
			"speaker": "Lucifer",
			"text": "Welcome. Sit, please. The stair is warm but the bench is cool. There is no rush. I would like to offer you something.",
			"choices": [
				{"label": "I'm listening.", "next_id": "listen"},
				{"label": "I refuse before you finish.", "next_id": "refuse_early",
				 "faction_rep_changes": {"crown": 500, "inquisition": 300}},
				{"label": "Insult him before he speaks.", "next_id": "insult",
				 "sets_run_flag": "insulted_lucifer",
				 "faction_rep_changes": {"crown": 250, "six_breaths": 100}}
			]
		},
		{
			"id": "listen",
			"speaker": "Lucifer",
			"text": "The cycle is exhausting. Tiamat returns. Marduk's edict frays. The seven seals have been failing for seventeen hundred years; they will fail again next cycle, and again, and again. I can stop the cycle. The price is simple. Walk back up. Tell the Storyteller you accept. The cycle ends. Marduk's grip on this world ends. The seven seals are unmade. Everyone goes home.",
			"choices": [
				{"label": "What is the catch?", "next_id": "catch"},
				{"label": "Refuse.", "next_id": "refuse_late"}
			]
		},
		{
			"id": "catch",
			"speaker": "Lucifer",
			"text": "The world ends with the cycle. Without Marduk's edict, Tiamat reasserts. The salt sea returns. Babilim drowns. The Ash-Step clans drown. Belitu drowns; the Storyteller does not, but she goes silent for ten thousand years out of grief, and grief, you understand, is contagious. The catch is the world. I am offering you the cycle's end. The world ends with it. I do not lie. I am simply not selling what you thought I was selling.",
			"choices": [
				{"label": "Refuse.", "next_id": "refuse_late",
				 "faction_rep_changes": {"crown": 1000, "inquisition": 500, "six_breaths": 500, "druids": 250}}
			]
		},
		{
			"id": "refuse_early",
			"speaker": "Lucifer",
			"text": "Brave, but premature. I had a different opening prepared. Stand up.",
			"choices": [{"label": "...", "next_id": "fight", "ends_dialogue": true}]
		},
		{
			"id": "refuse_late",
			"speaker": "Lucifer",
			"text": "I respect that. The Storyteller said you would. She has been right every cycle so far. Stand up.",
			"choices": [{"label": "...", "next_id": "fight", "ends_dialogue": true}]
		},
		{
			"id": "insult",
			"speaker": "Lucifer",
			"text": "Ah. Yes. Some things are worth saying. You have shortened my opening. I will lengthen the fight. Stand up.",
			"choices": [{"label": "...", "next_id": "fight", "ends_dialogue": true}]
		}
	]
	_make_dialogue(&"lucifer", &"intro", lines)

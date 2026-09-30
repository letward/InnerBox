class_name DialogueData
extends RefCounted
## Every line the game says. A node is either a list of lines, or lines plus
## choices. Choices may carry effects, applied the moment they are picked:
##   flag   : set a story flag to true
##   values : {flag: value} set several flags
##   quest  : start a quest id
##   done   : complete a quest id
##   give   : [item_id, count]
##   take   : [item_id, count]
##   heal   : hearts restored
##   close  : end the conversation instead of following "next"
##
## A speaker of "" is narration - no name plate.

const NARRATION := ""

const LINES := {
	# =====================================================================
	# ELDER MARROW
	# =====================================================================
	"elder_intro": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"There you are. I knew the path would keep one of us.",
			"Do not look at me like that. I know what you are: the part of this box that still remembers the shape of its own rooms.",
			"The rest of us have gone soft at the edges. It took the small things first.",
		],
		"choices": [
			{"text": "What happened in here?", "next": "elder_what"},
			{"text": "How do I fix it?", "next": "elder_fix"},
		],
	},
	"elder_what": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"Something in the core began eating. Not for hunger - to keep the lid shut.",
			"A box that remembers can be opened by anyone. A box that forgets has to stay shut.",
			"So it ate. Slowly. First the songs, then the faces, then the way home.",
		],
		"choices": [
			{"text": "And the people in here?", "next": "elder_people"},
			{"text": "Then what do we do?", "next": "elder_fix"},
		],
	},
	"elder_people": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"We are what is left of the music. Hold your hand to your chest and you will hear us, if you are quiet.",
			"You still have all of yours. That is not luck, child. That is an assignment.",
		],
		"choices": [
			{"text": "I'm listening.", "next": "elder_quest"},
		],
	},
	"elder_fix": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"Three braziers stand in Whisperwood. They were the box's lanterns - the last things it lit to see by.",
			"Take embers. Light all three. What they give back will be enough to cut a path inward.",
		],
		"choices": [
			{"text": "What will they give back?", "next": "elder_shard"},
			{"text": "I'll go at once.", "next": "elder_quest"},
		],
	},
	"elder_shard": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"Shards. The box stores its days in them, the way you store sweets in a tin.",
			"Take them to the Rust Hollow, past the gate, and put them where the eating came from.",
		],
		"choices": [
			{"text": "The Rust Hollow.", "next": "elder_quest"},
		],
	},
	"elder_quest": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"Whisperwood, then. North gate. Mind the moths - they follow anything that still has a pulse, and shame about it.",
			"Go on. I will hold the door shut behind you for as long as I can.",
		],
		"choices": [
			{"text": "I'll bring the light back.", "effects": {"done": "shattered_latch", "quest": "amber_light"}},
		],
	},
	"elder_wait_ambers": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"Embers first. They are lying about Whisperwood in little heaps, where the moss grew over dropped coals.",
			"Three braziers. Light all three and come back to me.",
		],
	},
	"elder_wait_lights": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"You carry enough embers for now. Go put them in the braziers, not in your pocket.",
		],
	},
	"elder_wait_shard": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"North gate. Whisperwood. You have heard it twice; go and do it.",
		],
	},
	"elder_shard_back": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"You are shaking. That is what it is like to hold a day in your hand.",
			"One shard. There will be more. There are always more, until you reach the thing that ate the first one.",
		],
		"choices": [
			{"text": "Where is it?", "next": "elder_where"},
		],
	},
	"elder_where": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"In the Rust Hollow, east of here. The gate is shut and it will stay shut.",
			"There is a key still made somewhere in that wreck. Find it, and mind the dark - it is not empty, only patient.",
			"Take this shard to the well on your way back. The well is where we keep what we still want.",
		],
		"choices": [
			{"text": "I'll find it.",
			 "effects": {"take": ["shard", 1], "done": "amber_light", "quest": "iron_tongue"}},
		],
	},
	"elder_wait_key": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"The Rust Hollow, east gate. Three plates, one key - the box was never wasteful.",
		],
	},
	"elder_wait_gate": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"You have the key. Get through that gate before you lose your nerve.",
		],
	},
	"elder_wait_core": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"It is awake again. Of course it is. You knocked.",
		],
	},
	"elder_wait_well": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"The Memory Well is at the south of the village. It is where the box keeps what it wants to keep.",
			"Three shards in the well. Then the lid, and whatever you decide to do with a world that is no longer hungry.",
			"Do not let me watch. I am not brave enough for the last part.",
		],
	},
	"elder_after": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": [
			"It is quiet. I had forgotten quiet was a thing the box could do.",
			"Listen. That is us, singing again, one note each. It will take years.",
			"Thank you for being the part that remembered.",
		],
	},
	"elder_idle": {
		"speaker": "Elder Marrow",
		"portrait": "elder",
		"lines": ["Every room in here is a memory of a bigger room. Walk carefully."],
	},

	# =====================================================================
	# TINK
	# =====================================================================
	"tink_intro": {
		"speaker": "Tink",
		"portrait": "tink",
		"lines": [
			"Careful! Mind the - ah. You have a whole shape. I had forgotten those walked around.",
			"I make things. Well. I make them into other things.",
		],
		"choices": [
			{"text": "What do you need?", "next": "tink_trade"},
			{"text": "What is this place?", "next": "tink_place"},
		],
	},
	"tink_trade": {
		"speaker": "Tink",
		"portrait": "tink",
		"lines": [
			"Cogs. Everything useful in here is a cog if you are patient with it.",
			"Three cogs, I give you two salves. No haggling. I am eleven, or I was.",
		],
		"choices": [
			{"text": "Trade 3 cogs for 2 salves.", "effects": {"take": ["cog", 3], "give": ["salve", 2]}},
			{"text": "Maybe later.", "close": true},
		],
	},
	"tink_place": {
		"speaker": "Tink",
		"portrait": "tink",
		"lines": [
			"A music box the size of a room, and we are the song inside it.",
			"Outside the walls there is only the lid. We stopped knocking a long time ago.",
		],
		"choices": [
			{"text": "What should I watch out for?", "next": "tink_danger"},
			{"text": "Show me your wares.", "next": "tink_trade"},
		],
	},
	"tink_danger": {
		"speaker": "Tink",
		"portrait": "tink",
		"lines": [
			"Rust ticks in the wood. They used to be the metronome. Now they just bite.",
			"Gloom moths hunt anything warm. Swing the empty hand, not the one holding the shard - they go for what glows.",
			"And in the deep dark, something big and slow. Do not let it touch you.",
		],
		"choices": [
			{"text": "Understood.", "close": true},
		],
	},
	"tink_done_trade": {
		"speaker": "Tink",
		"portrait": "tink",
		"lines": [
			"There. Do not drink it and do not eat the cork, and do not ask what it is made of.",
		],
	},
	"tink_no_trade": {
		"speaker": "Tink",
		"portrait": "tink",
		"lines": ["Bring me cogs. The ticks carry them in their bellies."],
	},
	"tink_full": {
		"speaker": "Tink",
		"portrait": "tink",
		"lines": [
			"You are full of salve and I am full of cogs. One of us is wasting something.",
			"Go and fight something. It will not be wasted.",
		],
	},
	"tink_idle": {
		"speaker": "Tink",
		"portrait": "tink",
		"lines": ["Three cogs, two salves. That is the whole economy."],
	},

	# =====================================================================
	# PIP
	# =====================================================================
	"pip_intro": {
		"speaker": "Pip",
		"portrait": "pip",
		"lines": [
			"Are you the new one? The whole one?",
			"I am Pip. I am made of the page somebody was not reading.",
		],
		"choices": [
			{"text": "Are you all right?", "next": "pip_lost"},
			{"text": "Nice to meet you.", "next": "pip_lost"},
		],
	},
	"pip_lost": {
		"speaker": "Pip",
		"portrait": "pip",
		"lines": [
			"I had a moon. A paper moon, folded out of my own page, and I hung it in the Rust Hollow so it would shine in the dark.",
			"It is not there any more. Somebody took it, or the dark ate it, and I do not know which is worse.",
			"Find it and I will stop following you around.",
		],
		"choices": [
			{"text": "I'll look.", "effects": {"quest": "paper_moon"}},
		],
	},
	"pip_again": {
		"speaker": "Pip",
		"portrait": "pip",
		"lines": [
			"You went into the dark for me?",
			"I thought everyone in the box only went to the dark for themselves.",
		],
		"choices": [
			{"text": "You're worth it.", "effects": {"give": ["salve", 2], "done": "paper_moon"}},
		],
	},
	"pip_done": {
		"speaker": "Pip",
		"portrait": "pip",
		"lines": [
			"I am hanging it up again. Look - it is still shining. Nothing down there could eat that.",
			"Go on, then. Bring the box back.",
		],
	},
	"pip_idle": {
		"speaker": "Pip",
		"portrait": "pip",
		"lines": ["If you find something small and bright down there, that is probably mine."],
	},

	# =====================================================================
	# THE BOX / NARRATION
	# =====================================================================
	"box_intro": {
		"speaker": "",
		"portrait": "box",
		"lines": [
			"The box was closed for eleven years.",
			"Long enough for the song inside it to forget it was a song.",
			"Long enough for something to decide that a closed box is a kind one.",
			"You wake with a lantern you cannot light and a name nobody here says out loud.",
			"Whatever is left of you gets up and opens the door.",
		],
		"choices": [
			{"text": "Begin.", "close": true},
		],
	},
	"box_brazier": {
		"speaker": "",
		"portrait": "box",
		"lines": [
			"The ember takes. For one moment the whole wood has a face you recognise.",
		],
	},
	"box_brazier_all": {
		"speaker": "",
		"portrait": "box",
		"lines": [
			"Three lanterns. The wood stops being a wood and becomes a hallway again.",
			"Something steps out of the light carrying a piece of yesterday.",
		],
		"choices": [
			{"text": "Take the shard.", "effects": {"give": ["shard", 1], "flag": "shard_from_wood"}},
		],
	},
	"box_plates": {
		"speaker": "",
		"portrait": "box",
		"lines": [
			"Three plates. Three crates. The box was never wasteful.",
			"Something heavy unlocks somewhere behind the wall.",
		],
		"choices": [
			{"text": "Search the vault.", "effects": {"flag": "vault_open"}},
		],
	},
	"box_gate": {
		"speaker": "",
		"portrait": "box",
		"lines": [
			"The key is older than the rust on it. The gate opens like it is apologising.",
		],
	},
	"box_boss_intro": {
		"speaker": "The Corrosion",
		"portrait": "corrosion",
		"lines": [
			"It does not speak. It has not needed to for a very long time.",
			"It only opens, and keeps opening, and takes.",
		],
		"choices": [
			{"text": "End it.", "close": true},
		],
	},
	"box_boss_end": {
		"speaker": "",
		"portrait": "box",
		"lines": [
			"It comes apart like a held breath.",
			"Inside it there is no monster. There is only a latch, and a great deal of hunger, and a door that was never locked from the outside.",
			"Underneath, one last shard.",
		],
		"choices": [
			{"text": "Take it.",
			 "effects": {"give": ["shard", 1], "extra": [["echo_core", 1]],
			             "done": "corroded_heart", "quest": "what_the_box_remembers"}},
		],
	},
	"box_well": {
		"speaker": "",
		"portrait": "box",
		"lines": [
			"The well is warm. It has been warm the whole time, waiting.",
			"Three shards, and a lid, and a world that is no longer hungry.",
		],
	},
	"box_well_wait": {
		"speaker": "",
		"portrait": "box",
		"lines": [
			"The well takes what you give it and is not fussy about the order.",
			"It has three notches in the rim. You are not going to fill them all today.",
		],
	},
	"box_death": {
		"speaker": "",
		"portrait": "box",
		"lines": [
			"You come apart into a note that nobody was playing.",
			"Somewhere in the box, the song picks itself up and starts again.",
		],
	},

	# =====================================================================
	# SIGNS AND READABLES
	# =====================================================================
	"sign_village": {
		"speaker": "",
		"portrait": "box",
		"lines": ["HOLLOWMERE - pop. 41. Please keep the music down after the ninth hour."],
	},
	"sign_woods": {
		"speaker": "",
		"portrait": "box",
		"lines": ["WHISPERWOOD. The lanterns were for seeing by. Now they are for remembering by."],
	},
	"sign_woods2": {
		"speaker": "",
		"portrait": "box",
		"lines": ["If you can read this, the moths have not got you yet. Keep to the lanterns."],
	},
	"sign_hollow": {
		"speaker": "",
		"portrait": "box",
		"lines": ["THE RUST HOLLOW. Mind the plates. They still count things."],
	},
	"sign_core": {
		"speaker": "",
		"portrait": "box",
		"lines": ["THE CORE. Nothing has been allowed in here since the box was first wound."],
	},

	# =====================================================================
	# ENDING
	# =====================================================================
	"ending": {
		"speaker": "",
		"portrait": "box",
		"lines": [
			"You set the shards into the well, one at a time, the way you would wind a spring.",
			"The lid does not open.",
			"It does not have to. Nothing is eating it now.",
			"Outside, a hand that had been holding the box for eleven years finally lets go.",
			"Somewhere, a music box begins to play, and this time the room is listening.",
		],
	},
}


static func has_node(id: String) -> bool:
	return LINES.has(id)


static func get_node(id: String) -> Dictionary:
	return LINES.get(id, {
		"speaker": "",
		"portrait": "box",
		"lines": ["..."],
	})

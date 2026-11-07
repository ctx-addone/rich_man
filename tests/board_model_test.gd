extends SceneTree

const Model = preload("res://scripts/model/board_model.gd")
var failures := 0

func check(condition: bool, reason: String) -> void:
	if not condition:
		failures += 1
		push_error(reason)

func fixture() -> Dictionary:
	# A contract fixture, not a claim to reproduce a Richman 11 map.
	return {
		"roads": [
			{"id":"north_a", "cell":[1,0], "exits":["north_b"]},
			{"id":"north_b", "cell":[2,0], "exits":["north_a","west"]},
			{"id":"west", "cell":[0,2], "exits":["north_b"]},
			{"id":"corner", "cell":[0,0], "exits":[]},
			{"id":"bank_road", "cell":[7,0], "exits":[]}
		],
		"lots": [
			{"id":"large_a", "footprint":[1,1,4,4], "frontage_nodes":["north_a","north_b","west"], "kind":"large", "trigger_events":["stop"], "rule_id":"USER-MULTI-FRONTAGE"},
			{"id":"bank", "footprint":[7,1,2,2], "frontage_nodes":["bank_road"], "kind":"facility", "trigger_events":["pass","stop"], "rule_id":"R11-BANK-PASS"}
		]
	}

func _initialize() -> void:
	var model = Model.new()
	check(model.load_layout(fixture()).is_empty(), "Valid 4x4 building and independent roads must load")
	check(model.lot_at_cell(Vector2i(3,3)) == "large_a", "All footprint cells reference one lot")
	check(model.lot_at_cell(Vector2i(2,0)) == "", "Walkable road must not be the building")
	for road in ["north_a","north_b","west"]:
		check(model.lots_for_event(road,"stop") == ["large_a"], "Every configured frontage triggers same building exactly once")
		check(model.lots_for_event(road,"pass").is_empty(), "Stop rule cannot silently charge for passing")
	check(model.lots_for_event("corner","stop").is_empty(), "Corner proximity is not frontage")
	check(model.lots_for_event("bank_road","pass") == ["bank"], "Bank can trigger on passing without finishing movement")
	check(model.set_lot_state("large_a",2,4,"hotel"), "Building state updates independently of road")
	for road in ["north_a","north_b","west"]:
		var id: String = model.lots_for_event(road,"stop")[0]
		check(model.lots[id].owner == 2 and model.lots[id].level == 4, "All frontage shares owner and level")
		check(not model.roads[road].has("owner"), "Road must not duplicate property ownership")
	var invalid := fixture()
	invalid.lots[0].footprint = [0,0,4,4]
	check(not model.load_layout(invalid).is_empty(), "Reject road/building overlap")
	check(model.lots.large_a.owner == 2, "Invalid import leaves previous board intact")
	invalid = fixture()
	invalid.lots[0].frontage_nodes.append("north_a")
	check(not model.load_layout(invalid).is_empty(), "Reject duplicate trigger frontage")
	invalid = fixture()
	invalid.lots[0].frontage_nodes = ["corner"]
	check(not model.load_layout(invalid).is_empty(), "Reject diagonal frontage")
	invalid = fixture()
	invalid.lots[1].footprint = [2,2,2,2]
	check(not model.load_layout(invalid).is_empty(), "Reject overlapping lots")
	invalid = fixture()
	invalid.roads[0].exits = ["absent"]
	check(not model.load_layout(invalid).is_empty(), "Reject missing exit target")
	invalid = fixture()
	invalid.roads[0].cell = [1.5,0]
	check(not model.load_layout(invalid).is_empty(), "Reject fractional cells")
	invalid = fixture()
	invalid.roads[0].event_ids = 3
	check(not model.load_layout(invalid).is_empty(), "Invalid event list rejected without runtime error")
	invalid = fixture()
	invalid.lots[0].owner = {"unexpected": true}
	check(not model.load_layout(invalid).is_empty(), "Invalid owner type rejected without runtime error")
	invalid = fixture()
	invalid.lots[0].level = -1
	check(not model.load_layout(invalid).is_empty(), "Negative level rejected")
	check(model.lots.large_a.owner == 2, "Malformed imports preserve valid ownership")
	print("BOARD_MODEL_CONTRACT failures=", failures)
	quit(1 if failures else 0)

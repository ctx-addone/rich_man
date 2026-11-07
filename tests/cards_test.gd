extends SceneTree

const Game = preload("res://scripts/game_state.gd")
const Catalog = preload("res://scripts/model/cards_catalog.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)

func fresh():
	var g = Game.new()
	g.setup(["甲","乙","丙","丁"], 17)
	return g

func equip(g, card: String) -> void:
	g.players[g.current].cards = [card]

func _initialize() -> void:
	check(Catalog.ALL.size() == 48, "Evidence catalogue retains all 48 source cards")
	for id in Catalog.ALL:
		check(Catalog.ALL[id].implemented == Catalog.NAMES.has(id), "Catalogue status matches executable pool")
	var g = fresh()
	equip(g,"audit")
	g.players[1].cash = 1001
	g.players[1].deposit = 777
	check(g.use_card("audit",1), "Audit accepts nearby opponent")
	check(g.players[0].cash == 10150 and g.players[1].cash == 851 and g.players[1].deposit == 777, "Audit floors 15 percent of cash and conserves funds")
	equip(g,"equal_pair")
	g.players[0].cash = 3
	g.players[1].cash = 4
	check(g.use_card("equal_pair",1) and g.players[0].cash+g.players[1].cash == 7, "Pair equalization conserves odd cash")
	equip(g,"equal_all")
	for i in range(4): g.players[i].cash = i
	check(g.use_card("equal_all"), "Global equalization executes")
	check(g.players[0].cash+g.players[1].cash+g.players[2].cash+g.players[3].cash == 6, "Global equalization conserves remainder")
	g = fresh()
	equip(g,"steal")
	g.players[1].cards = ["dice"]
	check(g.use_card("steal",1) and g.players[0].cards == ["dice"] and g.players[1].cards.is_empty(), "Steal transfers one card and consumes itself")
	g.players[0].cards = ["steal","dice","dice","dice","dice","dice","dice","dice"]
	g.players[1].cards = ["mine"]
	check(g.use_card("steal",1) and g.players[1].cards.is_empty() and g.players[0].cards.size() == 8 and g.players[0].cards.has("mine"), "Steal consumption releases space before receiving the target card")
	g = fresh()
	equip(g,"roadblock")
	check(g.use_card("roadblock",1), "Roadblock places")
	g.roll_dice(4)
	g.move_to(1)
	check(g.phase == "land" and g.steps_left == 0 and g.players[0].status.is_empty() and not g.road_objects.has(1), "Roadblock stops and resolves landing without hospital")
	g = fresh()
	equip(g,"portal")
	check(g.use_card("portal",1), "Portal places on a legal road")
	g.roll_dice(4)
	g.move_to(1)
	check(g.players[0].pos != 1 and g.steps_left == 0 and not g.road_objects.has(1), "Portal consumes itself and ends movement at another road")
	g = fresh()
	var lot: Dictionary = g.lots.lot_1_1
	lot.owner = 0
	lot.level = 1
	lot.building_type = "mall"
	equip(g,"worker")
	check(g.use_card("worker",lot.id) and lot.level == 2, "Worker upgrades shared building")
	equip(g,"bulldozer")
	check(g.use_card("bulldozer",lot.id) and lot.level == 1, "Bulldozer reduces shared building")
	equip(g,"rebuild")
	var options: Array = g.building_options(lot.id)
	var hotel_index: int = options.find("hotel")
	check(hotel_index >= 0 and g.use_card("rebuild",lot.id,hotel_index) and lot.building_type == "hotel", "Rebuild uses selected building type")
	equip(g,"rebuild")
	check(not g.use_card("rebuild",lot.id,hotel_index) and g.players[0].cards.has("rebuild"), "No-op rebuild does not consume card")
	equip(g,"close_street")
	check(g.use_card("close_street",lot.id) and lot.closed_until == g.round_number+5, "Street closure expiry stored")
	check(g.rent_preview(lot.id,1) == 0, "Closure suppresses actual rent")
	lot.closed_until = 0
	var base_rent: int = g.rent_preview(lot.id,1)
	equip(g,"raise_rent")
	check(g.use_card("raise_rent",lot.id) and lot.rent_until == g.round_number+6, "Street rent expiry stored")
	check(g.rent_preview(lot.id,1) == base_rent*2, "Street card doubles actual rent")
	equip(g,"glory")
	check(g.use_card("glory") and g.players[0].glory_until == g.round_number+12, "Glory expiry stored on owner")
	check(g.rent_preview(lot.id,1) == base_rent*4, "Independent rent multipliers combine")
	g.round_number += 12
	check(g.rent_preview(lot.id,1) == base_rent, "Expired multipliers stop affecting rent")
	lot.owner = 1
	equip(g,"misery")
	check(g.use_card("misery") and lot.closed_until == g.round_number+6, "Opponent closure applied")
	lot.level = 5
	equip(g,"disaster")
	check(g.use_card("disaster") and lot.level == 1, "Disaster drops four levels")
	equip(g,"worker")
	check(not g.use_card("worker",lot.id) and g.players[0].cards.has("worker"), "Worker rejects opponent property without consuming")
	check(g.gm_give_card(0,"free"), "Free reaction card included in live GM pool")
	check(not g.use_card("free") and g.players[0].cards.has("free"), "Free cannot be spent as an active card")
	print("R3_CARDS failures=",failures)
	quit(1 if failures else 0)

class_name EmberLayout
extends RefCounted
## Shared output-pixel geometry for rendering and input. No game rules here.

var viewport_size := Vector2(1440, 960)
var cell_size := 64.0
var art_scale := 2
var grid_origin := Vector2.ZERO
var bag_rect: Rect2
var market_rect: Rect2
var notes_rect: Rect2
var battle_rect: Rect2
var route_rect: Rect2
var primary_rect: Rect2
var refresh_rect: Rect2
var sell_rect: Rect2
var menu_rect: Rect2
var menu_panel_rect: Rect2
var menu_continue: Rect2
var menu_save: Rect2
var menu_load: Rect2
var menu_new: Rect2
var header_sound_rect: Rect2
var header_help_rect: Rect2
var speed_rect: Rect2
var recipe_toggle_rect: Rect2
var recipe_prev_rect: Rect2
var recipe_next_rect: Rect2
var modal_overlay_rect: Rect2
var reward_panel_rect: Rect2
var help_panel_rect: Rect2
var footer_rect: Rect2

func _init(output_size: Vector2 = Vector2(1440, 960)) -> void:
	update(output_size)

func update(output_size: Vector2) -> void:
	viewport_size = output_size
	var w: float = maxf(1280.0, output_size.x)
	var h: float = maxf(800.0, output_size.y)
	art_scale = 3 if w >= 1800 and h >= 1040 else 2
	cell_size = float(32 * art_scale)
	var margin := 24.0
	var gap := 16.0
	var stage_height: float = floorf(clampf(h * 0.28, 224.0, 302.0) / 2.0) * 2.0
	stage_height = minf(stage_height, 144 * art_scale)
	var route_width: float = floorf(clampf(w * 0.24, 288.0, 350.0))
	battle_rect = Rect2(margin, 94, w - margin * 2 - gap - route_width, stage_height)
	route_rect = Rect2(battle_rect.end.x + gap, 94, route_width, stage_height)
	var panel_y: float = battle_rect.end.y + gap
	var panel_height: float = h - 94.0 - panel_y
	var bag_width: float = cell_size * 6.0 + 52.0
	var market_width: float = floorf(clampf(w * 0.275, 336.0, 430.0))
	bag_rect = Rect2(margin, panel_y, bag_width, panel_height)
	market_rect = Rect2(bag_rect.end.x + gap, panel_y, market_width, panel_height)
	notes_rect = Rect2(market_rect.end.x + gap, panel_y, w - margin - market_rect.end.x - gap, panel_height)
	grid_origin = Vector2(floorf((bag_rect.position.x + 26.0) / art_scale) * art_scale, floorf((panel_y + 54.0 + maxf(0.0, panel_height - cell_size * 4.0 - 112.0) * 0.35) / art_scale) * art_scale)
	primary_rect = Rect2(w - 344, h - 76, 320, 52)
	footer_rect = Rect2(24, h - 76, w - 384, 52)
	refresh_rect = Rect2(market_rect.end.x - 120, panel_y + 18, 102, 32)
	sell_rect = Rect2(bag_rect.end.x - 154, bag_rect.end.y - 48, 130, 32)
	menu_rect = Rect2(w - 596, 26, 162, 38)
	header_sound_rect = Rect2(w - 214, 26, 88, 38)
	header_help_rect = Rect2(w - 112, 26, 88, 38)
	speed_rect = Rect2(battle_rect.get_center().x - 36, battle_rect.position.y + 47, 72, 26)
	recipe_toggle_rect = Rect2(notes_rect.end.x - 130, panel_y + 18, 110, 32)
	recipe_prev_rect = Rect2(notes_rect.position.x + 20, notes_rect.end.y - 46, 48, 30)
	recipe_next_rect = Rect2(notes_rect.end.x - 68, notes_rect.end.y - 46, 48, 30)
	modal_overlay_rect = Rect2(Vector2.ZERO, output_size)
	menu_panel_rect = Rect2(Vector2((w - 552) / 2.0, (h - 496) / 2.0), Vector2(552, 496))
	var menu_x: float = menu_panel_rect.position.x + 44
	var menu_y: float = menu_panel_rect.position.y + 130
	menu_continue = Rect2(menu_x, menu_y, 464, 48)
	menu_save = Rect2(menu_x, menu_y + 64, 464, 48)
	menu_load = Rect2(menu_x, menu_y + 128, 464, 48)
	menu_new = Rect2(menu_x, menu_y + 192, 464, 48)
	reward_panel_rect = Rect2(Vector2((w - 872) / 2.0, (h - 410) / 2.0), Vector2(872, 410))
	help_panel_rect = Rect2(Vector2((w - 820) / 2.0, (h - 644) / 2.0), Vector2(820, 644))

func shop_rect(index: int) -> Rect2:
	var card_width: float = floorf((market_rect.size.x - 52.0) / 2.0)
	var card_height: float = floorf((market_rect.size.y - 108.0) / 2.0)
	return Rect2(market_rect.position + Vector2(18 + (index % 2) * (card_width + 16), 66 + (index / 2) * (card_height + 12)), Vector2(card_width, card_height))

func reward_rect(index: int) -> Rect2:
	return Rect2(reward_panel_rect.position + Vector2(28 + index * 278, 126), Vector2(260, 214))

func blessing_rect(index: int) -> Rect2:
	return Rect2(route_rect.end.x - 24 - (4 - index) * 32, route_rect.position.y + 17, 28, 28)

func grid_rect() -> Rect2:
	return Rect2(grid_origin, Vector2(6, 4) * cell_size)

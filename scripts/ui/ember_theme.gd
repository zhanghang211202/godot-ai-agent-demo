class_name EmberTheme
extends RefCounted
## Original field-journal materials. Decoration stays in the panel margins.

const BG := Color("101d20")
const PANEL := Color("1a2b2c")
const PANEL_EDGE := Color("4b6256")
const TEXT := Color("eee7cd")
const MUTED := Color("9cae9c")
const GOLD := Color("e5bf77")
const TEAL := Color("8bc6ac")
const RED := Color("e29481")
const PAPER := Color("d8cba6")
const INK := Color("343b32")
const LEATHER := Color("45392c")
const BRASS := Color("a8874e")


static func draw_panel(canvas: CanvasItem, rect: Rect2, material: String = "dark") -> void:
	var box := Rect2(rect.position.floor(), rect.size.floor())
	if box.size.x < 12.0 or box.size.y < 12.0:
		return
	var fill := PANEL
	var edge := PANEL_EDGE
	var lip := Color("2d423b")
	if material == "paper":
		fill = PAPER
		edge = Color("95865d")
		lip = Color("eee1bb")
	elif material == "leather":
		fill = LEATHER
		edge = Color("897047")
		lip = Color("635039")
	_cut_rect(canvas, Rect2(box.position + Vector2(0, 3), box.size), Color("0b1518"), 5.0)
	_cut_rect(canvas, box, edge, 4.0)
	_cut_rect(canvas, box.grow(-1.0), Color("172523") if material == "dark" else edge.darkened(0.24), 3.0)
	_cut_rect(canvas, box.grow(-3.0), fill, 2.0)
	canvas.draw_rect(Rect2(box.position + Vector2(6, 3), Vector2(box.size.x - 12, 1)), lip)
	canvas.draw_rect(Rect2(box.position + Vector2(3, 6), Vector2(1, box.size.y - 12)), lip)
	if material == "paper":
		_draw_paper_corners(canvas, box)
	elif material == "leather":
		_draw_stitching(canvas, box, Color("a38b5d"))
		_draw_corners(canvas, box, BRASS)
	else:
		_draw_corners(canvas, box, Color("7a8158"))


static func draw_button(canvas: CanvasItem, rect: Rect2, hovered: bool = false, primary: bool = false, disabled: bool = false) -> void:
	var box := Rect2(rect.position.floor(), rect.size.floor())
	if box.size.x < 12.0 or box.size.y < 12.0:
		return
	var fill := Color("30453b") if hovered else Color("24382f")
	var edge := Color("a4ad7c") if hovered else Color("647858")
	var bevel := Color("5a7150")
	if primary:
		fill = Color("775631") if hovered else Color("614929")
		edge = GOLD if hovered else BRASS
		bevel = Color("9d7945")
	if disabled:
		fill = Color("25302d")
		edge = Color("465048")
		bevel = Color("39483d")
	_cut_rect(canvas, Rect2(box.position + Vector2(0, 2), box.size), Color("0b1518"), 4.0)
	_cut_rect(canvas, box, edge, 4.0)
	_cut_rect(canvas, box.grow(-2.0), fill, 3.0)
	canvas.draw_rect(Rect2(box.position + Vector2(6, 2), Vector2(box.size.x - 12, 1)), bevel)
	canvas.draw_rect(Rect2(Vector2(box.position.x + 6, box.end.y - 4), Vector2(box.size.x - 12, 1)), fill.darkened(0.22))
	if primary and not disabled and box.size.x >= 100.0:
		for side in [-1, 1]:
			var center := Vector2(box.get_center().x + side * (box.size.x * 0.5 - 11.0), box.get_center().y)
			canvas.draw_rect(Rect2(center - Vector2(1, 3), Vector2(2, 6)), BRASS)
			canvas.draw_rect(Rect2(center - Vector2(3, 1), Vector2(6, 2)), GOLD if hovered else Color("b89659"))


static func _cut_rect(canvas: CanvasItem, rect: Rect2, color: Color, corner: float) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(corner, 0), rect.size - Vector2(corner * 2, 0)), color)
	canvas.draw_rect(Rect2(rect.position + Vector2(0, corner), rect.size - Vector2(0, corner * 2)), color)
	for offset in [Vector2(2, 2), Vector2(rect.size.x - corner, 2), Vector2(2, rect.size.y - corner), rect.size - Vector2(corner, corner)]:
		canvas.draw_rect(Rect2(rect.position + offset, Vector2(corner - 1, corner - 1)), color)


static func _draw_corners(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	for x in [rect.position.x + 5, rect.end.x - 8]:
		for y in [rect.position.y + 5, rect.end.y - 8]:
			canvas.draw_rect(Rect2(x, y, 3, 3), color)
			canvas.draw_rect(Rect2(x, y, 1, 1), color.lightened(0.23))


static func _draw_stitching(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	for x in range(int(rect.position.x) + 15, int(rect.end.x) - 13, 12):
		canvas.draw_rect(Rect2(x, rect.position.y + 7, 3, 1), color)
		canvas.draw_rect(Rect2(x, rect.end.y - 8, 3, 1), color.darkened(0.15))
	for y in range(int(rect.position.y) + 16, int(rect.end.y) - 14, 12):
		canvas.draw_rect(Rect2(rect.position.x + 7, y, 1, 3), color)
		canvas.draw_rect(Rect2(rect.end.x - 8, y, 1, 3), color.darkened(0.15))


static func _draw_paper_corners(canvas: CanvasItem, rect: Rect2) -> void:
	var right := int(rect.end.x) - 4
	var top := int(rect.position.y) + 4
	# Folded upper corner uses stepped pixels rather than a smooth triangle.
	for step in range(7):
		canvas.draw_rect(Rect2(right - 7 + step, top + step, 7 - step, 1), Color("b0a07b"))
	canvas.draw_rect(Rect2(right - 7, top + 7, 7, 1), Color("ebe0bb"))
	canvas.draw_rect(Rect2(rect.position.x + 7, rect.end.y - 12, 12, 1), Color("bcad87"))
	canvas.draw_rect(Rect2(rect.position.x + 7, rect.end.y - 9, 6, 1), Color("c5b792"))

class_name DragDropStep
extends StepBase
## Drag the correct item(s) from the tray onto the correct target.
## params:
##   body_label: String            caption of the body part
##   items: [{label, correct: bool, effect, strike?: bool}]   wrong item = strike (default)
##   targets: [{label, correct: bool, effect}]   (optional; wrong target = strike)
##   target_label: String          label when there is a single target

var _needed: int = 0
var _placed: int = 0
var _body_rect := Rect2()


func _build() -> void:
	var items: Array = p("items", [])
	for it: Dictionary in items:
		if it.get("correct", false):
			_needed += 1
	build_tray(items)
	var targets: Array = p("targets", [])
	if targets.is_empty():
		targets = [{"label": p("target_label", "Drop here"), "correct": true}]
	var n := targets.size()
	for i: int in n:
		var t: Dictionary = targets[i]
		var z := DropZone.new()
		z.caption = t.get("label", "")
		z.zone_data = t
		z.on_drop = _on_drop
		add_child(z)
		z.anchor_left = 0.14
		z.anchor_right = 0.62
		var band := 0.68 / n
		z.anchor_top = 0.2 + band * i + 0.02
		z.anchor_bottom = 0.2 + band * (i + 1) - 0.02


func _draw() -> void:
	_body_rect = Rect2(size * Vector2(0.04, 0.04), size * Vector2(0.68, 0.92))
	draw_body_part(_body_rect, str(p("body_label", "Patient")))


func _on_drop(item: Dictionary, card: ItemCard, zone: DropZone) -> void:
	if done:
		return
	if not item.get("correct", false):
		if card != null:
			card.flash_wrong()
			card.mark_wrong()
		fail(str(item.get("effect", item.get("feedback", "That item is not right for this step."))), bool(item.get("strike", true)), str(item.get("label", "")))
		return
	if not zone.zone_data.get("correct", false):
		zone.bad = true
		zone.accepting = false
		zone.queue_redraw()
		fail(str(zone.zone_data.get("effect", zone.zone_data.get("feedback", "Right item, wrong place."))), true, "%s on the %s" % [item.get("label", ""), zone.zone_data.get("label", "")])
		return
	if card != null:
		card.mark_used()
	zone.good = true
	zone.queue_redraw()
	_placed += 1
	progress_changed.emit(float(_placed) / float(maxi(1, _needed)))
	if _placed >= _needed:
		complete()

class_name StageRunner
extends RefCounted
## Pure game logic for one stage (no UI, fully unit-testable).
##
## Flow per scene (matches the sketch):
##   SCENARIO -> player picks choice A (correct) / B (wrong) -> SHOW EFFECT -> forward
##   Correct or wrong, the stage then moves FORWARD: the player performs the correct
##   procedure (actions), then the next scene. A wrong pick costs a strike.
##
## Guarantees:
##   - Finite: scene_idx and action_idx only ever increase; every scene is visited once.
##   - 3 strikes -> FAILED, decided right after the 3rd consequence has been shown.
##   - Every call that is invalid for the current state is a no-op (returns {}).

enum State {
	DECISION,         ## waiting for the player to pick a choice
	DECISION_RESULT,  ## showing the effect of the picked choice
	ACTION,           ## performing a procedure (gesture minigame)
	ACTION_RESULT,    ## showing the effect of a completed procedure
	STRIKE_RESULT,    ## showing the effect of a wrong procedure picked inside an action
	TIMEOUT_RESULT,   ## an action ran out of time
	FAILED,           ## 3 strikes - terminal
	COMPLETE,         ## all scenes done - terminal
}

const MAX_STRIKES := 3
const POINTS := 10
const HESITATE_EFFECT := "You hesitated. In an emergency, every second counts - delay lets the injury get worse."
const ACTION_TIMEOUT_EFFECT := "Time ran out before the procedure was finished. The patient's condition got worse."

var scenes: Array = []
var scene_idx: int = 0
var action_idx: int = 0
var state: State = State.DECISION
var strikes: int = 0
var score: int = 0
var correct: int = 0
var incorrect: int = 0
var technique_errors: int = 0
var penalty: int = 2
var mistakes_log: Array = []     ## [{scene, chosen, effect, correct_procedure}] for the review screen
var last_outcome: Dictionary = {}


func _init(p_scenes: Array = [], p_penalty: int = 2) -> void:
	scenes = p_scenes
	penalty = p_penalty
	state = State.DECISION if scenes.size() > 0 else State.COMPLETE


# ------------------------------------------------------------------ queries

func is_over() -> bool:
	return state == State.FAILED or state == State.COMPLETE


func is_failed() -> bool:
	return state == State.FAILED


func current_scene() -> Dictionary:
	if scene_idx < 0 or scene_idx >= scenes.size():
		return {}
	return scenes[scene_idx]


func current_actions() -> Array:
	return current_scene().get("actions", [])


func current_action() -> Dictionary:
	var acts := current_actions()
	if action_idx < 0 or action_idx >= acts.size():
		return {}
	return acts[action_idx]


func correct_choice() -> Dictionary:
	for ch: Dictionary in current_scene().get("choices", []):
		if ch.get("correct", false):
			return ch
	return {}


func max_score() -> int:
	var total := 0
	for sc: Dictionary in scenes:
		total += POINTS * (1 + sc.get("actions", []).size())
	return total


func final_score() -> int:
	return clampi(score, 0, max_score())


## 0 if failed. Otherwise by percentage (90/70/40), capped at 3 - strikes.
func stars() -> int:
	if state != State.COMPLETE:
		return 0
	var m := max_score()
	var pct := 1.0 if m == 0 else float(final_score()) / float(m)
	var s := 0
	if pct >= 0.9:
		s = 3
	elif pct >= 0.7:
		s = 2
	elif pct >= 0.4:
		s = 1
	return mini(s, MAX_STRIKES - strikes)


# ------------------------------------------------------------------ actions

## Player picks choice i (index into the scene's ORIGINAL choices array).
func choose(i: int) -> Dictionary:
	if state != State.DECISION:
		return {}
	var choices: Array = current_scene().get("choices", [])
	if i < 0 or i >= choices.size():
		return {}
	var ch: Dictionary = choices[i]
	if ch.get("correct", false):
		score += POINTS
		correct += 1
		last_outcome = _outcome(true, ch.get("label", ""), ch.get("effect", ""), ch.get("mood", "happy"), false)
	else:
		_add_strike(ch.get("label", ""), ch.get("effect", ""))
		last_outcome = _outcome(false, ch.get("label", ""), ch.get("effect", ""), ch.get("mood", "hurt"), true)
	state = State.DECISION_RESULT
	return last_outcome


## The timer ran out (decision or action).
func timeout() -> Dictionary:
	match state:
		State.DECISION:
			_add_strike("(no decision)", HESITATE_EFFECT)
			last_outcome = _outcome(false, "(no decision)", HESITATE_EFFECT, "hurt", true)
			last_outcome["timeout"] = true
			state = State.DECISION_RESULT
			return last_outcome
		State.ACTION:
			_add_strike(str(current_action().get("title", "procedure")), ACTION_TIMEOUT_EFFECT)
			last_outcome = _outcome(false, "(not finished)", ACTION_TIMEOUT_EFFECT, "hurt", true)
			last_outcome["timeout"] = true
			state = State.TIMEOUT_RESULT
			return last_outcome
	return {}


## A wrong procedure picked inside an action (e.g. toothpaste on a burn). Costs a strike.
func action_strike(label: String, effect: String) -> Dictionary:
	if state != State.ACTION:
		return {}
	_add_strike(label, effect)
	score -= penalty
	last_outcome = _outcome(false, label, effect, "hurt", true)
	state = State.STRIKE_RESULT
	return last_outcome


## A technique slip (wrong wipe direction, let go too early...). Points only, no strike.
func action_technique_error() -> bool:
	if state != State.ACTION:
		return false
	technique_errors += 1
	incorrect += 1
	score -= penalty
	return true


func action_done(success_text: String = "") -> Dictionary:
	if state != State.ACTION:
		return {}
	score += POINTS
	correct += 1
	last_outcome = _outcome(true, str(current_action().get("title", "")), success_text, "happy", false)
	state = State.ACTION_RESULT
	return last_outcome


## Leave a *_RESULT state. Returns the new state.
func proceed() -> State:
	match state:
		State.DECISION_RESULT:
			if strikes >= MAX_STRIKES:
				state = State.FAILED
			elif current_actions().size() > 0:
				action_idx = 0
				state = State.ACTION
			else:
				_next_scene()
		State.STRIKE_RESULT:
			state = State.FAILED if strikes >= MAX_STRIKES else State.ACTION
		State.ACTION_RESULT:
			action_idx += 1
			if action_idx < current_actions().size():
				state = State.ACTION
			else:
				_next_scene()
		State.TIMEOUT_RESULT:
			if strikes >= MAX_STRIKES:
				state = State.FAILED
			else:
				_next_scene()   # skip the rest of this scene: always moves forward
	return state


# ------------------------------------------------------------------ internals

func _next_scene() -> void:
	scene_idx += 1
	action_idx = 0
	state = State.COMPLETE if scene_idx >= scenes.size() else State.DECISION


func _add_strike(chosen: String, effect: String) -> void:
	strikes = mini(strikes + 1, MAX_STRIKES)
	incorrect += 1
	mistakes_log.append({
		"scene": str(current_scene().get("title", "")),
		"chosen": chosen,
		"effect": effect,
		"correct_procedure": str(correct_choice().get("label", "")),
	})


func _outcome(ok: bool, chosen: String, effect: String, mood: String, strike: bool) -> Dictionary:
	return {
		"correct": ok,
		"chosen": chosen,
		"effect": effect,
		"mood": mood,
		"strike": strike,
		"strikes": strikes,
		"failed_now": strikes >= MAX_STRIKES,
		"correct_procedure": str(correct_choice().get("label", "")),
	}

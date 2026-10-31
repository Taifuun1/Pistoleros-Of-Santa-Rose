extends RefCounted
class_name ModalPauseCoordinator

## Shared modal/pause ownership (Docs/System Design/Journal/Journal.md):
## modals acquire the tree pause through one coordinator instead of toggling
## get_tree().paused directly, so stacked modals never unpause each other and
## a game paused for another reason stays paused after the last modal closes.

var _tree: SceneTree
var _owners: Array = []
var _pausedBeforeFirstAcquire := false


func _init(tree: SceneTree) -> void:
	_tree = tree


func acquirePause(pauseOwner: Object) -> void:
	if _owners.has(pauseOwner):
		return
	if _owners.is_empty():
		_pausedBeforeFirstAcquire = _tree.paused
		_tree.paused = true
	_owners.append(pauseOwner)


func releasePause(pauseOwner: Object) -> void:
	if !_owners.has(pauseOwner):
		return
	_owners.erase(pauseOwner)
	if _owners.is_empty():
		_tree.paused = _pausedBeforeFirstAcquire


func hasPauseOwner(pauseOwner: Object) -> bool:
	return _owners.has(pauseOwner)
class_name ShootoutEnemyAI
extends RefCounted


func chooseTarget(shootoutActors: Dictionary) -> String:
	var targets = shootoutActors[Shootout.TEAM_PLAYER].keys()
	if targets.is_empty():
		return ""
	return targets[randi() % targets.size()]

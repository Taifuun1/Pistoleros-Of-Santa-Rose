extends Node2D

@onready var waveFunctionCollapse = preload("res://Location/Location Generation/Wave Function Collapse/WaveFunctionCollapse.tscn")


func generateChunk(input: String, generatedChunkPosition: Vector2i):
	if get_child_count() == 0:
		var waveFunctionCollapseInstance = waveFunctionCollapse.instantiate()
		waveFunctionCollapseInstance.selectInputSet(input)
		add_child(waveFunctionCollapseInstance)
	$WaveFunctionCollapse.generateChunk(generatedChunkPosition)

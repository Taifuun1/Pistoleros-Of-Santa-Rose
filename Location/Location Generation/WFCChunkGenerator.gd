extends Node2D

@onready var waveFunctionCollapse = preload("res://Location/Location Generation/WaveFunctionCollapse.tscn")


func generateChunk(input: String):
	$WFCInputCreation.addInputs(input)
	WaveFunctionCollapse.inputs[input] = $WFCInputCreation.assignInputsForInputSet()
	$WFCInputCreation.removeInputs()
	
	var waveFunctionCollapseInstance = waveFunctionCollapse.instantiate()
	waveFunctionCollapseInstance.name = "WFC"
	waveFunctionCollapseInstance.selectInputSet(input)
	add_child(waveFunctionCollapseInstance)
	$WFC.generateChunk(Vector2i(0,0))

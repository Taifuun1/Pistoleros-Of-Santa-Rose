extends Node2D

## Thin, synchronous adapter around WFCSolver.
##
## The heavy input processing was already done once on the main thread
## (WFCInputCreation -> WaveFunctionCollapse.models). Here we just build a
## per-chunk solver and run it to completion. This is called from
## LocationGeneration on its sub-thread process group, so the whole collapse
## runs off the main thread with no per-frame stepping and no shared mutable
## state between generators.


func generateChunk(input: String, generatedChunkPosition: Vector2i) -> Dictionary:
	var model: WFCModel = WaveFunctionCollapse.models[input]
	var chunkSeed := WFCSolver.makeSeed(input, generatedChunkPosition, WaveFunctionCollapse.baseSeed)
	var solver := WFCSolver.new(model, WaveFunctionCollapse.gridSize, chunkSeed)
	return solver.run()

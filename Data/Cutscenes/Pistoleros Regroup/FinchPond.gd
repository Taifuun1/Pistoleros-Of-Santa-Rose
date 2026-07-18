var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Pistoleros Regroup",
		"location": "Finch Pond"
	},
	"nextLocation": {
		"location": "Finch Pond",
		"playerPosition": Vector2i(275, 475)
	},
	"initialCameraPosition": Vector2i(275, 475),
	"actors": [
		{
			"name": "Walker Langley",
			"type": "Named People",
			"position": Vector2i(275, 475)
		}
	],
	"shots": [
		# Move the camera to the scene position.
		{
			"object": "camera",
			"data": {
				"position": Vector2i(275, 475)
			}
		},
		# Wait a moment before anything happens.
		{
			"object": "wait",
			"data": {
				"time": 1.5
			}
		},
		# Set Walker to a looping idle animation (non-blocking — next shot runs immediately).
		{
			"object": "animation",
			"data": {
				"blocking": false,
				"animations": [
					{ "actor": "Walker Langley", "animation": "Idle" }
				]
			}
		},
		# Trigger a background dust/atmosphere particle effect in the setting scene (non-blocking).
		# Expects a GPUParticles2D or CPUParticles2D node named "AmbientDust" inside the location scene.
		{
			"object": "particles",
			"data": {
				"source": "setting",
				"node": "AmbientDust",
				"blocking": false
			}
		},
		# Wait for the scene to breathe before Walker stirs.
		{
			"object": "wait",
			"data": {
				"time": 1.5
			}
		},
		# Walker plays a one-shot "Snap" animation (blocking — wait for it to finish).
		{
			"object": "animation",
			"data": {
				"blocking": true,
				"animations": [
					{ "actor": "Walker Langley", "animation": "Snap" }
				]
			}
		},
		# After the snap, switch Walker to a looping revolver idle (non-blocking).
		{
			"object": "animation",
			"data": {
				"blocking": false,
				"animations": [
					{ "actor": "Walker Langley", "animation": "Idle Revolver" }
				]
			}
		},
		# Walker walks forward toward the pond (blocking move — wait until he arrives).
		{
			"object": "move",
			"data": {
				"blocking": true,
				"duration": 1.5,
				"moves": [
					{ "actor": "Walker Langley", "position": Vector2i(275, 440) }
				]
			}
		},
		# Walker fires his revolver (blocking one-shot animation).
		{
			"object": "animation",
			"data": {
				"blocking": true,
				"animations": [
					{ "actor": "Walker Langley", "animation": "Shoot Revolver" }
				]
			}
		},
		# Trigger a muzzle flash particle attached to Walker's actor node (non-blocking).
		# Expects a GPUParticles2D or CPUParticles2D node named "MuzzleFlash" as a child
		# of the Walker Langley animations node.
		{
			"object": "particles",
			"data": {
				"source": "actor",
				"actor": "Walker Langley",
				"node": "MuzzleFlash",
				"blocking": false
			}
		},
		# Walker returns to looping idle revolver while dialog plays (non-blocking).
		{
			"object": "animation",
			"data": {
				"blocking": false,
				"animations": [
					{ "actor": "Walker Langley", "animation": "Idle Revolver" }
				]
			}
		},
		# Dialog plays while Walker holds his revolver idle loop.
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "Ugghhhh..."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "What happened... I can't remember..."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "There was piles of cash... and a chase..."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "I remember... flashes of light. Gunfire."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "What happened to the bags of cash? Ahhh..."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "I got to find Gwyneth. Where is she?"
			}
		}
	]
}

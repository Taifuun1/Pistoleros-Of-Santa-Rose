# Player Reveal Shader System

This shader system makes sprites transparent in a circle around the player character when the player is behind objects in the game world. This helps players see their character when they're behind trees, buildings, or other obstacles.

## How It Works

The system consists of:
1. **PlayerReveal.gdshader** - The shader that creates the transparency effect
2. **PlayerRevealController.gd** - Manages the shader and updates player position
3. **RevealableObject.gd** - Optional component to mark objects as revealable

## Features

- Creates a circular transparency area around the player
- Only affects objects in the "revealable" group
- Configurable radius, softness, and minimum alpha
- Works with Sprite2D, AnimatedSprite2D, and TileMap nodes
- Does NOT affect other characters (actors)

## Setup

### 1. Automatic Setup (Already Done)

The ClearwaterGrove scene has been updated with:
- PlayerRevealController node added to Entities
- LocationMap.gd initializes the controller with the player

### 2. Mark Objects as Revealable

There are two ways to make objects revealable:

#### Method A: Using the "revealable" Group (Recommended)

Add objects to the "revealable" group in the editor:
1. Select the object in the scene
2. In the Inspector, find "Groups"
3. Click "Manage Groups"
4. Add the group "revealable"

Or via code:
```gdscript
# Add to _ready() of your object
add_to_group("revealable")
```

#### Method B: Using the RevealableObject Component

Attach the `RevealableObject.gd` script to any object:
1. Select the object
2. In the Inspector, click "Attach Script"
3. Choose `res://Shaders/Revealable.gd`
4. Configure the exported properties if needed

### 3. For Interactables and Outdoor Objects

The Interactable and OutdoorObjects nodes should have their children marked as revealable. You can do this by:

1. Adding the "revealable" group to each child sprite
2. Or modifying the spawn code to add the group automatically

Example for ChunkProcessor.gd when spawning objects:
```gdscript
# When creating an interactable
var interactable = interactable_scene.instantiate()
interactable.add_to_group("revealable")  # Add this line
$"../../Entities/Interactables".add_child(interactable)
```

## Configuration

### Shader Parameters (per material)

These can be adjusted in the Inspector when you select a revealable object:

- **player_reveal_position** (vec2) - Center of the rendered player sprite; updated automatically
- **reveal_radius** (float, 0-500) - Size of the transparency circle (default: 80)
- **reveal_softness** (float, 0-100) - Edge feathering (default: 10)
- **min_alpha** (float, 0-1) - Minimum transparency (default: 0.0). Keep at zero
  when revealable sprites overlap, otherwise their residual alpha accumulates.
- **enabled** (bool) - Toggle the effect on/off (default: true)

### Controller Properties (runtime)

Access the controller to adjust settings at runtime:

```gdscript
var controller = $Entities/PlayerRevealController

# Adjust settings
controller.reveal_radius = 100.0      # Larger reveal area
controller.reveal_softness = 20.0     # Softer edges
controller.min_alpha = 0.1              # More transparent
controller.enabled = false              # Disable effect
```

## How to Add to Other Locations

If you have other location scenes, add the PlayerRevealController:

1. Open your location scene (e.g., `AnotherLocation.tscn`)
2. Add a child node to Entities:
   - Type: Node2D
   - Name: PlayerRevealController
   - Script: `res://Shaders/PlayerRevealController.gd`
3. In your location's main script (e.g., `AnotherLocation.gd`), add to `_ready()`:
   ```gdscript
   var reveal_controller = $Entities/PlayerRevealController
   if reveal_controller != null:
       reveal_controller.init($Entities/Actors/PlayerActor)
   ```

## Important Notes

- The shader applies a complete radial mask to revealable sprites around the player.
- Scene Y-sorting determines which sprites are drawn in front of the player; the
  shader does not use sprite origins to clip the circle.
- Characters (Actors) are NOT affected - only objects in the "revealable" group
- The effect is applied per-material, so each revealable object gets its own material instance
- The controller updates player position every frame in `_process()`

## Troubleshooting

**Objects aren't becoming transparent:**
- Make sure the object is in the "revealable" group
- Check that the PlayerRevealController is initialized with the player
- Verify the shader material is applied (check in Inspector)
- For dynamically spawned objects (trees, interactables), ensure the material is applied after spawning

**Effect is too strong/weak:**
- Adjust `reveal_radius` - larger values = bigger transparent area
- Adjust `min_alpha` - lower values = more transparent (0 = invisible, 1 = opaque)
- Adjust `reveal_softness` - higher values = softer edges

**Performance concerns:**
- The shader runs on the GPU and is generally fast
- Each revealable object gets its own material instance
- If you have many objects, consider using TileMap layers instead of individual sprites

**Trees not working:**
- Trees are StaticBody2D nodes with Sprite2D children
- The controller automatically finds child sprites and applies materials
- Make sure trees are added to the "revealable" group AND the material is applied via `reveal_controller._apply_material_to_node(tree)`

## Files Created

- `Shaders/PlayerReveal.gdshader` - The shader code
- `Shaders/PlayerRevealController.gd` - Controller script
- `Shaders/PlayerRevealController.tscn` - Controller scene
- `Shaders/RevealableObject.gd` - Optional component script
- `Shaders/README_PlayerReveal.md` - This documentation

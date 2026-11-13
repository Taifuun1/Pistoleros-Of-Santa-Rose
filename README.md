# Pistoleros-Of-Santa-Rose

## Development

Use the standard (non-.NET) **Godot 4.7** editor. Import resources before running
the headless tests or exporting from a fresh checkout:

```sh
godot --headless --path . --import
godot --headless --path . --script res://Tests/RunAll.gd
```

To run a subset of tests, pass case-insensitive name filters after `--`:

```sh
godot --headless --path . --script res://Tests/RunAll.gd -- Music Targeting
```

## Exports

Install the Godot 4.7 export templates through **Editor > Manage Export
Templates**. All presets in `export_presets.cfg` write into `build/`, which is
git-ignored:

| Preset | Output |
|---|---|
| `Linux` | `build/linux/PistolerosOfSantaRose.x86_64` |
| `Windows Desktop` | `build/windows/PistolerosOfSantaRose.exe` (+ `.pck`) |

Linux release build:

```sh
godot --headless --path . --export-release Linux build/linux/PistolerosOfSantaRose.x86_64
```

Windows release build:

```sh
godot --headless --path . --export-release "Windows Desktop" build/windows/PistolerosOfSantaRose.exe
```

The executable and its `.pck` file are written to the preset's `build/<platform>/`
directory — never the project root. The `build/linux` and `build/windows` folders
are kept in the repository (via `.gitkeep`) because Godot refuses to export into a
directory that does not exist. GitHub Actions runs the same import, test, and
export steps on pull requests and pushes to `main`, and uploads the Linux build as
a workflow artifact.

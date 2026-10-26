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

## Linux release build

Install the Godot 4.7 export templates through **Editor > Manage Export
Templates**, then run:

```sh
mkdir -p build/linux
godot --headless --path . --export-release Linux build/linux/PistolerosOfSantaRose.x86_64
```

The executable and its `.pck` file are written to `build/linux/`. GitHub Actions
runs the same import, test, and export steps on pull requests and pushes to
`main`, and uploads the Linux build as a workflow artifact.

# The Flutter App

Desktop UI for the V1 vertical slice.

Whenever you modify the files in this folder, please update the description below.

## What This App Does

- Launches the Rust analyzer in `../../core` using `cargo run --quiet`
- Reads JSON recommendations from stdout
- Displays top 3 pickup options with mode and ETA breakdown

## Run

```bash
cd app/flutter
flutter run -d linux
```

If `AMAP_KEY` is available in the shell environment, the Rust analyzer will call Amap APIs. Otherwise, the analyzer returns fallback ETA estimates.

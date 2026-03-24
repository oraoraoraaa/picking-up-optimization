# The Rust Core

The core RUST implementation like domain, optimization engine, scoring, route fusion, caching policy, etc. should be put in this directory.

## Vertical Slice Entry Point

The first vertical slice prototype lives in `src/main.rs`.

It currently does the following:

- Uses hardcoded passenger/driver + pickup candidate locations
- Fetches route durations from Amap for driving/walking/bicycle/transit when `AMAP_KEY` is available
- Applies simple scoring (`driver_eta + passenger_eta`)
- Ranks and returns the top 3 recommendations as JSON
- Falls back to deterministic ETA estimates when API calls are unavailable

Run it with:

```bash
cd core
cargo run --quiet
```

Optional key setup:

```bash
export AMAP_KEY="your_amap_web_service_key"
```

## Contributor Rule

1. Make sure you fully understand where you should modify or add new files.

2. Be 100% clear about how your incoming changes are working with the current related code.

3. Write proper documentation describing your modification, and how it works with the current code in proper place (comments, PRs, etc.).

4. If an appropriate category folder does not exist, create a new one for your code and add a README.md that follows the same guidance style.

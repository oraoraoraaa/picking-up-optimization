# Architecture Decision Records

## ADR-001: Project Architecture

### Status: LOCKED

- **app/**: Contains all application code. Platform-specific subfolders (e.g., `flutter/`) hold the source code for each client or interface.
  - **app/flutter/**: Main Flutter app, with standard Flutter structure (lib/, android/, ios/, web/, etc.).
- **core/**: Contains core logic, libraries, and backend code written in Rust.
- **docs/**: Project documentation, guidelines, plans, and architecture decision records (ADRs).
  - **docs/adr/**: All ADRs are stored here, including this file.
- **resource/**: Static resources such as images, icons, banners, and related documentation.

# Architecture Decision Records

## ADR-001: Project Architecture

### Status: LOCKED

### Context

To maintain clarity and scalability, the project directory structure is organized by function and responsibility. This ADR documents where different types of files and resources are placed.

### Decision

- **app/**: Contains all application code. Platform-specific subfolders (e.g., `flutter/`) hold the source code for each client or interface.
  - **app/flutter/**: Main Flutter app, with standard Flutter structure (lib/, android/, ios/, web/, etc.).
- **core/**: Contains core logic, libraries, or backend code (e.g., Rust, Python, etc.).
- **docs/**: Project documentation, guidelines, plans, and architecture decision records (ADRs).
  - **docs/adr/**: All ADRs are stored here, including this file.
- **resource/**: Static resources such as images, icons, banners, and related documentation.

### Consequences

- Contributors can easily locate code, documentation, and resources.
- The structure supports multi-platform development and clear separation of concerns.
- New modules or platforms can be added by creating new subfolders under `app/` or other relevant directories.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PineFlash is a cross-platform GUI tool for flashing IronOS firmware to Pine64 soldering irons (Pinecil V1 and V2). Built with Rust using the egui/eframe GUI framework.

## Build Commands

```bash
# Development build
cargo build

# Release build
cargo build --release

# Build for Linux AppImage (includes bundled tools)
cargo build --release --features appimage

# Run
cargo run --release

# Check for errors
cargo check

# Lint
cargo clippy
```

## Architecture

The application follows a single-struct state machine pattern centered around the `Flasher` struct in `main.rs`:

```
src/
├── main.rs                    # Entry point, Flasher struct, eframe::App impl, main update loop
└── submodules/
    ├── mod.rs                 # Module exports
    ├── connection_poller.rs   # USB device detection (Pinecil V1 via rusb, V2 via serial)
    ├── flash.rs               # Firmware flashing logic (dfu-util for V1, blisp for V2)
    ├── main_panel.rs          # Main UI panel (iron selection, version picker, language, flash button)
    ├── top_panel.rs           # Header bar with dark mode toggle
    └── fonts.rs               # Font configuration
```

### Key Components

**FlasherConfig** - Runtime state including:
- Device selection (`iron`, `int_name`)
- Firmware version and language
- Download/flash progress flags
- USB connection state (`iron_connected`, `v2_serial_path`)

**FlashSavedConfig** - Persisted settings (via `confy` crate)

### External Tool Dependencies

The app shells out to external flashing tools:
- **Pinecil V1**: `dfu-util` (DFU protocol over USB)
- **Pinecil V2**: `blisp` (BL70x serial protocol) - source included as git submodule

On Linux, `pkexec` is used for privilege escalation. On Windows, tools are expected in a `tools/` directory alongside the executable.

### Git Submodule

The `blisp` directory is a git submodule pointing to [pine64/blisp](https://github.com/pine64/blisp). After cloning:

```bash
git submodule update --init --recursive
```

The install script (`generic_unix_install.sh`) downloads prebuilt blisp binaries for supported platforms, falling back to building from source for unsupported architectures.

### Data Flow

1. App fetches IronOS release metadata from GitHub API on startup
2. User selects iron type, firmware version, and language
3. Firmware ZIP downloaded to temp directory, extracted
4. Connection poller detects device via USB (V1: vendor/product ID `10473:393`, V2: serial number containing `000000020000`)
5. Flash command executed with appropriate tool

### Platform-Specific Code

Heavy use of `#[cfg(...)]` attributes for platform differences:
- `target_os = "linux"`, `target_os = "macos"`, `target_os = "windows"`
- `target_family = "unix"`, `target_family = "windows"`
- `feature = "appimage"` for Linux AppImage builds with bundled tools

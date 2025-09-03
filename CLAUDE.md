# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

locgen-swift is a Swift command-line tool that generates iOS *.strings translation files from online Excel sheets. It downloads XLSX files (from URLs or local paths), parses them according to a YAML configuration map, and generates localized .strings files for iOS projects.

## Commands

### Building and Development
- `make` - Build release version (creates `.build/release/locgen-swift`)
- `make install` - Install built executable to /usr/local/bin
- `make clean` - Remove .build directory
- `swift build` - Standard Swift Package Manager build
- `swift test` - Run tests

### Running the Tool
```
locgen-swift --input "path/to/file.xlsx" --sheets "Sheet 1" --map "map.yml"
```
All parameters are required:
- `--input`: URL or local path to XLSX file
- `--sheets`: Sheet name(s) with translations
- `--map`: Path to YAML configuration file

## Architecture

### Core Components

**main.swift**: Entry point using ArgumentParser for CLI options. Handles error display and help messages.

**LocgenTask.swift**: Main orchestrator that:
- Validates input parameters
- Downloads remote files or reads local files
- Coordinates XLSX parsing with YAML configuration
- Uses DispatchQueue for async operations

**ParserXLSX.swift**: Core parsing logic that:
- Reads XLSX using CoreXLSX library
- Maps columns based on YAML configuration
- Generates .strings files in appropriate .lproj directories
- Handles file creation and directory structure

**Config.swift**: Configuration model for YAML mapping file structure

**DownloadManager.swift**: Handles downloading remote files with URLSession

### Key Dependencies
- **CoreXLSX**: XLSX file parsing
- **ArgumentParser**: Command-line argument handling  
- **Yams**: YAML parsing for configuration files

### Configuration Structure (map.yml)
The YAML configuration defines:
- `key`: Column name containing translation keys
- `languages`: Maps language codes to XLSX column names
- `dirs`: Optional custom directory paths for specific languages
- `names`: Optional custom filenames for specific languages

### Output Structure
Generates iOS localization files:
- Default: `{language}.lproj/Localizable.strings`
- Custom paths configurable per language in YAML
- Format: `"key" = "translation";`
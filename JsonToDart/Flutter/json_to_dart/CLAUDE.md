# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application that converts JSON to Dart code. The app provides a web-based interface where users can paste JSON, configure generation options, and receive formatted Dart class definitions.

## Development Commands

### Run the application
```bash
flutter run -d chrome  # Run on web browser
flutter run            # Run on default device
```

### Build
```bash
flutter build web      # Build for web
flutter build apk      # Build for Android
flutter build ios      # Build for iOS
flutter build macos    # Build for macOS
flutter build linux    # Build for Linux
flutter build windows  # Build for Windows
```

### Code generation
```bash
# Generate code for Hive adapters and other generated files
dart run build_runner build --delete-conflicting-outputs
```

### Analyze and lint
```bash
flutter analyze        # Run static analysis
```

### Dependencies
```bash
flutter pub get        # Install dependencies
flutter pub upgrade    # Upgrade dependencies
```

## Architecture

### State Management
- Uses **GetX** (`get` package) for state management and dependency injection
- `MainController` (lib/main_controller.dart) is the primary controller, registered globally via `Get.put()`
- All reactive state uses GetX observables (`.obs`) and `Rx` types

### Core JSON to Dart Conversion
- The actual conversion logic is in the **`json_to_dart_library`** package (external dependency at version ^0.0.7)
- `MainController` extends `JsonToDartControllerMixin` from the library
- Custom implementations extend library classes:
  - `FFDartObject` extends `DartObject` with UI-specific reactive properties
  - `FFDartProperty` extends `DartProperty` with UI-specific features
  - `FFJsonToDartConfig` implements `JsonToDartConfig` to bridge app settings with the library

### Configuration and Persistence
- `ConfigSetting` (lib/models/config.dart) is a singleton that manages app settings
- Uses **Hive** for local storage persistence of user preferences
- Settings are reactive (using GetX `Rx` types) and automatically saved
- Custom `RxTypeAdapter<T>` handles serialization of GetX reactive types for Hive

### Localization
- Uses Flutter's built-in localization with `flutter_localizations`
- Generated localization files in lib/l10n/
- Configured via l10n.yaml
- Supports English (en) and Chinese (zh)
- Access via `appLocalizations` getter in main_controller.dart

### UI Structure
The main screen has a two-column layout with a draggable divider:

**Left column** (lib/pages/json_text_field.dart):
- JSON input text field
- Settings panel (lib/pages/setting.dart)

**Right column**:
- JSON tree header (lib/pages/json_tree_header.dart)
- JSON tree view (lib/pages/json_tree.dart) showing parsed structure
- Individual tree items (lib/pages/json_tree_item.dart)

**Draggable divider** (lib/widget/drag_icon.dart):
- Allows resizing columns
- Column widths persisted in ConfigSetting

### Code Generation Flow
1. User inputs JSON in `JsonTextField`
2. `MainController.formatJsonAndCreateDartObject()` parses JSON (uses `compute` for async processing)
3. Creates `DartObject` tree structure via `dynamicToDartObject()`
4. Validates class names, property names, handles nullability
5. `generateDartCode()` converts to Dart code string
6. Uses `dart_style` package's `DartFormatter` to format output
7. Copies result to clipboard automatically
8. Shows result in dialog if `showResultDialog` is enabled

### Error Handling
- Custom `ClassNameCheckerTextEditingController` (lib/utils/error_check/) validates input
- Errors are tracked reactively in `_classError` and `_propertyError` sets on objects
- `handleError()` in MainController shows error dialogs and copies stack traces to clipboard

### Special Features
- **JSON Schema support**: Detects and converts JSON Schema to sample JSON
- **Smart nullable detection**: Analyzes JSON to determine nullability
- **Array protection**: Wraps array access in try-catch
- **Data protection**: Adds null/type checking in generated code
- **Multiple naming conventions**: camelCase, PascalCase, snake_case, etc.
- **Property sorting**: Alphabetical or by appearance order
- **Equality methods**: Generate `==` and `hashCode` (official, dart-lang/sdk, or equatable package)
- **Copy methods**: Generate `copyWith()` methods

## File Structure Highlights

- **lib/models/** - Data models (Config, DartObject, DartProperty, FFConfig)
- **lib/pages/** - UI pages and widgets for the main interface
- **lib/widget/** - Reusable widgets (buttons, checkboxes, pickers)
- **lib/style/** - Color, size, and text style constants
- **lib/utils/** - Utilities including custom error-checking text controllers
- **lib/collection/** - Extensions for List and Map types
- **lib/l10n/** - Generated localization files

## Important Notes

- The app works on web with a special fix for Dart SDK issue #34105 (replaces `.0` with `.1` in JSON)
- Generated code files (*.g.dart) are excluded from analysis via analysis_options.yaml
- The project enforces strict linting rules (always_specify_types, implicit-casts: false, etc.)
- When modifying config models, regenerate with `dart run build_runner build --delete-conflicting-outputs`
- All UI updates must call `update()` on controllers to trigger GetX rebuilds
- The library is registered globally via `registerConfig()` and `registerController()` in main.dart

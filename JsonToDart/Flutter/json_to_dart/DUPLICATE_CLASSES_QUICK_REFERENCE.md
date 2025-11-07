# Duplicate Classes Error - Quick Reference Guide

## What is "Duplicate Classes" Error?
An error that occurs when multiple class objects in a JSON structure have the same class name assigned to them.

## Where the Error Message is Used

### 1. Error Message Definition
```
File: /Users/wells/Documents/Git2022/WHJsonToDart/JsonToDart/Flutter/json_to_dart/lib/l10n/app_en.arb
Line: 43
Message: "There are duplicate classes"

File: /Users/wells/Documents/Git2022/WHJsonToDart/JsonToDart/Flutter/json_to_dart/lib/l10n/app_zh.arb
Line: 43
Message: "包含重复的类"
```

### 2. Configuration Bridge
```
File: /Users/wells/Documents/Git2022/WHJsonToDart/JsonToDart/Flutter/json_to_dart/lib/models/ff_config.dart
Lines: 124
Property: duplicateClasses
Bridge: appLocalizations.duplicateClasses → json_to_dart_library
```

## How Duplicates are Detected

### Detection Trigger Location
```
File: /Users/wells/Documents/Git2022/WHJsonToDart/JsonToDart/Flutter/json_to_dart/lib/pages/json_tree_item.dart
Lines: 260-264
Function: ClassNameTextField.onChanged()
Code:
  onChanged: (String value) {
    if (property.className != value) {
      property.className = value;
      property.checkError(property.className);  // <-- TRIGGER
    }
  }
```

### Detection Logic Location
**External:** `json_to_dart_library` package (version ^0.0.7)
- Method: `DartObject.checkError(String className)`
- Behavior:
  - Iterates through `allObjects` list
  - Compares each object's className
  - If duplicate found: adds error to `_classError` set

### Error Storage Locations
```
File: /Users/wells/Documents/Git2022/WHJsonToDart/JsonToDart/Flutter/json_to_dart/lib/models/dart_object.dart
Class: FFDartObjectMixin
Property: _classError
Type: RxSet<String>  (GetX observable)

File: /Users/wells/Documents/Git2022/WHJsonToDart/JsonToDart/Flutter/json_to_dart/lib/models/dart_property.dart
Class: FFDartPropertyMixin
Property: _propertyError
Type: RxSet<String>  (GetX observable)
```

## How It's Handled

### UI Display (Error Feedback)
```
File: /Users/wells/Documents/Git2022/WHJsonToDart/JsonToDart/Flutter/json_to_dart/lib/pages/json_tree_item.dart
Class: ClassNameTextField
Lines: 241-251
Display:
  - Red Icon: When hasClassError == true
  - Blue Icon: When hasClassError == false
  - Tooltip: Shows all error messages from classError set
```

### Code Generation Prevention
```
File: /Users/wells/Documents/Git2022/WHJsonToDart/JsonToDart/Flutter/json_to_dart/lib/main_controller.dart
Function: generateDartCode()
Lines: 134-142
Check:
  final DartObject? errorObject = allObjects.firstOrNullWhere(
    (DartObject element) =>
      element.hasClassError ||  // <-- Checks for duplicate class errors
      element.hasPropertyError
  );
  if (errorObject != null) {
    showAlertDialog(errorObject.classError.join('\n'));
    return null;  // Blocks code generation
  }
```

## Global State Management

```
File: /Users/wells/Documents/Git2022/WHJsonToDart/JsonToDart/Flutter/json_to_dart/lib/main_controller.dart
Class: MainController
Mixin: JsonToDartControllerMixin
Global Lists:
  - allObjects: List<DartObject>      // All class objects created from JSON
  - allProperties: List<DartProperty> // All properties of those objects

Lifecycle:
  1. formatJsonAndCreateDartObject() -> clears allObjects
  2. dynamicToDartObject() -> populates allObjects
  3. User changes class name -> checkError() searches allObjects
  4. generateDartCode() -> searches allObjects for errors
```

## Quick Lookup Table

| Component | File | Location | Purpose |
|-----------|------|----------|---------|
| Error Message (EN) | `app_en.arb` | Line 43 | "There are duplicate classes" |
| Error Message (ZH) | `app_zh.arb` | Line 43 | "包含重复的类" |
| Config Bridge | `ff_config.dart` | Line 124 | `duplicateClasses` getter |
| Error Storage (Class) | `dart_object.dart` | Line 36 | `_classError: RxSet<String>` |
| Error Storage (Property) | `dart_property.dart` | Line 69 | `_propertyError: RxSet<String>` |
| Detection Trigger | `json_tree_item.dart` | Line 263 | `property.checkError()` call |
| Error Display | `json_tree_item.dart` | Lines 241-251 | `ClassNameTextField` icon |
| Generation Gate | `main_controller.dart` | Lines 134-142 | `hasClassError` check |
| Global State | `main_controller.dart` | Lines 62-63 | `allObjects.clear()` |

## Dependencies

- **json_to_dart_library**: ^0.0.7
  - Provides: `DartObject.checkError()` method
  - Provides: `JsonToDartControllerMixin`
  - Provides: `allObjects` and `allProperties` lists

- **get**: any
  - Provides: GetX state management and reactivity (`.obs`)
  - Used: `RxSet<String>` for error storage

## Example Flow

```
User Input: Changes class name from "User" to "User" (duplicate exists)
    ↓
Trigger: onChanged handler in ClassNameTextField
    ↓
Action: property.checkError("User")
    ↓
Library: Searches allObjects for duplicate "User" class names
    ↓
Result: Duplicate found, error message added to _classError
    ↓
Reactivity: Obx wrapper detects change, rebuilds UI
    ↓
Visual: Icon turns red, tooltip shows "There are duplicate classes"
    ↓
Prevention: When Generate clicked, generateDartCode() blocks execution
    ↓
User: Sees error alert, must fix duplicate class names before generating
```

## Testing Checklist

- [ ] Localization strings exist in all ARB files
- [ ] `FFJsonToDartConfig.duplicateClasses` returns correct localized string
- [ ] `FFDartObject` has `_classError` RxSet
- [ ] `ClassNameTextField` displays red icon on error
- [ ] `ClassNameTextField` shows tooltip with error message
- [ ] `generateDartCode()` blocks if `hasClassError == true`
- [ ] Error message is cleared when duplicate is resolved
- [ ] Multiple class names can be unique without triggering error

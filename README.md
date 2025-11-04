# import_ozempic

A Dart command-line tool that automatically organizes and cleans up imports in your Dart projects.

## Features

- **Automatic Import Organization**: Groups imports into three categories in the correct order:
  1. Dart core libraries (`dart:*`)
  2. Package imports (`package:*`)
  3. Relative imports
- **Unused Import Removal**: Detects and removes unused imports using Dart's analyzer
- **Multi-file Processing**: Process individual files, multiple files, or entire directories
- **Configurable Exclusions**: Support for excluding specific files or glob patterns via configuration
- **Part File Support**: Correctly handles Dart libraries with part files

## Installation

Add `import_ozempic` to your `pubspec.yaml`:

```yaml
dev_dependencies:
  import_ozempic: <version>
```

Or activate it globally:

```bash
dart pub global activate import_ozempic
```

## Usage

### Basic Usage

Fix imports in a single file:

```bash
import_ozempic fix lib/main.dart
```

Or use the shorter `ioz` alias:

```bash
ioz fix lib/main.dart
```

Fix imports in multiple files:

```bash
import_ozempic fix lib/main.dart lib/utils.dart
```

Fix imports in an entire directory:

```bash
import_ozempic fix .
```

### With Configuration

Create a configuration file (e.g., `import_cleaner.yaml`):

```yaml
exclude:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
  - "**/generated/**"
```

Then run with the config:

```bash
import_ozempic fix . --config import_cleaner.yaml
```

## Configuration

The configuration file supports the following options:

### `exclude`

A list of file paths or glob patterns to exclude from processing. Can be a string or list of strings.

**Example:**

```yaml
exclude:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
  - "lib/generated/**"
  - "test/fixtures/**"
```

### `format_imports`

A boolean flag to control import formatting. When `false` (default), each import statement remains on a single line. When `true`, imports are formatted according to Dart's style guide.

**Example:**

```yaml
format_imports: true
exclude:
  - "**/*.g.dart"
```

## How It Works

1. **Analysis**: Uses Dart's analyzer to parse and understand your code
2. **Reference Collection**: Traverses the AST to collect all type references
3. **Import Resolution**: Determines which imports are needed and categorizes them
4. **Organization**: Rewrites import statements in the correct order with proper grouping
5. **Cleanup**: Runs `dart fix` to remove unused imports and fix related warnings

## Example

**Before:**

```dart
import 'dart:async';

import 'package:project_domain/domain.dart' hide DateFormat;
import 'package:flutter/material.dart' hide Divider, IconButton;
import 'package:flutter/services.dart' hide TextInput;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:provider/provider.dart';
import 'package:select_when/select_when.dart';
```

**After:**

```dart
import 'dart:async' show Completer;

import 'package:project_domain/enums/user_type.dart' show UserType;
import 'package:flutter/src/foundation/key.dart' show Key, ValueKey;
import 'package:flutter/src/painting/edge_insets.dart' show EdgeInsets;
import 'package:flutter/src/widgets/basic.dart' show Builder, Column, Expanded, KeyedSubtree, SizedBox;
import 'package:flutter/src/widgets/framework.dart' show BuildContext, State, StatefulWidget, StatelessWidget, Widget;
import 'package:flutter_bloc/src/bloc_provider.dart' show BlocProvider;
import 'package:formz/formz.dart' show FormzInput, FormzMixin;
import 'package:provider/src/change_notifier_provider.dart' show ChangeNotifierProvider;
import 'package:provider/src/provider.dart' show MultiProvider, Provider, ReadContext, SelectContext;
import 'package:select_when/src/select_when_context.dart' show SelectWhenContext;
```

## Requirements

- Dart SDK: `>=3.8.0 <4.0.0`

## Development

### Running Tests

```bash
dart test
```

### Project Structure

```text
lib/
├── commands/           # Command implementations
│   └── fix_command.dart
├── deps/              # Dependency interfaces for testability
├── domain/            # Core business logic
│   ├── import_type_collector.dart
│   ├── resolved_references.dart
│   └── ...
└── import_ozempic.dart
```

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

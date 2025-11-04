# import_ozempic 💉

**Trim the fat from your Dart imports.**

Is your codebase carrying extra weight from bloated import statements? Time for a transformation! `import_ozempic` helps your Dart projects shed those unused imports and get lean, organized, and healthy.

> ⚠️ **Disclaimer:** These statements have not been evaluated by the FDA. This tool is not intended to diagnose, treat, cure, or prevent any diseases in your codebase. Results may vary. Consult your tech lead before starting any new import regimen.

## Features

- **Automatic Import Organization**: Get your imports in shape! Groups imports into three categories in the correct order:
  1. Dart core libraries (`dart:*`)
  2. Package imports (`package:*`)
  3. Relative imports
- **Unused Import Removal**: Cuts out the excess—detects and removes unused imports that are just adding bulk
- **Multi-file Processing**: Process individual files, multiple files, or give your entire directory a complete makeover
- **Configurable Exclusions**: Some files are already perfect (like generated files)—exclude what you want to keep as-is
- **Part File Support**: Correctly handles Dart libraries with part files—no side effects!

## Installation

Ready to start your import weight-loss journey?

Add `import_ozempic` to your `pubspec.yaml`:

```yaml
dev_dependencies:
  import_ozempic: <version>
```

Or activate it globally for quick access:

```bash
dart pub global activate import_ozempic
```

## Usage

### Basic Usage

Give a single file a quick checkup:

```bash
import_ozempic fix lib/main.dart
```

Or use the shorter `ioz` alias (because who has time for long commands?):

```bash
ioz fix lib/main.dart
```

Treat multiple files at once:

```bash
import_ozempic fix lib/main.dart lib/utils.dart
```

Go for the full transformation—fix an entire directory:

```bash
import_ozempic fix .
```

### With Configuration

Want a personalized treatment plan? Create a configuration file (e.g., `import_cleaner.yaml`):

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

A list of file paths or glob patterns to exclude from processing. Think of these as the files that are already at their ideal weight!

**Example:**

```yaml
exclude:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
  - "lib/generated/**"
  - "test/fixtures/**"
```

### `format_imports`

A boolean flag to control import formatting. When `false` (default), each import statement remains on a single line. When `true`, imports are formatted according to Dart's style guide—for when you want that extra polish!

**Example:**

```yaml
format_imports: true
exclude:
  - "**/*.g.dart"
```

## How It Works

The secret formula for healthy imports:

1. **Analysis**: Uses Dart's analyzer to examine your code (the medical checkup)
2. **Reference Collection**: Traverses the AST to collect all type references (checking vital signs)
3. **Import Resolution**: Determines which imports are actually needed (diagnosis)
4. **Organization**: Rewrites import statements in the correct order with proper grouping (the treatment)
5. **Cleanup**: Runs `dart fix` to remove unused imports and fix related warnings (follow-up care)

## Example

**Before:** Carrying excess baggage 🎒

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

**After:** Lean, precise, and organized 💪

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

Notice how we've eliminated the unnecessary bloat and only import exactly what you need. Your imports just got a lot healthier!

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

Got ideas to make import_ozempic even more effective? Contributions are welcome! Help us trim even more fat from Dart codebases—submit a Pull Request and join the wellness movement! 🏃‍♀️

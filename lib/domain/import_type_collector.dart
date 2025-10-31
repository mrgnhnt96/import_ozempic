import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/ast/ast.dart';

/// Collects all external type references that would require imports.
class ImportTypeCollector extends RecursiveAstVisitor<void> {
  ImportTypeCollector();

  final libraries = <LibraryElement>{};
  // Example: 'dart:math' -> 'math'
  final importPrefixes = <String, String>{};
  final hiddenTypes = <InterfaceType>{};
  final prefixedIdentifiers = <String, List<InterfaceType>>{};

  @override
  void visitImportDirective(ImportDirective node) {
    if (node case ImportDirective(
      libraryImport: LibraryImport(:final importedLibrary?),
      prefix: SimpleIdentifier(element: PrefixElement(:final String name)),
    )) {
      _addImportPrefix(importedLibrary, name);
    }

    for (final combination in node.combinators) {
      switch (combination) {
        case HideCombinator(:final hiddenNames):
          for (final name in hiddenNames) {
            switch (name.element) {
              case ClassElement(:final thisType):
                hiddenTypes.add(thisType);
              case EnumElement(:final instantiate):
                hiddenTypes.add(
                  instantiate(
                    typeArguments: const [],
                    nullabilitySuffix: NullabilitySuffix.none,
                  ),
                );
              case TypeAliasElement(:final library):
                _addLibrary(library);
              case TopLevelVariableElement(:final library):
                _addLibrary(library);
              case TopLevelFunctionElement(:final library):
                _addLibrary(library);
              case MethodElement(:final ExtensionElement enclosingElement):
                _addLibrary(enclosingElement.library);
              case ConstructorElement(:final library):
                _addLibrary(library);
              case FieldElement(:final enclosingElement, isStatic: true):
                _addLibrary(enclosingElement.library);
              default:
                break;
            }
          }
        case ShowCombinator():
      }
    }

    super.visitImportDirective(node);
  }

  @override
  void visitNamedType(NamedType node) {
    switch (node) {
      case NamedType(name: Token(lexeme: 'Future' || 'Stream')):
        break;
      // Example: `Foo`, `List<Bar>`
      case NamedType(:final InterfaceType type, :final typeArguments):
        _addType(type);

        if (typeArguments?.arguments case final args?) {
          for (final arg in args) {
            if (arg case final NamedType arg) {
              visitNamedType(arg);
            }
          }
        }

      /// Example: `VoidCallback`
      case NamedType(:final TypeAliasElement element):
        _addLibrary(element.library);
    }

    super.visitNamedType(node);
  }

  @override
  void visitImportPrefixReference(ImportPrefixReference node) {
    if (node.element case final PrefixElement element) {
      _addNamespace(element);
    }

    super.visitImportPrefixReference(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;

    if (element?.displayName.startsWith('_') case true) {
      super.visitSimpleIdentifier(node);
      return;
    }

    switch (node.element) {
      case ClassElement(:final library):
        _addLibrary(library);
      case PropertyAccessorElement(
        /// Example: `pi`
        :final library,
        variable: TopLevelVariableElement(),
      ):
        _addLibrary(library);

      // Example: `pi`
      case TopLevelVariableElement(:final library):
        _addLibrary(library);

      // Example: `max()`
      case TopLevelFunctionElement(:final library):
        _addLibrary(library);
    }

    super.visitSimpleIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Example: `math.max(1, 2)`
    if (node.target case SimpleIdentifier(:final PrefixElement element)) {
      _addNamespace(element);
    }

    switch (node.methodName.element) {
      /// Example: `context.extensionName(...)`
      case MethodElement(:final ExtensionElement enclosingElement):
        _addLibrary(enclosingElement.library);

      // Example: `Theme.of(context)` or `listEquals(...)`
      case MethodElement(:final enclosingElement, isStatic: true):
      case TopLevelFunctionElement(:final enclosingElement):
        switch (enclosingElement) {
          case LibraryElement(:final library):
            _addLibrary(library);
          case ClassElement(:final thisType):
            _addType(thisType);
          case EnumElement(:final instantiate):
            _addType(
              instantiate(
                typeArguments: const [],
                nullabilitySuffix: NullabilitySuffix.none,
              ),
            );
        }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitConstructorReference(ConstructorReference node) {
    if (node.constructorName.element case ConstructorElement(:final library)) {
      _addLibrary(library);
    }
    super.visitConstructorReference(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    switch (node.prefix) {
      // Example: `math.pi`
      case SimpleIdentifier(:final PrefixElement element):
        if (node.staticType case final InterfaceType type) {
          (prefixedIdentifiers[element.displayName] ??= []).add(type);
        }
        _addNamespace(element);

      // Example: `HttpOverrides.global`
      case SimpleIdentifier(element: ClassElement(:final library)):
        _addLibrary(library);

      // Example: `typedef LogLevel = Level --> LogLevel.info
      case SimpleIdentifier(element: TypeAliasElement(:final library)):
        _addLibrary(library);
    }

    switch (node.identifier.element) {
      // Example: `context.extensionName`
      case ExecutableElement(:final ExtensionElement enclosingElement):
        _addLibrary(enclosingElement.library);

      // Example: `ClassName.staticMethod()` or `ClassName.staticField`
      case ExecutableElement(isStatic: true) || FieldElement(isStatic: true):
        final targetElement = node.prefix.element;
        switch (targetElement) {
          case ClassElement(:final thisType):
            _addType(thisType);
          case MixinElement(:final library):
            _addLibrary(library);
          case EnumElement(:final instantiate):
            _addType(
              instantiate(
                typeArguments: const [],
                nullabilitySuffix: NullabilitySuffix.none,
              ),
            );
        }
    }

    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.element case ExecutableElement(
      enclosingElement: final ExtensionElement e,
    )) {
      _addLibrary(e.library);
      super.visitPropertyAccess(node);
      return;
    }

    // Handles instance property access like `context.foo`
    Element? element;
    PropertyAccess access = node;

    while (element == null) {
      var shouldBreak = false;
      switch (access.realTarget) {
        case PropertyAccess(:final PropertyAccess realTarget):
          access = realTarget;
        case PropertyAccess(:final PrefixedIdentifier realTarget):
          element = realTarget.element?.enclosingElement;
        case PropertyAccess(:final SimpleIdentifier realTarget):
          element = realTarget.element?.enclosingElement;
        case SimpleIdentifier(element: final e):
          element = e;
        case PrefixedIdentifier(
          element: final e?,
          prefix: SimpleIdentifier(element: final PrefixElement prefix),
        ):
          _addNamespace(prefix);

          switch (e) {
            case EnumElement(:final instantiate):
              _addType(
                instantiate(
                  typeArguments: const [],
                  nullabilitySuffix: NullabilitySuffix.none,
                ),
              );
              shouldBreak = true;
            case PropertyAccessorElement(variable: FieldElement()):
              shouldBreak = true;
              break;
            default:
              element = e.enclosingElement;
          }
        default:
          shouldBreak = true;
          break;
      }
      if (shouldBreak) break;
    }

    if (element
        case ExtensionElement(:final library) || ClassElement(:final library)) {
      _addLibrary(library);
    }

    super.visitPropertyAccess(node);
  }

  @override
  void visitComment(Comment node) {
    // Handles `/// [TypeName]` doc comment references
    for (final ref in node.references) {
      final element = switch (ref.expression) {
        SimpleIdentifier(:final element) => element,
        PrefixedIdentifier(:final element) => element?.enclosingElement,
        _ => null,
      };

      if (element case final ClassElement element) {
        _addType(element.thisType);
      } else if (element case final EnumElement element?) {
        _addType(
          element.instantiate(
            typeArguments: const [],
            nullabilitySuffix: NullabilitySuffix.none,
          ),
        );
      }
    }
    super.visitComment(node);
  }

  void _addType(InterfaceType type) {
    final library = type.element.library;
    if (type.element.name?.startsWith('_') case true) {
      return;
    }

    _addLibrary(library);
  }

  void _addLibrary(LibraryElement library) {
    if (library.isDartCore) {
      return;
    }

    libraries.add(library);
  }

  void _addNamespace(PrefixElement element) {
    if (element case PrefixElement(
      :final displayName,
      imports: [LibraryImport(:final importedLibrary?), ...],
    )) {
      _addImportPrefix(importedLibrary, displayName);
    }
  }

  void _addImportPrefix(LibraryElement library, String name) {
    final import = library.uri.toString();
    if (importPrefixes.containsKey(import)) {
      if (importPrefixes[import] == name) {
        return;
      }

      throw Exception('Duplicate import prefix: $import -> $name');
    }

    importPrefixes[import] = name;
  }
}

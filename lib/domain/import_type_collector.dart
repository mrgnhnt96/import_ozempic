import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// Collects all external type references that would require imports.
class ImportTypeCollector extends RecursiveAstVisitor<void> {
  ImportTypeCollector();

  final libraries = <LibraryElement>{};
  // Example: 'dart:math' -> 'math'
  final importPrefixes = <String, String>{};

  @override
  void visitNamedType(NamedType node) {
    switch (node) {
      // Example: `Foo`, `List<Bar>`
      case NamedType(:final InterfaceType type):
        _addType(type);

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
    // Example: `math.pi`
    if (node.prefix.element case PrefixElement element) {
      _addNamespace(element);
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
        case PrefixedIdentifier(element: final e?):
          switch (e) {
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
      if (importPrefixes[library.uri.toString()] == name) {
        return;
      }

      throw Exception('Duplicate import prefix: $import -> $name');
    }

    importPrefixes[import] = name;
  }
}

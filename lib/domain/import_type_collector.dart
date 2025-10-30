import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// Collects all external type references that would require imports.
class ImportTypeCollector extends RecursiveAstVisitor<void> {
  ImportTypeCollector();

  final libraries = <LibraryElement>{};

  @override
  void visitNamedType(NamedType node) {
    // Handles explicit type annotations (e.g., `Foo`, `List<Bar>`, etc.)
    final type = node.type;
    if (type is InterfaceType) {
      _addType(type);
    }
    super.visitNamedType(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;

    if (element?.displayName.startsWith('_') case true) {
      super.visitSimpleIdentifier(node);
      return;
    }

    /// Example: `pi`
    if (node.element case PropertyAccessorElement(
      :final library,
      variable: TopLevelVariableElement(),
    )) {
      _addLibrary(library);
    }

    super.visitSimpleIdentifier(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // Example: `context.extensionName`
    if (node.identifier.element case ExecutableElement(
      :final ExtensionElement enclosingElement,
    )) {
      _addLibrary(enclosingElement.library);
      super.visitPrefixedIdentifier(node);
      return;
    }

    // Example: `ClassName.staticMethod()` or `ClassName.staticField`
    final isStatic = switch (node.identifier.element) {
      ExecutableElement(isStatic: true) => true,
      FieldElement(isStatic: true) => true,
      _ => false,
    };

    // Only handle static members (methods, fields, getters, setters)
    if (isStatic) {
      final targetElement = node.prefix.element;

      if (targetElement is ClassElement) {
        _addType(targetElement.thisType);
      } else if (targetElement is EnumElement) {
        _addType(
          targetElement.instantiate(
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
        case SimpleIdentifier(element: final e):
          element = e;
        case PrefixedIdentifier(element: final e?):
          element = e.enclosingElement;
        default:
          shouldBreak = true;
          break;
      }
      if (shouldBreak) break;
    }

    if (element case final ExtensionElement element) {
      _addLibrary(element.library);
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
}

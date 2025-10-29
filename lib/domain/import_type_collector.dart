import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// Collects all external type references that would require imports.
class ImportTypeCollector extends RecursiveAstVisitor<void> {
  ImportTypeCollector();

  final referencedTypes = <InterfaceType>{};
  final extensions = <ExtensionElement>{};

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
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // Example: `ClassName.staticMember`
    final targetElement = node.prefix.element;
    final memberElement = node.identifier.element;

    // Only handle cases where the member is a static declaration.
    if (memberElement is ExecutableElement && memberElement.isStatic) {
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
      extensions.add(element);
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

    if (library.isDartCore) {
      return;
    }

    referencedTypes.add(type);
  }
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// Collects all external type references that would require imports.
class ImportTypeCollector extends RecursiveAstVisitor<void> {
  ImportTypeCollector();

  final referencedTypes = <InterfaceType>{};

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
    // Handles `ClassName.staticMember` or `EnumType.value`
    final element = node.prefix.staticType?.element;
    if (element is ClassElement) {
      _addType(element.thisType);
    } else if (element is EnumElement) {
      _addType(
        element.instantiate(
          typeArguments: const [],
          nullabilitySuffix: NullabilitySuffix.none,
        ),
      );
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    // Handles instance property access like `context.foo`
    final targetType = node.target?.staticType;
    if (targetType is InterfaceType) {
      _addType(targetType);
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

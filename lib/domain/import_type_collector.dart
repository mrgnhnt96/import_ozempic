import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// Collects all external type references that would require imports.
class ImportTypeCollector extends RecursiveAstVisitor<void> {
  /// The set of all referenced [InterfaceType]s not defined in this library.
  final referencedTypes = <InterfaceType>{};

  ImportTypeCollector();

  @override
  void visitNamedType(NamedType node) {
    final type = node.type;
    if (type is InterfaceType) {
      _addType(type);
    }
    super.visitNamedType(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // Handles `Color.red` or `Namespace.MyClass`
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
    // Handles things like `Color.red` when accessed via property
    final target = node.target;
    final targetType = target?.staticType;
    if (targetType is InterfaceType && targetType.element is EnumElement) {
      _addType(targetType);
    }
    super.visitPropertyAccess(node);
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

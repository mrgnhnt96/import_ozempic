import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/ast/ast.dart';
import 'package:analyzer/src/dart/element/scope.dart';
import 'package:import_ozempic/domain/reference.dart';

/// Collects all external type references that would require imports.
class ImportTypeCollector extends RecursiveAstVisitor<void> {
  ImportTypeCollector();

  final references = <Reference>{};

  @override
  void visitPatternFieldName(PatternFieldName node) {
    // Find the parent pattern
    final parentPattern = node.thisOrAncestorOfType<ObjectPattern>();
    final parentType = parentPattern?.type.type;

    if (parentType is InterfaceType) {
      final objectFields = {
        for (final field in parentType.element.fields) field.displayName,
      };

      final patternFields = {
        if (parentPattern != null)
          for (final field in parentPattern.fields)
            if (field.effectiveName case final String name) name,
      };

      final needsExtLookup = patternFields.difference(objectFields).isNotEmpty;

      if (needsExtLookup) {
        final unit = node.thisOrAncestorOfType<CompilationUnit>();
        final extensions = switch (unit?.declaredFragment?.scope) {
          LibraryFragmentScope(:final accessibleExtensions) =>
            accessibleExtensions,
          _ => <ExtensionElement>[],
        };

        for (final ext in extensions) {
          if (ext.extendedType case InterfaceType(:final Element element)) {
            if (element == parentType.element) {
              _addReference(
                Reference(lib: ext.library, associatedElement: ext),
              );
            }
          }
        }
      }
    }

    super.visitPatternFieldName(node);
  }

  @override
  void visitNamedType(NamedType node) {
    switch (node) {
      case NamedType(name: Token(lexeme: 'Future' || 'Stream')):
        break;

      /// Example: `VoidCallback`
      case NamedType(:final TypeAliasElement element):
        _addReference(
          Reference(lib: element.library, associatedElement: element),
        );

      // Example: `Foo`, `List<Bar>`
      case NamedType(
        type: InterfaceType(:final element),
        :final typeArguments,
        :final importPrefix,
      ):
        final prefix = switch (importPrefix) {
          ImportPrefixReference(name: Token(:final lexeme)) => lexeme,
          _ => null,
        };

        _addReference(
          Reference(
            lib: element.library,
            associatedElement: element,
            prefix: prefix,
          ),
        );

        if (typeArguments?.arguments case final args?) {
          for (final arg in args) {
            if (arg case final NamedType arg) {
              visitNamedType(arg);
            }
          }
        }
    }

    super.visitNamedType(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    super.visitSimpleIdentifier(node);

    if (node.parent case HideCombinator() || ShowCombinator()) {
      return;
    }

    final prefix = switch (node) {
      SimpleIdentifier(
        parent: PrefixedIdentifier(
          prefix: SimpleIdentifier(:final name, element: PrefixElement()),
        ),
      ) =>
        name,
      SimpleIdentifier(
        parent: MethodInvocation(
          target: SimpleIdentifier(:final name, element: PrefixElement()),
        ),
      ) =>
        name,
      _ => null,
    };

    if (node.element == null) {
      switch (node) {
        case SimpleIdentifierImpl(
          scopeLookupResult: PrefixScopeLookupResult(
            setter: ExecutableElement(:final baseElement),
          ),
          parent: AssignmentExpression(),
        ):
          if (baseElement case SetterElement(
            :final library,
            variable: TopLevelVariableElement(),
          )) {
            _addReference(
              Reference(
                lib: library,
                associatedElement: baseElement,
                prefix: prefix,
              ),
            );
          }
        case SimpleIdentifierImpl(
          scopeLookupResult: PrefixScopeLookupResult(
            getter: ExecutableElement(:final baseElement),
          ),
        ):
          if (baseElement case PropertyAccessorElement(
            :final library,
            variable: TopLevelVariableElement(),
          )) {
            _addReference(
              Reference(
                lib: library,
                associatedElement: baseElement,
                prefix: prefix,
              ),
            );
          }
        case SimpleIdentifierImpl(scopeLookupResult: null, :final name):
          final unit = node.thisOrAncestorOfType<CompilationUnit>();
          final libraries = unit?.declaredFragment?.importedLibraries ?? [];
          for (final lib in libraries) {
            if (lib.getGetter(name) ?? lib.getSetter(name)
                case final Element element) {
              _addReference(
                Reference(lib: lib, associatedElement: element, prefix: prefix),
              );
            }
          }
      }
    }

    switch (node.element) {
      case MixinElement(:final library):
      case ClassElement(:final library):
      case EnumElement(:final library):
      case PropertyAccessorElement(
        /// Example: `pi`
        :final library,
        variable: TopLevelVariableElement(),
      ):
      case ExtensionTypeElement(:final library):
      // Example: `pi`
      case TopLevelVariableElement(:final library):
      case TypeAliasElement(:final library):
      // Example: `max()`
      case TopLevelFunctionElement(:final library):
        if (node.element case final element?) {
          _addReference(
            Reference(lib: library, associatedElement: element, prefix: prefix),
          );
        }
      case ExecutableElement(enclosingElement: final element):
        if (element case ExtensionElement(:final library)) {
          _addReference(
            Reference(lib: library, associatedElement: element, prefix: prefix),
          );
        }
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final prefix = switch (node.target) {
      SimpleIdentifier(:final name, element: PrefixElement()) => name,
      PrefixedIdentifier(
        prefix: SimpleIdentifier(:final name, element: PrefixElement()),
      ) =>
        name,
      _ => null,
    };

    // Example: `math.max(1, 2)`
    switch (node.target) {
      case SimpleIdentifier(element: PrefixElement()):
        if (node.methodName case SimpleIdentifier(:final element?)) {
          if (element.library case final library?) {
            _addReference(
              Reference(
                lib: library,
                associatedElement: element,
                prefix: prefix,
              ),
            );
          }
        }
      case InstanceCreationExpression(:final InterfaceType staticType):
        _addReference(
          Reference(
            lib: staticType.element.library,
            associatedElement: staticType.element,
            prefix: prefix,
          ),
        );
    }

    final element = node.methodName.element;

    switch (element) {
      /// Example: `context.extensionName(...)`
      case MethodElement(:final ExtensionElement enclosingElement):
        _addReference(
          Reference(
            lib: enclosingElement.library,
            associatedElement: enclosingElement,
            prefix: prefix,
          ),
        );

      // Example: `Theme.of(context)` or `listEquals(...)`
      case MethodElement(:final enclosingElement, isStatic: true):
      case TopLevelFunctionElement(:final enclosingElement):
        switch (enclosingElement) {
          case LibraryElement(:final library):
            if (element != null) {
              _addReference(
                Reference(
                  lib: library,
                  associatedElement: element,
                  prefix: prefix,
                ),
              );
            }
          case ClassElement(:final thisType):
            _addReference(
              Reference(
                lib: thisType.element.library,
                associatedElement: thisType.element,
                prefix: prefix,
              ),
            );
          case EnumElement(:final instantiate):
            final type = instantiate(
              typeArguments: const [],
              nullabilitySuffix: NullabilitySuffix.none,
            );

            _addReference(
              Reference(
                associatedElement: type.element,
                lib: type.element.library,
                prefix: prefix,
              ),
            );
        }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitConstructorReference(ConstructorReference node) {
    switch (node.constructorName.element) {
      case ConstructorElement(:final ClassElement enclosingElement):
        _addReference(
          Reference(
            lib: enclosingElement.library,
            associatedElement: enclosingElement,
          ),
        );
    }

    super.visitConstructorReference(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    super.visitPropertyAccess(node);

    switch (node) {
      case PropertyAccess(
        // Example: `context.extensionName.methodName`
        target: PrefixedIdentifier(element: final targetElement),
        // Example: `context.extensionName`
        propertyName: SimpleIdentifier(element: final simpleElement),
      ):
        for (final element in [targetElement, simpleElement]) {
          if (element case ExecutableElement(
            :final library,
            :final lookupName?,
          )) {
            final extensions = <Element>[];
            for (final ext in library.extensions) {
              if (ext.getGetter(lookupName) case Element()) {
                extensions.add(ext);
              }
            }

            for (final extension in extensions) {
              if (extension case Element(:final library?)) {
                _addReference(
                  Reference(lib: library, associatedElement: extension),
                );
              }
            }
          }
        }
    }
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

      switch (element) {
        case ClassElement(thisType: InterfaceType(:final element)):
          _addReference(
            Reference(lib: element.library, associatedElement: element),
          );
        case EnumElement(:final instantiate):
          final type = instantiate(
            typeArguments: const [],
            nullabilitySuffix: NullabilitySuffix.none,
          );

          _addReference(
            Reference(
              associatedElement: type.element,
              lib: type.element.library,
            ),
          );
      }
    }
    super.visitComment(node);
  }

  void _addReference(Reference reference) {
    references.add(reference);
  }
}

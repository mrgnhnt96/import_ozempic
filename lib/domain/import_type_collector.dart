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
                Reference(lib: ext.library, associatedElement: element),
              );
            }
          }
        }
      }
    }

    super.visitPatternFieldName(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    final names = <(NodeList<SimpleIdentifier>, {bool hide})>[];
    for (final combination in node.combinators) {
      switch (combination) {
        case HideCombinator(:final hiddenNames):
          names.add((hiddenNames, hide: true));
        case ShowCombinator(:final shownNames):
          names.add((shownNames, hide: false));
      }
    }

    for (final (hiddenNames, :hide) in names) {
      for (final name in hiddenNames) {
        switch (name.element) {
          case ClassElement(:final thisType, :final library):
            _addReference(
              Reference.optional(
                lib: library,
                associatedElement: thisType.element,
                hide: hide,
              ),
            );
          case EnumElement(:final instantiate, :final library):
            _addReference(
              Reference.optional(
                lib: library,
                associatedElement: instantiate(
                  typeArguments: const [],
                  nullabilitySuffix: NullabilitySuffix.none,
                ).element,
                hide: hide,
              ),
            );
          case TypeAliasElement(:final instantiate, :final library):
            _addReference(
              Reference.optional(
                lib: library,
                associatedElement: instantiate(
                  typeArguments: const [],
                  nullabilitySuffix: NullabilitySuffix.none,
                ).element,
                hide: hide,
              ),
            );
          case MethodElement(:final ExtensionElement enclosingElement):
            if (enclosingElement case Element(:final library?)) {
              _addReference(
                Reference.optional(
                  associatedElement: enclosingElement,
                  lib: library,
                  hide: hide,
                ),
              );
            }
          case FieldElement(:final enclosingElement, isStatic: true):
            if (enclosingElement case Element(:final library?)) {
              _addReference(
                Reference.optional(
                  associatedElement: enclosingElement,
                  lib: library,
                  hide: hide,
                ),
              );
            }

          case ConstructorElement(:final library):
          case TopLevelVariableElement(:final library):
          case TopLevelFunctionElement(:final library):
          case Element(:final library?):
            _addReference(
              Reference.optional(
                associatedElement: name.element,
                lib: library,
                hide: hide,
              ),
            );
          default:
            break;
        }
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
      case NamedType(
        :final InterfaceType type,
        :final typeArguments,
        :final importPrefix,
      ):
        final prefix = switch (importPrefix) {
          ImportPrefixReference(name: Token(:final lexeme)) => lexeme,
          _ => null,
        };

        _addReference(
          Reference(
            lib: type.element.library,
            associatedElement: type.element,
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

      /// Example: `VoidCallback`
      case NamedType(:final TypeAliasElement element):
        _addReference(
          Reference(lib: element.library, associatedElement: element),
        );
    }

    super.visitNamedType(node);
  }

  @override
  void visitImportPrefixReference(ImportPrefixReference node) {
    if (node case ImportPrefixReference(
      :final PrefixElement element,
      parent: NamedType(element: Element(:final library?)),
    )) {
      _addReference(
        Reference.optional(
          lib: library,
          associatedElement: element,
          prefix: element.displayName,
        ),
      );
    }

    super.visitImportPrefixReference(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
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
                getter: ExecutableElement(:final baseElement),
              ) ||
              PrefixScopeLookupResult(
                setter: ExecutableElement(:final baseElement),
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
      // Example: `pi`
      case TopLevelVariableElement(:final library):
      // Example: `max()`
      case TopLevelFunctionElement(:final library):
        if (node.element case final element?) {
          _addReference(
            Reference(lib: library, associatedElement: element, prefix: prefix),
          );
        }
    }

    super.visitSimpleIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final prefix = switch (node.target) {
      SimpleIdentifier(:final name, element: PrefixElement()) => name,
      _ => null,
    };

    // Example: `math.max(1, 2)`
    switch (node.target) {
      case SimpleIdentifier(:final PrefixElement element):
        if (node.methodName case SimpleIdentifier(
          element: Element(:final library?),
        )) {
          _addReference(
            Reference(lib: library, associatedElement: element, prefix: prefix),
          );
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

  // @override
  // void visitPrefixedIdentifier(PrefixedIdentifier node) {
  //   switch (node.prefix) {
  //     // Example: `math.pi`
  //     case SimpleIdentifier(element: final PrefixElement prefix):
  //       if (node.element case final Element element) {
  //         if (element.library case final LibraryElement library) {
  //           _addReference(
  //             Reference(
  //               lib: library,
  //               associatedElement: element,
  //               prefix: prefix.displayName,
  //             ),
  //           );
  //         }
  //       }

  //     // Example: `HttpOverrides.global`
  //     case SimpleIdentifier(
  //       element: ClassElement(:final library) ||
  //           EnumElement(:final library) ||
  //           ExtensionTypeElement(:final library) ||
  //           // Example: `typedef LogLevel = Level --> LogLevel.info
  //           TypeAliasElement(:final library),
  //     ):
  //       if (node.identifier.element case final element?) {
  //         _addReference(Reference(lib: library, associatedElement: element));
  //       }
  //   }

  //   switch (node.identifier.element) {
  //     // Example: `context.extensionName`
  //     case ExecutableElement(:final ExtensionElement enclosingElement):
  //       _addReference(
  //         Reference(
  //           lib: enclosingElement.library,
  //           associatedElement: enclosingElement,
  //         ),
  //       );

  //     // Example: `ClassName.staticMethod()` or `ClassName.staticField`
  //     case ExecutableElement(isStatic: true) || FieldElement(isStatic: true):
  //       final targetElement = node.prefix.element;
  //       switch (targetElement) {
  //         case ClassElement(:final thisType):
  //           _addReference(
  //             Reference(
  //               lib: thisType.element.library,
  //               associatedElement: thisType.element,
  //             ),
  //           );
  //         case MixinElement(:final library):
  //           _addReference(
  //             Reference(lib: library, associatedElement: targetElement),
  //           );
  //         case EnumElement(:final instantiate):
  //           final type = instantiate(
  //             typeArguments: const [],
  //             nullabilitySuffix: NullabilitySuffix.none,
  //           );

  //           _addReference(
  //             Reference(
  //               associatedElement: type.element,
  //               lib: type.element.library,
  //             ),
  //           );
  //       }
  //   }

  //   super.visitPrefixedIdentifier(node);
  // }

  // @override
  // void visitPropertyAccess(PropertyAccess node) {
  //   if (node.propertyName.element case ExecutableElement(
  //     enclosingElement: final ExtensionElement e,
  //   )) {
  //     _addReference(Reference(lib: e.library, associatedElement: e));
  //     super.visitPropertyAccess(node);
  //     return;
  //   }

  //   // Handles instance property access like `context.foo`
  //   Element? element;
  //   PropertyAccess access = node;

  //   while (element == null) {
  //     var shouldBreak = false;
  //     switch (access.realTarget) {
  //       case PropertyAccess(:final PropertyAccess realTarget):
  //         access = realTarget;
  //       case PropertyAccess(:final PrefixedIdentifier realTarget):
  //         element = realTarget.element?.enclosingElement;
  //       case PropertyAccess(:final SimpleIdentifier realTarget):
  //         element = realTarget.element?.enclosingElement;
  //       case SimpleIdentifier(element: final e):
  //         element = e;
  //       case PrefixedIdentifier(element: final e?):
  //         switch (e) {
  //           case EnumElement(:final instantiate):
  //             final type = instantiate(
  //               typeArguments: const [],
  //               nullabilitySuffix: NullabilitySuffix.none,
  //             );
  //             _addReference(
  //               Reference(
  //                 associatedElement: type.element,
  //                 lib: type.element.library,
  //               ),
  //             );
  //             shouldBreak = true;
  //           case PropertyAccessorElement(variable: FieldElement()):
  //             shouldBreak = true;
  //             break;
  //           default:
  //             element = e.enclosingElement;
  //         }
  //       default:
  //         shouldBreak = true;
  //         break;
  //     }
  //     if (shouldBreak) break;
  //   }

  //   super.visitPropertyAccess(node);
  // }

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

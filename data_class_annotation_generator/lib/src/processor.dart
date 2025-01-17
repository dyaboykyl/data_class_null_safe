// Copyright (c) 2017, Ltei. All rights reserved.
// Use of this source code is governed by a MIT license that can be found in the
// LICENSE file.

import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:data_class_annotation/data_class_annotation.dart';
import 'package:data_class_annotation_generator/src/class_element_info.dart';
import 'package:source_gen/source_gen.dart';

/// The DataClass code generator.
class DataClassProcessor extends GeneratorForAnnotation<DataClass> {
  @override
  FutureOr<String> generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError('The element annotated with @DataClass is not a class.', element: element);
    }

    final ClassElement classElement = element as ClassElement;

    final classElementInfo = ClassElementInfo.parse(classElement);

    final dataClassExtension = Code(_generateDataClass(classElementInfo));

    final library = Library((builder) => builder..body.add(dataClassExtension));
    return library.accept(DartEmitter()).toString();
  }

  String _generateDataClass(ClassElementInfo classElementInfo) {
    final result = StringBuffer();
    result.write('extension ${classElementInfo.name}Ext on ${classElementInfo.name} {\n');
    if (classElementInfo.dataClassAnnotation.generateCopyWith) result.write('${_generateMethodCopyWith(classElementInfo)} \n\n');
    if (classElementInfo.dataClassAnnotation.generateDataEquals) result.write('${_generateMethodEqualsData(classElementInfo)} \n\n');
    if (classElementInfo.dataClassAnnotation.generateDataToString) result.write('${_generateMethodToStringData(classElementInfo)} \n\n');
    if (classElementInfo.dataClassAnnotation.generateDataHashCode)
      result.write('int get dataHashCode => ${_generateHashCodeExpr(classElementInfo)}; \n');
    result.write('}');
    return result.toString();
  }

  String _generateMethodCopyWith(ClassElementInfo classElementInfo) {
    String paramsString = classElementInfo.fields.fold("", (acc, e) {
      final subTypes = e.typeParameters.map((e) => e.name).join(",");
      final generics = subTypes.isNotEmpty ? "<$subTypes>" : "";
      final optional = "${e.type}".contains("?") ? "" : "?";
      return "$acc${e.type}$optional ${e.name}, ";
    });
    paramsString = paramsString.isEmpty ? "" : "{$paramsString}";

    StringBuffer constructorParamsStringBuffer = StringBuffer();
    for (final param in classElementInfo.primaryConstructor.parameters.where((e) => e.isPositional)) {
      constructorParamsStringBuffer..write("${param.name} ?? this.${param.name}, ");
    }
    for (final param in classElementInfo.primaryConstructor.parameters.where((e) => e.isNamed)) {
      constructorParamsStringBuffer..write("${param.name}: ${param.name} ?? this.${param.name}, ");
    }

    final code =
        "return ${classElementInfo.constructorCallConstString}${classElementInfo.name}${classElementInfo.constructorCallNameString}($constructorParamsStringBuffer);";

    return "${classElementInfo.name} copyWith($paramsString) {$code}";
  }

  String _generateMethodEqualsData(ClassElementInfo classElementInfo) {
    final code = StringBuffer();
    for (int i = 0; i < classElementInfo.fields.length; i++) {
      final field = classElementInfo.fields[i];
      if (field.customEqualityType == null) {
        code.write(
            "(this.${field.name} == other.${field.name} || const DeepCollectionEquality(const DefaultEquality()).equals(this.${field.name}, other.${field.name}))");
      } else {
        final eqTypeName = field.customEqualityType.name;
        code.write(
            "(const $eqTypeName().equals(this.${field.name}, other.${field.name}) || const DeepCollectionEquality(const $eqTypeName()).equals(this.${field.name}, other.${field.name}))");
      }
      if (i < classElementInfo.fields.length - 1) {
        code.write(" && ");
      }
    }
    final fullCode = code.isEmpty ? "other is ${classElementInfo.name}" : "other is ${classElementInfo.name} && ${code.toString()}";
    return "bool dataEquals(dynamic other) => $fullCode;";
  }

  String _generateMethodToStringData(ClassElementInfo classElementInfo) {
    final code = StringBuffer();
    for (int i = 0; i < classElementInfo.fields.length; i++) {
      final field = classElementInfo.fields[i];
      code.write("${field.name}=\${this.${field.name}}");
      if (i < classElementInfo.fields.length - 1) {
        code.write(", ");
      }
    }
    return "String dataToString() => \"${classElementInfo.name}($code)\";";
  }

  String _generateHashCodeExpr(ClassElementInfo classElementInfo) {
    final code = StringBuffer();
    code.write("(${classElementInfo.name}).hashCode");
    for (int i = 0; i < classElementInfo.fields.length; i++) {
      final field = classElementInfo.fields[i];
      code.write(" ^ this.${field.name}.hashCode");
    }
    return code.toString();
  }
}

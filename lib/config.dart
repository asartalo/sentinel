// ignore_for_file: avoid_implementing_value_types

import 'dart:collection';

import 'package:equatable/equatable.dart';

class Config extends Equatable {
  final List<String> ignorePaths;

  Config({required List<String> ignorePaths})
      : ignorePaths = UnmodifiableListView(ignorePaths);

  @override
  List<Object?> get props => [ignorePaths];

  @override
  bool? get stringify => true;
}

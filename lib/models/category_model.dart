import 'package:flutter/material.dart';

class CategoryModel {
  final int? id;
  final String name;
  final int iconCode;

  CategoryModel({
    this.id,
    required this.name,
    required this.iconCode,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'],
      name: map['name'],
      iconCode: map['icon_code'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_code': iconCode,
    };
  }

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
}

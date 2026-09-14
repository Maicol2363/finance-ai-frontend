import 'package:flutter/material.dart';

import '../domain/category_models.dart';

extension CategoryColorVisuals on CategoryColor {
  Color get value => switch (this) {
    CategoryColor.blue => Colors.blue,
    CategoryColor.green => Colors.green,
    CategoryColor.orange => Colors.orange,
    CategoryColor.purple => Colors.purple,
    CategoryColor.pink => Colors.pink,
    CategoryColor.red => Colors.red,
    CategoryColor.teal => Colors.teal,
    CategoryColor.yellow => Colors.amber,
    CategoryColor.gray => Colors.blueGrey,
  };

  String get label => switch (this) {
    CategoryColor.blue => 'Azul',
    CategoryColor.green => 'Verde',
    CategoryColor.orange => 'Naranja',
    CategoryColor.purple => 'Morado',
    CategoryColor.pink => 'Rosa',
    CategoryColor.red => 'Rojo',
    CategoryColor.teal => 'Turquesa',
    CategoryColor.yellow => 'Amarillo',
    CategoryColor.gray => 'Gris',
  };
}

extension CategoryIconVisuals on CategoryIcon {
  IconData get value => switch (this) {
    CategoryIcon.essentials => Icons.check_circle_outline,
    CategoryIcon.wants => Icons.auto_awesome_outlined,
    CategoryIcon.food => Icons.restaurant_outlined,
    CategoryIcon.transport => Icons.directions_bus_outlined,
    CategoryIcon.home => Icons.home_outlined,
    CategoryIcon.health => Icons.health_and_safety_outlined,
    CategoryIcon.education => Icons.school_outlined,
    CategoryIcon.entertainment => Icons.movie_outlined,
    CategoryIcon.shopping => Icons.shopping_bag_outlined,
    CategoryIcon.bills => Icons.receipt_long_outlined,
    CategoryIcon.travel => Icons.flight_outlined,
    CategoryIcon.gift => Icons.card_giftcard_outlined,
    CategoryIcon.other => Icons.category_outlined,
  };

  String get label => switch (this) {
    CategoryIcon.essentials => 'Esenciales',
    CategoryIcon.wants => 'Gustos',
    CategoryIcon.food => 'Comida',
    CategoryIcon.transport => 'Transporte',
    CategoryIcon.home => 'Hogar',
    CategoryIcon.health => 'Salud',
    CategoryIcon.education => 'Educación',
    CategoryIcon.entertainment => 'Entretenimiento',
    CategoryIcon.shopping => 'Compras',
    CategoryIcon.bills => 'Facturas',
    CategoryIcon.travel => 'Viajes',
    CategoryIcon.gift => 'Regalos',
    CategoryIcon.other => 'Otros',
  };
}

import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';

import '../domain/category_models.dart';

extension CategoryColorVisuals on CategoryColor {
  Color get value => switch (this) {
    CategoryColor.blue => const Color(0xFF4C83D7),
    CategoryColor.green => const Color(0xFF3C9270),
    CategoryColor.orange => const Color(0xFFD8893F),
    CategoryColor.purple => const Color(0xFF8D6AC0),
    CategoryColor.pink => const Color(0xFFC96F93),
    CategoryColor.red => const Color(0xFFD45F5B),
    CategoryColor.teal => const Color(0xFF3C9294),
    CategoryColor.yellow => const Color(0xFFC49A38),
    CategoryColor.gray => const Color(0xFF75817C),
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
    CategoryIcon.essentials => FinanceIconCatalog.dataFor(
      FinanceIconKey.category,
    ),
    CategoryIcon.wants => FinanceIconCatalog.dataFor(FinanceIconKey.aiCapture),
    CategoryIcon.food => FinanceIconCatalog.dataFor(FinanceIconKey.food),
    CategoryIcon.transport => FinanceIconCatalog.dataFor(
      FinanceIconKey.transport,
    ),
    CategoryIcon.home => FinanceIconCatalog.dataFor(FinanceIconKey.home),
    CategoryIcon.health => FinanceIconCatalog.dataFor(FinanceIconKey.health),
    CategoryIcon.education => FinanceIconCatalog.dataFor(
      FinanceIconKey.education,
    ),
    CategoryIcon.entertainment => FinanceIconCatalog.dataFor(
      FinanceIconKey.entertainment,
    ),
    CategoryIcon.shopping => FinanceIconCatalog.dataFor(
      FinanceIconKey.shopping,
    ),
    CategoryIcon.bills => FinanceIconCatalog.dataFor(FinanceIconKey.bills),
    CategoryIcon.travel => FinanceIconCatalog.dataFor(FinanceIconKey.travel),
    CategoryIcon.gift => FinanceIconCatalog.dataFor(FinanceIconKey.gift),
    CategoryIcon.other => FinanceIconCatalog.dataFor(FinanceIconKey.category),
  };

  IconData get emphasisValue => switch (this) {
    CategoryIcon.essentials => FinanceIconCatalog.emphasisDataFor(
      FinanceIconKey.category,
    ),
    CategoryIcon.wants => FinanceIconCatalog.emphasisDataFor(
      FinanceIconKey.aiCapture,
    ),
    CategoryIcon.food => FinanceIconCatalog.emphasisDataFor(
      FinanceIconKey.food,
    ),
    CategoryIcon.transport => FinanceIconCatalog.emphasisDataFor(
      FinanceIconKey.transport,
    ),
    CategoryIcon.home => FinanceIconCatalog.emphasisDataFor(
      FinanceIconKey.home,
    ),
    CategoryIcon.health => FinanceIconCatalog.emphasisDataFor(
      FinanceIconKey.health,
    ),
    CategoryIcon.education => FinanceIconCatalog.emphasisDataFor(
      FinanceIconKey.education,
    ),
    CategoryIcon.entertainment => FinanceIconCatalog.emphasisDataFor(
      FinanceIconKey.entertainment,
    ),
    CategoryIcon.shopping => FinanceIconCatalog.emphasisDataFor(
      FinanceIconKey.shopping,
    ),
    CategoryIcon.bills => FinanceIconCatalog.emphasisDataFor(
      FinanceIconKey.bills,
    ),
    CategoryIcon.travel => FinanceIconCatalog.emphasisDataFor(
      FinanceIconKey.travel,
    ),
    CategoryIcon.gift => FinanceIconCatalog.emphasisDataFor(
      FinanceIconKey.gift,
    ),
    CategoryIcon.other => FinanceIconCatalog.emphasisDataFor(
      FinanceIconKey.category,
    ),
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

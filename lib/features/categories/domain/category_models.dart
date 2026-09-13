enum CategoryColor {
  blue,
  green,
  orange,
  purple,
  pink,
  red,
  teal,
  yellow,
  gray;

  static CategoryColor fromWire(Object? value) {
    if (value is! String) {
      throw const FormatException('Invalid category color');
    }
    return values.firstWhere(
      (item) => item.name == value,
      orElse: () => throw const FormatException('Unsupported category color'),
    );
  }
}

enum CategoryIcon {
  essentials,
  wants,
  food,
  transport,
  home,
  health,
  education,
  entertainment,
  shopping,
  bills,
  travel,
  gift,
  other;

  static CategoryIcon fromWire(Object? value) {
    if (value is! String) {
      throw const FormatException('Invalid category icon');
    }
    return values.firstWhere(
      (item) => item.name == value,
      orElse: () => throw const FormatException('Unsupported category icon'),
    );
  }
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Category.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final sortOrder = json['sort_order'];
    final createdAt = json['created_at'];
    final updatedAt = json['updated_at'];
    if (id is! int ||
        id < 1 ||
        name is! String ||
        name.trim().isEmpty ||
        sortOrder is! int ||
        sortOrder < 0 ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('Invalid category response');
    }
    final parsedCreatedAt = DateTime.tryParse(createdAt);
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedCreatedAt == null || parsedUpdatedAt == null) {
      throw const FormatException('Invalid category timestamp');
    }
    return Category(
      id: id,
      name: name,
      color: CategoryColor.fromWire(json['color']),
      icon: CategoryIcon.fromWire(json['icon']),
      sortOrder: sortOrder,
      createdAt: parsedCreatedAt.toUtc(),
      updatedAt: parsedUpdatedAt.toUtc(),
    );
  }

  final int id;
  final String name;
  final CategoryColor color;
  final CategoryIcon icon;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class CategoryListResult {
  const CategoryListResult({
    required this.categories,
    required this.supportedColors,
    required this.supportedIcons,
  });

  factory CategoryListResult.fromJson(Map<String, Object?> json) {
    final rawCategories = json['categories'];
    final rawColors = json['supported_colors'];
    final rawIcons = json['supported_icons'];
    if (rawCategories is! List<Object?> ||
        rawColors is! List<Object?> ||
        rawIcons is! List<Object?>) {
      throw const FormatException('Invalid category list response');
    }
    final categories = rawCategories
        .map((value) {
          if (value is! Map<String, Object?>) {
            throw const FormatException('Invalid category list item');
          }
          return Category.fromJson(value);
        })
        .toList(growable: false);
    final colors = rawColors
        .map(CategoryColor.fromWire)
        .toList(growable: false);
    final icons = rawIcons.map(CategoryIcon.fromWire).toList(growable: false);
    if (colors.isEmpty || icons.isEmpty) {
      throw const FormatException('Category options cannot be empty');
    }
    return CategoryListResult(
      categories: List.unmodifiable(categories),
      supportedColors: List.unmodifiable(colors),
      supportedIcons: List.unmodifiable(icons),
    );
  }

  final List<Category> categories;
  final List<CategoryColor> supportedColors;
  final List<CategoryIcon> supportedIcons;

  Category? categoryById(int id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}

class CategoryCreateCommand {
  const CategoryCreateCommand({
    required this.name,
    required this.color,
    required this.icon,
  });

  final String name;
  final CategoryColor color;
  final CategoryIcon icon;

  Map<String, Object?> toJson() => {
    'name': name,
    'color': color.name,
    'icon': icon.name,
  };
}

typedef CategoryUpdateCommand = CategoryCreateCommand;

class CategoryFailure implements Exception {
  const CategoryFailure({
    required this.code,
    required this.userMessage,
    this.fieldErrors = const {},
    this.correlationId = 'unavailable',
    this.technicalReason = 'category_operation_failure',
    this.isMutationOutcomeUncertain = false,
  });

  final String code;
  final String userMessage;
  final Map<String, List<String>> fieldErrors;
  final String correlationId;
  final String technicalReason;
  final bool isMutationOutcomeUncertain;
}

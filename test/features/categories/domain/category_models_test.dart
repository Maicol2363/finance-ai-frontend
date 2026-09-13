import 'package:finance_ai/features/categories/domain/category_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> categoryJson({int id = 4, String name = 'Food'}) => {
  'id': id,
  'name': name,
  'color': 'orange',
  'icon': 'food',
  'sort_order': 0,
  'created_at': '2026-09-12T12:00:00Z',
  'updated_at': '2026-09-12T12:00:00Z',
};

void main() {
  test('decodes category list, controlled options, lookup, and UTC times', () {
    final result = CategoryListResult.fromJson({
      'categories': [categoryJson()],
      'supported_colors': CategoryColor.values
          .map((item) => item.name)
          .toList(),
      'supported_icons': CategoryIcon.values.map((item) => item.name).toList(),
    });

    expect(result.categoryById(4)?.name, 'Food');
    expect(result.categoryById(99), isNull);
    expect(result.categories.single.color, CategoryColor.orange);
    expect(result.categories.single.icon, CategoryIcon.food);
    expect(result.categories.single.createdAt.isUtc, isTrue);
  });

  test('commands use the exact server wire format', () {
    expect(
      const CategoryCreateCommand(
        name: 'Travel',
        color: CategoryColor.teal,
        icon: CategoryIcon.travel,
      ).toJson(),
      {'name': 'Travel', 'color': 'teal', 'icon': 'travel'},
    );
  });

  test('malformed and unsupported responses fail closed', () {
    for (final value in [
      {...categoryJson(), 'id': 0},
      {...categoryJson(), 'color': 'rainbow'},
      {...categoryJson(), 'icon': 'secret'},
      {...categoryJson(), 'created_at': 'today'},
    ]) {
      expect(() => Category.fromJson(value), throwsA(isA<FormatException>()));
    }
    expect(
      () => CategoryListResult.fromJson({
        'categories': const [],
        'supported_colors': const [],
        'supported_icons': const [],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}

/// Spanish presentation labels for a small set of canonical seed values.
///
/// These labels are display-only: callers must keep the original catalog value
/// for requests and editable fields. Unknown values are returned unchanged.
class CatalogLabels {
  const CatalogLabels._();

  static String display(String value) => switch (value.trim().toLowerCase()) {
    'needs' => 'Necesidades',
    'wants' => 'Deseos',
    'other' => 'Otros',
    'salary' => 'Salario',
    'colombian peso' => 'Peso colombiano',
    _ => value,
  };
}

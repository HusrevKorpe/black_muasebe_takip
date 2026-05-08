class Partner {
  final String id;
  final String name;
  final double percentage;
  final String? note;

  const Partner({
    required this.id,
    required this.name,
    required this.percentage,
    this.note,
  });

  factory Partner.fromMap(Map<String, dynamic> m) {
    return Partner(
      id: m['id'] as String? ?? '',
      name: m['name'] as String? ?? '',
      percentage: (m['percentage'] as num?)?.toDouble() ?? 0,
      note: m['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'percentage': percentage,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  Partner copyWith({
    String? id,
    String? name,
    double? percentage,
    String? note,
  }) {
    return Partner(
      id: id ?? this.id,
      name: name ?? this.name,
      percentage: percentage ?? this.percentage,
      note: note ?? this.note,
    );
  }
}

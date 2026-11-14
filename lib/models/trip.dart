class Trip {
  Trip({
    required this.id,
    required this.name,
    this.notes,
    this.startDate,
    this.endDate,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? notes;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  Trip copyWith({
    String? name,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
  }) => Trip(
    id: id,
    name: name ?? this.name,
    notes: notes ?? this.notes,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    createdAt: createdAt,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'notes': notes,
    'start_date': startDate?.millisecondsSinceEpoch,
    'end_date': endDate?.millisecondsSinceEpoch,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory Trip.fromMap(Map<String, Object?> m) => Trip(
    id: m['id'] as String,
    name: m['name'] as String,
    notes: m['notes'] as String?,
    startDate: _date(m['start_date']),
    endDate: _date(m['end_date']),
    createdAt: _date(m['created_at']) ?? DateTime.now(),
  );
}

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());

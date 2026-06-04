class Warehouse {
  final int? id;
  final String name;
  final String type; // raw, purchased, semi_finished, finished, sales
  final int? factoryId;
  final DateTime? createdAt;

  Warehouse({
    this.id,
    required this.name,
    required this.type,
    this.factoryId,
    this.createdAt,
  });

  factory Warehouse.fromRow(dynamic row) {
    return Warehouse(
      id: row[0] as int,
      name: row[1] as String,
      type: row[2] as String,
      factoryId: row[3] as int?,
      createdAt: row[4] as DateTime?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'factoryId': factoryId,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

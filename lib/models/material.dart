class Material {
  final int? id;
  final String name;
  final String type; // raw, purchased, self_produced
  final String unit;
  final double currentStock;
  final double minStock;
  final double maxStock;
  final int? supplierId;
  final int leadTimeDays;
  final int? factoryId;
  final DateTime? createdAt;

  Material({
    this.id,
    required this.name,
    required this.type,
    this.unit = 'kg',
    this.currentStock = 0,
    this.minStock = 0,
    this.maxStock = 0,
    this.supplierId,
    this.leadTimeDays = 30,
    this.factoryId,
    this.createdAt,
  });

  factory Material.fromRow(dynamic row) {
    return Material(
      id: row[0] as int,
      name: row[1] as String,
      type: row[2] as String,
      unit: row[3] as String,
      currentStock: double.parse(row[4].toString()),
      minStock: double.parse(row[5].toString()),
      maxStock: double.parse(row[6].toString()),
      supplierId: row[7] as int?,
      leadTimeDays: row[8] as int,
      factoryId: row[9] as int?,
      createdAt: row[10] as DateTime?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'unit': unit,
      'currentStock': currentStock,
      'minStock': minStock,
      'maxStock': maxStock,
      'supplierId': supplierId,
      'leadTimeDays': leadTimeDays,
      'factoryId': factoryId,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class Service {
  const Service({
    required this.id,
    required this.shopId,
    required this.name,
    required this.durationMinutes,
    required this.priceCents,
    this.isActive = true,
  });

  final String id;
  final String shopId;
  final String name;
  final int durationMinutes;
  final int priceCents;
  final bool isActive;

  factory Service.fromJson(Map<String, dynamic> json) => Service(
        id: json['id'] as String,
        shopId: json['shop_id'] as String,
        name: json['name'] as String,
        durationMinutes: json['duration_minutes'] as int,
        priceCents: json['price_cents'] as int,
        isActive: (json['is_active'] as bool?) ?? true,
      );
}

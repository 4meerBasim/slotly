class Shop {
  const Shop({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.slotIntervalMinutes,
    this.description,
    this.address,
    this.phone,
    this.imageUrl,
  });

  final String id;
  final String ownerId;
  final String name;
  final int slotIntervalMinutes;
  final String? description;
  final String? address;
  final String? phone;
  final String? imageUrl;

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        slotIntervalMinutes: (json['slot_interval_minutes'] as int?) ?? 15,
        description: json['description'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        imageUrl: json['image_url'] as String?,
      );
}

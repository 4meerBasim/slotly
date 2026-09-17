class StaffMember {
  const StaffMember({
    required this.id,
    required this.shopId,
    required this.name,
    this.title,
    this.imageUrl,
    this.isActive = true,
  });

  final String id;
  final String shopId;
  final String name;
  final String? title;
  final String? imageUrl;
  final bool isActive;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: json['id'] as String,
        shopId: json['shop_id'] as String,
        name: json['name'] as String,
        title: json['title'] as String?,
        imageUrl: json['image_url'] as String?,
        isActive: (json['is_active'] as bool?) ?? true,
      );
}

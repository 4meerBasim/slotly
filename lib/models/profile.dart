enum UserRole { customer, owner }

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    this.phone,
  });

  final String id;
  final String fullName;
  final UserRole role;
  final String? phone;

  bool get isOwner => role == UserRole.owner;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        fullName: (json['full_name'] as String?) ?? '',
        phone: json['phone'] as String?,
        role: json['role'] == 'owner' ? UserRole.owner : UserRole.customer,
      );
}

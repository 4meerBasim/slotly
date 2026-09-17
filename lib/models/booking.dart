enum BookingStatus { pending, confirmed, completed, cancelled, noShow }

extension BookingStatusX on BookingStatus {
  String get wire => switch (this) {
        BookingStatus.noShow => 'no_show',
        _ => name,
      };

  String get label => switch (this) {
        BookingStatus.pending => 'Pending',
        BookingStatus.confirmed => 'Confirmed',
        BookingStatus.completed => 'Completed',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.noShow => 'No-show',
      };

  bool get isLive =>
      this == BookingStatus.pending || this == BookingStatus.confirmed;

  static BookingStatus parse(String value) => switch (value) {
        'pending' => BookingStatus.pending,
        'confirmed' => BookingStatus.confirmed,
        'completed' => BookingStatus.completed,
        'cancelled' => BookingStatus.cancelled,
        'no_show' => BookingStatus.noShow,
        _ => BookingStatus.pending,
      };
}

class Booking {
  const Booking({
    required this.id,
    required this.shopId,
    required this.staffId,
    required this.serviceId,
    required this.customerId,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.priceCents,
    this.notes,
    this.shopName,
    this.staffName,
    this.serviceName,
    this.customerName,
  });

  final String id;
  final String shopId;
  final String staffId;
  final String serviceId;
  final String customerId;
  final DateTime startsAt;
  final DateTime endsAt;
  final BookingStatus status;
  final int priceCents;
  final String? notes;

  // denormalised labels from the join, for display only
  final String? shopName;
  final String? staffName;
  final String? serviceName;
  final String? customerName;

  bool get isUpcoming => status.isLive && endsAt.isAfter(DateTime.now());

  factory Booking.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? rel(String key) =>
        json[key] as Map<String, dynamic>?;

    return Booking(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      staffId: json['staff_id'] as String,
      serviceId: json['service_id'] as String,
      customerId: json['customer_id'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      status: BookingStatusX.parse(json['status'] as String),
      priceCents: json['price_cents'] as int,
      notes: json['notes'] as String?,
      shopName: rel('shops')?['name'] as String?,
      staffName: rel('staff')?['name'] as String?,
      serviceName: rel('services')?['name'] as String?,
      customerName: rel('profiles')?['full_name'] as String?,
    );
  }
}

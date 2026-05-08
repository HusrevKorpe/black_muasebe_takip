import 'user_role.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? shopId;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.shopId,
  });

  bool get isBoss => role == UserRole.boss;
  bool get isOwner => role == UserRole.owner;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      role: UserRole.fromWire(map['role'] as String?),
      shopId: map['shopId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'role': role.wire,
        if (shopId != null) 'shopId': shopId,
      };
}

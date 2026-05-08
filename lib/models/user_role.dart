enum UserRole {
  owner,
  boss;

  String get wire => name;

  static UserRole fromWire(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.wire == value,
      orElse: () => UserRole.owner,
    );
  }
}

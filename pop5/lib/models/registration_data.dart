/// Collected on C2 and finished on C2b.
class RegistrationData {
  final String fullName;
  final String username;
  final String email;
  final String phone; // normalised, e.g. +60123456789
  final String password;

  const RegistrationData({
    required this.fullName,
    required this.username,
    required this.email,
    required this.phone,
    required this.password,
  });
}

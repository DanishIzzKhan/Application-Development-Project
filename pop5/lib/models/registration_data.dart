class RegistrationData {
  final String fullName;
  final String username;
  final String email;
  final String phone; // normalised, e.g. +60123456789
  final String password;
  final bool phoneVerified; // true when SMS verification was done on C2

  const RegistrationData({
    required this.fullName,
    required this.username,
    required this.email,
    required this.phone,
    required this.password,
    required this.phoneVerified,
  });
}

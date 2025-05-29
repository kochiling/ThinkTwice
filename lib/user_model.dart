class UserModel{
  final String id;
  final String name;
  final String email;
  final String country;
  final String profileImage;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.country,
    required this.profileImage,

  });

  factory UserModel.fromMap(Map<dynamic, dynamic> data, String id) {
    return UserModel(
      id: id,
      name: data['username'] ?? '',
      email: data['email'] ?? '',
      profileImage: data['profile_pic'] ?? '',
      country: data['country'] ?? '',
    );
  }
}

/// Public data of a user, stored with the same id as its `AuthUser`.
class Profile {
  final String id;
  final String username;
  final String fullName;

  const Profile({
    required this.id,
    required this.username,
    required this.fullName,
  });

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.username == username &&
      other.fullName == fullName;

  @override
  int get hashCode => Object.hash(id, username, fullName);

  @override
  String toString() =>
      'Profile(id: $id, username: $username, fullName: $fullName)';
}

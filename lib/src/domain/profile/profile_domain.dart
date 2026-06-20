class UserProfileSnapshot {
  const UserProfileSnapshot({this.avatarUri});

  final Uri? avatarUri;
}

abstract interface class UserProfileProvider {
  Future<UserProfileSnapshot?> currentProfile();
}

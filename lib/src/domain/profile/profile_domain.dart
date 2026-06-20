class UserProfileSnapshot {
  const UserProfileSnapshot({this.displayName, this.avatarUri});

  final String? displayName;
  final Uri? avatarUri;
}

abstract interface class UserProfileProvider {
  Future<UserProfileSnapshot?> currentProfile();
}

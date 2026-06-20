import 'profile_domain.dart';

enum BangumiLoginStartStatus {
  opened,
  unavailable,
  failed,
}

final class BangumiLoginStartResult {
  const BangumiLoginStartResult._({
    required this.status,
    required this.openedUri,
    required this.message,
  });

  const BangumiLoginStartResult.opened(Uri openedUri)
      : this._(
          status: BangumiLoginStartStatus.opened,
          openedUri: openedUri,
          message: null,
        );

  const BangumiLoginStartResult.unavailable(String message)
      : this._(
          status: BangumiLoginStartStatus.unavailable,
          openedUri: null,
          message: message,
        );

  const BangumiLoginStartResult.failed(String message)
      : this._(
          status: BangumiLoginStartStatus.failed,
          openedUri: null,
          message: message,
        );

  final BangumiLoginStartStatus status;
  final Uri? openedUri;
  final String? message;
}

enum BangumiTokenSignInStatus {
  signedIn,
  signedOut,
  failed,
}

final class BangumiTokenSignInResult {
  const BangumiTokenSignInResult._({
    required this.status,
    required this.profile,
    required this.message,
  });

  const BangumiTokenSignInResult.signedIn(UserProfileSnapshot profile)
      : this._(
          status: BangumiTokenSignInStatus.signedIn,
          profile: profile,
          message: null,
        );

  const BangumiTokenSignInResult.signedOut()
      : this._(
          status: BangumiTokenSignInStatus.signedOut,
          profile: null,
          message: null,
        );

  const BangumiTokenSignInResult.failed(String message)
      : this._(
          status: BangumiTokenSignInStatus.failed,
          profile: null,
          message: message,
        );

  final BangumiTokenSignInStatus status;
  final UserProfileSnapshot? profile;
  final String? message;
}

abstract interface class BangumiLoginController {
  Future<BangumiLoginStartResult> startLogin();

  Future<BangumiTokenSignInResult> signInWithAccessToken(String accessToken);
}

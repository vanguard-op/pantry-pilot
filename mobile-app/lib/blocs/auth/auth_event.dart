part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Fired at app start to check whether a valid session already exists.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Fired when the user taps "Sign in" on the login screen.
class AuthSignInRequested extends AuthEvent {
  const AuthSignInRequested();
}

/// Fired when the user taps "Sign out" in settings.
class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

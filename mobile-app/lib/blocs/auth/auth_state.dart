part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState extends AsyncState {
  const AuthState({
    this.status = AuthStatus.initial,
    super.requestStatus = const IdleStatus<void>(),
  });

  const AuthState.initial() : this();

  final AuthStatus status;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  @override
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({AuthStatus? status, Status<void>? requestStatus}) {
    return AuthState(
      status: status ?? this.status,
      requestStatus: requestStatus ?? this.requestStatus,
    );
  }

  @override
  List<Object?> get props => [status, ...asyncProps];
}

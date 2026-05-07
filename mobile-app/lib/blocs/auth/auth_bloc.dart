import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../core/async_state.dart';
import '../../data/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthState.initial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final AuthRepository _authRepository;

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        requestStatus: LoadingStatus<void>(actionKey: event.actionKey),
      ),
    );

    final authenticated = await _authRepository.isAuthenticated();
    final nextStatus = authenticated
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;

    emit(
      state.copyWith(
        status: nextStatus,
        requestStatus: SuccessStatus<void>(actionKey: event.actionKey),
      ),
    );
    emit(
      state.copyWith(
        status: nextStatus,
        requestStatus: IdleStatus<void>(actionKey: event.actionKey),
      ),
    );
  }

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        requestStatus: LoadingStatus<void>(actionKey: event.actionKey),
      ),
    );

    final success = await _authRepository.signIn();
    if (success) {
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          requestStatus: SuccessStatus<void>(actionKey: event.actionKey),
        ),
      );
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          requestStatus: IdleStatus<void>(actionKey: event.actionKey),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        requestStatus: ErrorStatus<void>(
          message:
              _authRepository.lastError ??
              'Could not sign in. Please try again.',
          actionKey: event.actionKey,
        ),
      ),
    );
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        requestStatus: LoadingStatus<void>(actionKey: event.actionKey),
      ),
    );
    await _authRepository.signOut();
    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        requestStatus: SuccessStatus<void>(actionKey: event.actionKey),
      ),
    );
    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        requestStatus: IdleStatus<void>(actionKey: event.actionKey),
      ),
    );
  }
}

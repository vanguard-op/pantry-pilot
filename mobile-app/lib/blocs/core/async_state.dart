import 'package:equatable/equatable.dart';

abstract interface class ActionTrackedEvent {
  String? get actionKey;
}

sealed class Status<T> extends Equatable {
  const Status({this.data, this.actionKey});

  final T? data;
  final String? actionKey;

  @override
  List<Object?> get props => <Object?>[data, actionKey];
}

final class IdleStatus<T> extends Status<T> {
  const IdleStatus({super.actionKey});
}

final class LoadingStatus<T> extends Status<T> {
  const LoadingStatus({this.message = 'Loading...', super.actionKey});

  final String message;

  @override
  List<Object?> get props => <Object?>[...super.props, message];
}

final class SuccessStatus<T> extends Status<T> {
  const SuccessStatus({super.data, super.actionKey});
}

final class ErrorStatus<T> extends Status<T> {
  const ErrorStatus({
    required this.message,
    this.code,
    this.cause,
    super.data,
    super.actionKey,
  });

  final String message;
  final String? code;
  final Object? cause;

  @override
  List<Object?> get props => <Object?>[...super.props, message, code, cause];
}

abstract class AsyncState extends Equatable {
  const AsyncState({this.requestStatus = const IdleStatus<void>()});

  final Status<void> requestStatus;

  bool get isLoading => requestStatus is LoadingStatus<void>;
  bool get hasError => requestStatus is ErrorStatus<void>;

  ErrorStatus<void>? get errorStatus {
    final status = requestStatus;
    return status is ErrorStatus<void> ? status : null;
  }

  String? get errorMessage => errorStatus?.message;

  List<Object?> get asyncProps => <Object?>[requestStatus];
}

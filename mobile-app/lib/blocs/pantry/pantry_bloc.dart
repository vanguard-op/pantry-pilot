import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../core/async_state.dart';
import '../../data/api/api_client.dart';
import '../../data/models/pantry_item.dart';
import '../../data/repositories/pantry_repository.dart';

part 'pantry_event.dart';
part 'pantry_state.dart';

class PantryBloc extends Bloc<PantryEvent, PantryState> {
  PantryBloc({required PantryRepository pantryRepository})
    : _pantryRepository = pantryRepository,
      super(const PantryState()) {
    on<PantryStarted>(_onStarted);
    on<PantryItemsChanged>(_onItemsChanged);
    on<PantryItemAdded>(_onItemAdded);
    on<PantryItemUpdated>(_onItemUpdated);
    on<PantryItemDeleted>(_onItemDeleted);
    on<PantryRefreshed>(_onRefreshed);
    on<PantryRequestFailed>(_onRequestFailed);
  }

  final PantryRepository _pantryRepository;
  StreamSubscription<List<PantryItem>>? _subscription;

  Future<void> _onStarted(
    PantryStarted event,
    Emitter<PantryState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = _pantryRepository.watchAll().listen(
      (items) => add(PantryItemsChanged(items)),
      onError: (error) => add(
        PantryRequestFailed(
          _errorMessage(error),
          sourceActionKey: event.actionKey,
        ),
      ),
    );

    await _runRequest(event, emit, _pantryRepository.refresh);
  }

  void _onItemsChanged(PantryItemsChanged event, Emitter<PantryState> emit) {
    emit(state.copyWith(items: event.items));
  }

  Future<void> _onItemAdded(
    PantryItemAdded event,
    Emitter<PantryState> emit,
  ) async {
    await _runRequest(event, emit, () => _pantryRepository.addItem(event.item));
  }

  Future<void> _onItemUpdated(
    PantryItemUpdated event,
    Emitter<PantryState> emit,
  ) async {
    await _runRequest(
      event,
      emit,
      () => _pantryRepository.updateItem(event.item),
    );
  }

  Future<void> _onItemDeleted(
    PantryItemDeleted event,
    Emitter<PantryState> emit,
  ) async {
    await _runRequest(
      event,
      emit,
      () => _pantryRepository.deleteItem(event.id),
    );
  }

  Future<void> _onRefreshed(
    PantryRefreshed event,
    Emitter<PantryState> emit,
  ) async {
    await _runRequest(event, emit, _pantryRepository.refresh);
  }

  void _onRequestFailed(PantryRequestFailed event, Emitter<PantryState> emit) {
    emit(
      state.copyWith(
        requestStatus: ErrorStatus<void>(
          message: event.message,
          actionKey: event.actionKey,
        ),
      ),
    );
  }

  Future<void> _runRequest(
    PantryEvent event,
    Emitter<PantryState> emit,
    Future<void> Function() run,
  ) async {
    emit(
      state.copyWith(
        requestStatus: LoadingStatus<void>(actionKey: event.actionKey),
      ),
    );

    var failed = false;
    try {
      await run();
      emit(
        state.copyWith(
          requestStatus: SuccessStatus<void>(actionKey: event.actionKey),
        ),
      );
    } catch (error) {
      failed = true;
      emit(
        state.copyWith(
          requestStatus: ErrorStatus<void>(
            message: _errorMessage(error),
            actionKey: event.actionKey,
            cause: error,
          ),
        ),
      );
    } finally {
      if (!failed) {
        emit(
          state.copyWith(
            requestStatus: IdleStatus<void>(actionKey: event.actionKey),
          ),
        );
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Unable to update pantry right now.';
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

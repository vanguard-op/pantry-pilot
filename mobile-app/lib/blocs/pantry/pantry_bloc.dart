import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

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
    );
  }

  void _onItemsChanged(PantryItemsChanged event, Emitter<PantryState> emit) {
    emit(state.copyWith(items: event.items));
  }

  Future<void> _onItemAdded(
    PantryItemAdded event,
    Emitter<PantryState> emit,
  ) async {
    await _pantryRepository.addItem(event.item);
  }

  Future<void> _onItemUpdated(
    PantryItemUpdated event,
    Emitter<PantryState> emit,
  ) async {
    await _pantryRepository.updateItem(event.item);
  }

  Future<void> _onItemDeleted(
    PantryItemDeleted event,
    Emitter<PantryState> emit,
  ) async {
    await _pantryRepository.deleteItem(event.id);
  }

  Future<void> _onRefreshed(
    PantryRefreshed event,
    Emitter<PantryState> emit,
  ) async {
    await _pantryRepository.refresh();
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

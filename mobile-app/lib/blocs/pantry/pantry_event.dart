part of 'pantry_bloc.dart';

sealed class PantryEvent extends Equatable {
  const PantryEvent();

  @override
  List<Object?> get props => <Object?>[];
}

class PantryStarted extends PantryEvent {
  const PantryStarted();
}

class PantryItemsChanged extends PantryEvent {
  const PantryItemsChanged(this.items);

  final List<PantryItem> items;

  @override
  List<Object?> get props => <Object?>[items];
}

class PantryItemAdded extends PantryEvent {
  const PantryItemAdded(this.item);

  final PantryItem item;

  @override
  List<Object?> get props => <Object?>[item];
}

class PantryItemUpdated extends PantryEvent {
  const PantryItemUpdated(this.item);

  final PantryItem item;

  @override
  List<Object?> get props => <Object?>[item];
}

class PantryItemDeleted extends PantryEvent {
  const PantryItemDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => <Object?>[id];
}

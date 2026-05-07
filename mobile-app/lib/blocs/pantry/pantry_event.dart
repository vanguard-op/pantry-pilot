part of 'pantry_bloc.dart';

sealed class PantryEvent extends Equatable implements ActionTrackedEvent {
  const PantryEvent();

  @override
  String? get actionKey => null;

  @override
  List<Object?> get props => <Object?>[];
}

class PantryStarted extends PantryEvent {
  const PantryStarted();

  @override
  String get actionKey => 'pantry.started';
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
  String get actionKey => 'pantry.itemAdded';

  @override
  List<Object?> get props => <Object?>[item];
}

class PantryItemUpdated extends PantryEvent {
  const PantryItemUpdated(this.item);

  final PantryItem item;

  @override
  String get actionKey => 'pantry.itemUpdated';

  @override
  List<Object?> get props => <Object?>[item];
}

class PantryItemDeleted extends PantryEvent {
  const PantryItemDeleted(this.id);

  final String id;

  @override
  String get actionKey => 'pantry.itemDeleted';

  @override
  List<Object?> get props => <Object?>[id];
}

class PantryRefreshed extends PantryEvent {
  const PantryRefreshed();

  @override
  String get actionKey => 'pantry.refreshed';
}

class PantryRequestFailed extends PantryEvent {
  const PantryRequestFailed(this.message, {this.sourceActionKey});

  final String message;
  final String? sourceActionKey;

  @override
  String? get actionKey => sourceActionKey;

  @override
  List<Object?> get props => <Object?>[message, sourceActionKey];
}

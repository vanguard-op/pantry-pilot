part of 'pantry_bloc.dart';

class PantryState extends AsyncState {
  const PantryState({this.items = const <PantryItem>[], super.requestStatus});

  final List<PantryItem> items;

  List<PantryItem> get useSoonItems {
    final now = DateTime.now();
    return items
        .where((item) => item.expiryDate.difference(now).inDays <= 3)
        .toList(growable: false)
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
  }

  PantryState copyWith({List<PantryItem>? items, Status<void>? requestStatus}) {
    return PantryState(
      items: items ?? this.items,
      requestStatus: requestStatus ?? this.requestStatus,
    );
  }

  @override
  List<Object?> get props => <Object?>[items, ...asyncProps];
}

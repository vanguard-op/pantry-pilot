part of 'pantry_bloc.dart';

class PantryState extends Equatable {
  const PantryState({this.items = const <PantryItem>[]});

  final List<PantryItem> items;

  List<PantryItem> get useSoonItems {
    final now = DateTime.now();
    return items
        .where((item) => item.expiryDate.difference(now).inDays <= 3)
        .toList(growable: false)
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
  }

  PantryState copyWith({List<PantryItem>? items}) {
    return PantryState(items: items ?? this.items);
  }

  @override
  List<Object?> get props => <Object?>[items];
}

// lib/features/atlas/application/people_providers.dart
//
// Congress directory state: filters, the persisted home state, and the
// query into the local people table (fully offline).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';

const kHomeStateMetaKey = 'atlas.home_state';

/// Two-letter home state, persisted in AppMeta. Null until chosen.
final homeStateProvider = FutureProvider<String?>((ref) async {
  ref.watch(homeStateTickProvider);
  return ref.watch(databaseProvider).metaDao.get(kHomeStateMetaKey);
});

final homeStateTickProvider = StateProvider<int>((ref) => 0);

class DirectoryFilter {
  const DirectoryFilter({this.chamber, this.state, this.party, this.query = ''});

  final String? chamber; // senate | house | null = both
  final String? state;
  final String? party;
  final String query;

  DirectoryFilter copyWith({
    String? Function()? chamber,
    String? Function()? state,
    String? Function()? party,
    String? query,
  }) =>
      DirectoryFilter(
        chamber: chamber == null ? this.chamber : chamber(),
        state: state == null ? this.state : state(),
        party: party == null ? this.party : party(),
        query: query ?? this.query,
      );

  @override
  bool operator ==(Object other) =>
      other is DirectoryFilter &&
      other.chamber == chamber &&
      other.state == state &&
      other.party == party &&
      other.query == query;

  @override
  int get hashCode => Object.hash(chamber, state, party, query);
}

final directoryFilterProvider =
    StateProvider<DirectoryFilter>((ref) => const DirectoryFilter());

final directoryResultsProvider = FutureProvider<List<Person>>((ref) {
  final f = ref.watch(directoryFilterProvider);
  return ref.watch(databaseProvider).peopleDao.directory(
        chamber: f.chamber,
        state: f.state,
        party: f.party,
        query: f.query,
      );
});

final availableStatesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(databaseProvider).peopleDao.states(),
);

final personProvider = FutureProvider.family<Person?, String>(
  (ref, id) => ref.watch(databaseProvider).peopleDao.byId(id),
);

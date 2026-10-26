import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';

/// Reads `settings/store` (public). Always from the server: the order rules
/// check the delivery fee against the current document.
class StoreSettingsRepository {
  StoreSettingsRepository(this._db);

  final FirebaseFirestore _db;

  Future<StoreSettings> load() async {
    final doc = await _db
        .doc('settings/store')
        .get(const GetOptions(source: Source.server));
    final data = doc.data();
    if (data == null) throw StateError('settings/store is missing');
    return StoreSettings.fromJson(data);
  }
}

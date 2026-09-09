import 'package:drift/native.dart';
import '../../../domain/contracts/contracts.dart';
import '../files/app_paths.dart';
import '../managed_local_books.dart';
import 'user_database.dart';

/// One owner, one background connection per lifetime. No cross-file transactions.
class LocalDatabases {
  LocalDatabases._(this.users, this.localBooks);
  final UserDatabase users;
  final ManagedLocalBooks localBooks;
  static Future<Result<LocalDatabases>> open(AppPaths paths) async {
    UserDatabase? users;
    try {
      await paths.prepare();
      users = UserDatabase(
        NativeDatabase.createInBackground(paths.userDatabase),
      );
      await users.customSelect('SELECT 1').get();
      final imported = await ManagedLocalBooks.open(paths, users);
      if (imported case Success<ManagedLocalBooks>(:final value)) {
        return Success(LocalDatabases._(users, value));
      }
      throw StateError('Local book storage unavailable');
    } catch (_) {
      await users?.close();
      // Preserve every file, including corrupt or future-version databases.
      return Failure(
        AppFailure(
          kind: FailureKind.database,
          operation: Operation.libraryRead,
        ),
      );
    }
  }

  Future<void> close() async {
    await localBooks.close();
    await users.close();
  }
}

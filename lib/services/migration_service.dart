import 'package:local_keep/services/hive_database_service.dart';

class MigrationService {
  // Check if migration is needed
  static Future<bool> needsMigration() async {
    // Since SQLite is removed, no migration is needed
    return false;
  }

  // Simplified migration - just initialize Hive
  static Future<void> migrateSqliteToHive(String password) async {
    print('Initializing Hive database...');

    // Initialize Hive
    await HiveDatabaseService.initialize();
    HiveDatabaseService.setPassword(password);

    print('Hive database initialized successfully.');
  }
}

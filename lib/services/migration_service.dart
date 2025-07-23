class MigrationService {
  static Future<bool> needsMigration() async {
    return false;
  }

  static Future<void> migrateSqliteToHive(String password) async {
    // No migration needed
  }
}

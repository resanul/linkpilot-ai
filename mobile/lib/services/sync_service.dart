import 'api_client.dart';
import 'local_db_service.dart';
import '../models/post_model.dart';

class SyncResult {
  final bool success;
  final int syncedCount;
  final String? errorMessage;
  SyncResult({required this.success, this.syncedCount = 0, this.errorMessage});
}

class SyncService {
  final ApiClient apiClient;
  final LocalDbService dbService;

  SyncService({
    required this.apiClient,
    LocalDbService? dbService,
  }) : dbService = dbService ?? LocalDbService.instance;

  Future<SyncResult> synchronize() async {
    try {
      // 1. Gather all unsynced local posts
      final unsynced = await dbService.getUnsyncedPosts();

      // 2. Push unsynced and fetch updated cloud posts
      final cloudPosts = await apiClient.syncPosts(unsynced);

      // 3. Update local SQLite cache with definitive cloud records
      for (final post in cloudPosts) {
        await dbService.insertOrUpdatePost(post.copyWith(isSynced: true));
      }

      return SyncResult(success: true, syncedCount: cloudPosts.length);
    } catch (e) {
      return SyncResult(success: false, errorMessage: e.toString());
    }
  }

  Future<List<PostModel>> loadPosts({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await synchronize();
    }
    final localPosts = await dbService.getAllPosts();
    if (localPosts.isEmpty && !forceRefresh) {
      // First run or empty cache: try to sync from cloud
      await synchronize();
      return await dbService.getAllPosts();
    }
    return localPosts;
  }
}

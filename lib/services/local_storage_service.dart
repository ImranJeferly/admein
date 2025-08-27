import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/ad_model.dart';
import '../models/performance_model.dart';

class LocalStorageService {
  static Database? _database;
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _database = await _initDatabase();
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'admain.db');
    
    return await openDatabase(
      path,
      version: 5, // Increment version to force upgrade and add file_name column
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE ads(
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            url TEXT NOT NULL,
            duration INTEGER NOT NULL,
            qr_link TEXT,
            text TEXT,
            quiz TEXT,
            created_at TEXT NOT NULL,
            local_path TEXT,
            file_name TEXT
          )
        ''');
        
        await db.execute('''
          CREATE TABLE ad_performances(
            ad_id TEXT PRIMARY KEY,
            view_count INTEGER DEFAULT 0,
            played_seconds REAL DEFAULT 0.0,
            click_count INTEGER DEFAULT 0,
            last_updated TEXT NOT NULL
          )
        ''');
        
        await db.execute('''
          CREATE TABLE ride_ratings(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rating INTEGER NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
        
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('📦 [DB] Upgrading database from version $oldVersion to $newVersion');
        
        if (oldVersion < 2) {
          print('📦 [DB] Adding text column...');
          await db.execute('ALTER TABLE ads ADD COLUMN text TEXT');
        }
        
        if (oldVersion < 4) {
          print('📦 [DB] Adding quiz column...');
          // Check if quiz column already exists to avoid errors
          try {
            await db.execute('ALTER TABLE ads ADD COLUMN quiz TEXT');
            print('📦 [DB] Quiz column added successfully');
          } catch (e) {
            if (e.toString().contains('duplicate column name')) {
              print('📦 [DB] Quiz column already exists, skipping');
            } else {
              print('📦 [DB] Error adding quiz column: $e');
              rethrow;
            }
          }
        }
        
        if (oldVersion < 5) {
          print('📦 [DB] Adding file_name column...');
          // Check if file_name column already exists to avoid errors
          try {
            await db.execute('ALTER TABLE ads ADD COLUMN file_name TEXT');
            print('📦 [DB] file_name column added successfully');
          } catch (e) {
            if (e.toString().contains('duplicate column name')) {
              print('📦 [DB] file_name column already exists, skipping');
            } else {
              print('📦 [DB] Error adding file_name column: $e');
              rethrow;
            }
          }
        }
        
        print('📦 [DB] Database upgrade completed');
      },
    );
  }

  // Ad Storage with smart update logic
  static Future<void> saveAds(List<AdModel> ads) async {
    final db = _database!;
    
    print('💾 [STORAGE] Updating ads in local storage...');
    
    // Get existing ads from database
    final existingAds = await getAds();
    final existingIds = existingAds.map((ad) => ad.id).toSet();
    final newIds = ads.map((ad) => ad.id).toSet();
    
    // Find ads to remove (exist locally but not in new list)
    final idsToRemove = existingIds.difference(newIds);
    if (idsToRemove.isNotEmpty) {
      print('💾 [STORAGE] Removing ${idsToRemove.length} ads: $idsToRemove');
      for (final id in idsToRemove) {
        await db.delete('ads', where: 'id = ?', whereArgs: [id]);
        // Also clean up performance data for removed ads
        await db.delete('ad_performances', where: 'ad_id = ?', whereArgs: [id]);
      }
    }
    
    // Find ads to add/update
    final idsToAddOrUpdate = newIds.difference(existingIds);
    if (idsToAddOrUpdate.isNotEmpty) {
      print('💾 [STORAGE] Adding/updating ${idsToAddOrUpdate.length} ads: $idsToAddOrUpdate');
    }
    
    // Insert or update all ads from backend
    for (var ad in ads) {
      await db.insert('ads', ad.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      print('💾 [STORAGE] Saved ad: ${ad.id} - ${ad.type} - ${ad.url}');
    }
    
    print('💾 [STORAGE] Total ads in storage: ${ads.length}');
  }

  static Future<List<AdModel>> getAds() async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query('ads');
    
    return List.generate(maps.length, (i) {
      return AdModel.fromJson(maps[i]);
    });
  }

  // Performance Tracking
  static Future<void> updateAdPerformance(String adId, {
    int? viewIncrement,
    double? playedSecondsIncrement,
    int? clickIncrement,
  }) async {
    final db = _database!;
    
    // Get existing performance or create new
    final existing = await db.query(
      'ad_performances',
      where: 'ad_id = ?',
      whereArgs: [adId],
    );
    
    AdPerformance performance;
    if (existing.isEmpty) {
      performance = AdPerformance(adId: adId);
    } else {
      performance = AdPerformance.fromJson(existing.first);
    }
    
    // Update values
    if (viewIncrement != null) performance.viewCount += viewIncrement;
    if (playedSecondsIncrement != null) performance.playedSeconds += playedSecondsIncrement;
    if (clickIncrement != null) performance.clickCount += clickIncrement;
    performance.lastUpdated = DateTime.now();
    
    await db.insert(
      'ad_performances',
      performance.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<AdPerformance>> getAllAdPerformances() async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query('ad_performances');
    
    return List.generate(maps.length, (i) {
      return AdPerformance.fromJson(maps[i]);
    });
  }

  static Future<void> clearAdPerformances() async {
    final db = _database!;
    await db.delete('ad_performances');
  }

  // Rating Storage
  static Future<void> saveRideRating(int rating) async {
    final db = _database!;
    final rideRating = RideRating(rating: rating);
    
    await db.insert('ride_ratings', rideRating.toJson());
  }

  static Future<List<RideRating>> getAllRideRatings() async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query('ride_ratings');
    
    return List.generate(maps.length, (i) {
      return RideRating.fromJson(maps[i]);
    });
  }

  static Future<void> clearRideRatings() async {
    final db = _database!;
    await db.delete('ride_ratings');
  }

  // Detailed Rating Storage using SharedPreferences
  static Future<void> saveDetailedRating(String ratingType, int rating) async {
    await _prefs!.setInt('rating_$ratingType', rating);
    await _prefs!.setString('rating_${ratingType}_timestamp', DateTime.now().toIso8601String());
    
    print('💾 [DETAILED_RATING] Saved $ratingType: $rating');
  }

  static Map<String, int> getAllDetailedRatings() {
    final ratings = <String, int>{};
    final ratingTypes = ['interest', 'attention', 'frequency', 'quality'];
    
    for (final type in ratingTypes) {
      ratings[type] = _prefs!.getInt('rating_$type') ?? 0;
    }
    
    return ratings;
  }

  static Map<String, String> getAllDetailedRatingsWithTimestamp() {
    final ratingsWithTime = <String, String>{};
    final ratingTypes = ['interest', 'attention', 'frequency', 'quality'];
    
    for (final type in ratingTypes) {
      final rating = _prefs!.getInt('rating_$type') ?? 0;
      final timestamp = _prefs!.getString('rating_${type}_timestamp') ?? '';
      ratingsWithTime[type] = '$rating|$timestamp';
    }
    
    return ratingsWithTime;
  }

  static Future<void> clearDetailedRatings() async {
    final ratingTypes = ['interest', 'attention', 'frequency', 'quality'];
    
    for (final type in ratingTypes) {
      await _prefs!.remove('rating_$type');
      await _prefs!.remove('rating_${type}_timestamp');
    }
    
    print('💾 [DETAILED_RATING] Cleared all detailed ratings');
  }

  // Settings
  static Future<void> saveDriverId(String driverId) async {
    await _prefs!.setString('driver_id', driverId);
  }

  static String? getDriverId() {
    return _prefs!.getString('driver_id');
  }

  static Future<void> saveAuthToken(String token) async {
    await _prefs!.setString('auth_token', token);
  }

  static String? getAuthToken() {
    return _prefs!.getString('auth_token');
  }

  // Save authentication state
  static Future<void> saveAuthenticationState({
    required String authToken,
    required String driverId,
    required String actualDriverId,
    String? logoUrl,
  }) async {
    await _prefs!.setString('auth_token', authToken);
    await _prefs!.setString('driver_id', driverId);
    await _prefs!.setString('actual_driver_id', actualDriverId);
    if (logoUrl != null) {
      await _prefs!.setString('logo_url', logoUrl);
    }
    await _prefs!.setBool('is_authenticated', true);
    print('💾 [AUTH] Saved authentication state');
  }

  // Get saved authentication state
  static Map<String, String?> getSavedAuthenticationState() {
    final isAuthenticated = _prefs!.getBool('is_authenticated') ?? false;
    if (!isAuthenticated) {
      return {};
    }
    
    return {
      'auth_token': _prefs!.getString('auth_token'),
      'driver_id': _prefs!.getString('driver_id'),
      'actual_driver_id': _prefs!.getString('actual_driver_id'),
      'logo_url': _prefs!.getString('logo_url'),
    };
  }

  // Clear authentication state
  static Future<void> clearAuthenticationState() async {
    await _prefs!.remove('is_authenticated');
    await _prefs!.remove('auth_token');
    await _prefs!.remove('driver_id');
    await _prefs!.remove('actual_driver_id');
    await _prefs!.remove('logo_url');
    print('💾 [AUTH] Cleared authentication state');
  }

  // Quiz Answers Storage - persist selected answers per ad
  static Future<void> saveQuizAnswersForAd(String adId, Map<String, String> questionAnswers) async {
    final String key = 'quiz_answers_$adId';
    final String jsonData = jsonEncode(questionAnswers);
    await _prefs!.setString(key, jsonData);
    print('💾 [QUIZ] Saved ${questionAnswers.length} answers for ad: $adId');
  }

  static Map<String, String> getQuizAnswersForAd(String adId) {
    final String key = 'quiz_answers_$adId';
    final String? jsonData = _prefs!.getString(key);
    
    if (jsonData != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(jsonData);
        final Map<String, String> answers = decoded.cast<String, String>();
        print('💾 [QUIZ] Loaded ${answers.length} saved answers for ad: $adId');
        return answers;
      } catch (e) {
        print('💾 [QUIZ] Error loading answers for ad $adId: $e');
        return {};
      }
    }
    
    return {};
  }

  static Future<Map<String, Map<String, String>>> getAllQuizAnswers() async {
    final Map<String, Map<String, String>> allAnswers = {};
    final Set<String> keys = _prefs!.getKeys();
    
    for (final key in keys) {
      if (key.startsWith('quiz_answers_')) {
        final String adId = key.replaceAll('quiz_answers_', '');
        final answers = getQuizAnswersForAd(adId);
        if (answers.isNotEmpty) {
          allAnswers[adId] = answers;
        }
      }
    }
    
    print('💾 [QUIZ] Found quiz answers for ${allAnswers.length} ads');
    return allAnswers;
  }

  static Future<void> clearAllQuizAnswers() async {
    print('💾 [QUIZ] 🧹 Clearing all quiz answers on app restart...');
    final Set<String> keys = _prefs!.getKeys();
    final List<String> keysToRemove = keys.where((key) => key.startsWith('quiz_answers_')).toList();
    
    for (final key in keysToRemove) {
      await _prefs!.remove(key);
    }
    
    print('💾 [QUIZ] ✅ Cleared quiz answers for ${keysToRemove.length} ads');
  }
}
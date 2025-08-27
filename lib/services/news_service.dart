import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news_model.dart';

class NewsService {
  static const String _apiKey = 'pub_7287861283d7862a90ad4b1f67baf3be78d02';
  static const String _baseUrl = 'https://newsdata.io/api/1/latest';
  
  static List<NewsModel> _cachedNews = [];
  static int _newsIteration = 0;
  static DateTime? _lastFetch;
  
  static Future<List<NewsModel>> fetchNews() async {
    // Return cached news if less than 1 hour old
    if (_cachedNews.isNotEmpty && _lastFetch != null) {
      final now = DateTime.now();
      if (now.difference(_lastFetch!).inHours < 1) {
        print('📰 [NEWS] Using cached news data (${_cachedNews.length} articles)');
        return _cachedNews;
      }
    }
    
    try {
      print('📰 [NEWS] Fetching news...');
      final url = '$_baseUrl?apikey=$_apiKey&country=az&language=az';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'success' && data['results'] != null) {
          final List<dynamic> results = data['results'];
          
          // Filter articles that have descriptions
          _cachedNews = results
              .where((article) => article['description'] != null)
              .map((article) => NewsModel.fromJson(article))
              .toList();
          
          _lastFetch = DateTime.now();
          _newsIteration = 0; // Reset iteration
          
          print('📰 [NEWS] News fetched successfully (${_cachedNews.length} articles)');
          return _cachedNews;
        } else {
          print('⚠️ [NEWS] No news articles found');
          return [];
        }
      } else {
        print('❌ [NEWS] HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ [NEWS] Error fetching news: $e');
      return [];
    }
  }
  
  static NewsModel? getCurrentNewsArticle() {
    if (_cachedNews.isEmpty) return null;
    
    final article = _cachedNews[_newsIteration];
    
    print('📰 [NEWS] Displaying article ${_newsIteration + 1}/${_cachedNews.length}: ${article.title.length > 50 ? article.title.substring(0, 50) : article.title}...');
    return article;
  }
  
  static void moveToNextArticle() {
    if (_cachedNews.isNotEmpty) {
      _newsIteration = (_newsIteration + 1) % _cachedNews.length;
      print('📰 [NEWS] Advanced to next article for next cycle: ${_newsIteration + 1}/${_cachedNews.length}');
    }
  }
  
  static List<NewsModel> getCachedNews() {
    return _cachedNews;
  }
  
  static void resetIteration() {
    _newsIteration = 0;
  }
}
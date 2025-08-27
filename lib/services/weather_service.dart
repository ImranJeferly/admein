import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

class WeatherService {
  static const String _apiKey = '57dbdf331fcca0372fc78700616fd874';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  
  static WeatherModel? _cachedWeather;
  static DateTime? _lastFetch;
  
  static Future<WeatherModel?> fetchBakuWeather() async {
    // Return cached weather if less than 1 hour old
    if (_cachedWeather != null && _lastFetch != null) {
      final now = DateTime.now();
      if (now.difference(_lastFetch!).inHours < 1) {
        print('🌤️ [WEATHER] Using cached weather data (${_cachedWeather!.temperature}°C, ${_cachedWeather!.description})');
        return _cachedWeather;
      }
    }
    
    try {
      print('🌤️ [WEATHER] Fetching fresh weather data for Baku...');
      final url = '$_baseUrl?q=Baku&units=metric&appid=$_apiKey';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Weather API request timeout');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['cod'] == 200) {
          _cachedWeather = WeatherModel.fromJson(data);
          _lastFetch = DateTime.now();
          print('🌤️ [WEATHER] ✅ Fresh weather data fetched: ${_cachedWeather!.temperature}°C, ${_cachedWeather!.description}');
          return _cachedWeather;
        } else {
          print('❌ [WEATHER] API returned error: ${data['message']}');
          // Return cached data if available, even if expired
          if (_cachedWeather != null) {
            print('🌤️ [WEATHER] Returning expired cached weather as fallback');
            return _cachedWeather;
          }
          return null;
        }
      } else {
        print('❌ [WEATHER] HTTP error: ${response.statusCode}');
        // Return cached data if available, even if expired
        if (_cachedWeather != null) {
          print('🌤️ [WEATHER] Returning expired cached weather as fallback');
          return _cachedWeather;
        }
        return null;
      }
    } catch (e) {
      print('❌ [WEATHER] Error fetching weather: $e');
      // Return cached data if available, even if expired
      if (_cachedWeather != null) {
        print('🌤️ [WEATHER] Returning expired cached weather as fallback');
        return _cachedWeather;
      }
      return null;
    }
  }
  
  static WeatherModel? getCachedWeather() {
    return _cachedWeather;
  }
}
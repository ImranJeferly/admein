class WeatherModel {
  final String city;
  final String country;
  final String description;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int weatherId;

  WeatherModel({
    required this.city,
    required this.country,
    required this.description,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherId,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      city: json['name'] ?? 'Unknown',
      country: json['sys']['country'] ?? 'Unknown',
      description: json['weather'][0]['description'] ?? 'No description',
      temperature: (json['main']['temp'] ?? 0).toDouble(),
      feelsLike: (json['main']['feels_like'] ?? 0).toDouble(),
      humidity: json['main']['humidity'] ?? 0,
      windSpeed: (json['wind']['speed'] ?? 0).toDouble(),
      weatherId: json['weather'][0]['id'] ?? 800,
    );
  }

  String get weatherIcon {
    if (weatherId == 800) {
      return '☀️'; // Clear
    } else if (weatherId >= 200 && weatherId <= 232) {
      return '⛈️'; // Storm
    } else if (weatherId >= 600 && weatherId <= 622) {
      return '❄️'; // Snow
    } else if (weatherId >= 701 && weatherId <= 781) {
      return '🌫️'; // Haze
    } else if (weatherId >= 801 && weatherId <= 804) {
      return '☁️'; // Cloud
    } else if ((weatherId >= 500 && weatherId <= 531) || (weatherId >= 300 && weatherId <= 321)) {
      return '🌧️'; // Rain
    }
    return '🌤️'; // Default
  }
}
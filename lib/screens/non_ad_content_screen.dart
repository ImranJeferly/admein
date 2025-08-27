import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/app_state_service.dart';
import '../models/weather_model.dart';
import '../models/news_model.dart';
import '../models/driver_profile_model.dart';

class NonAdContentScreen extends StatelessWidget {
  const NonAdContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateService>(
      builder: (context, appState, child) {
        final contentType = appState.currentNonAdContent;
        
        return Scaffold(
          backgroundColor: const Color(0xFF2a2e6a), // App background color
          body: _buildContent(contentType),
        );
      },
    );
  }

  Widget _buildContent(NonAdContentType contentType) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            return ClipPath(
              clipper: CircularRevealClipper(
                fraction: animation.value,
              ),
              child: child!,
            );
          },
        );
      },
      child: Container(
        key: ValueKey(contentType),
        child: _getContentWidget(contentType),
      ),
    );
  }

  Widget _getContentWidget(NonAdContentType contentType) {
    switch (contentType) {
      case NonAdContentType.weather:
        return _buildWeatherContent();
      case NonAdContentType.news:
        return _buildNewsContent();
      case NonAdContentType.rideInfo:
        return _buildRideInfoContent();
      case NonAdContentType.rate:
        return _buildRateContent();
    }
  }

  Widget _buildWeatherContent() {
    return Consumer<AppStateService>(
      builder: (context, appState, child) {
        final weather = appState.currentWeather;
        
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF2a2e6a), // App background color
          ),
          child: weather != null
              ? _buildWeatherDisplay(context, weather)
              : _buildWeatherLoading(),
        );
      },
    );
  }

  Widget _buildWeatherDisplay(BuildContext context, WeatherModel weather) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modern Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFffc107).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.wb_sunny_outlined,
                    color: Color(0xFFffc107),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'HAVA',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f5f5),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Main content row - Temperature on left, Stats on right
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.75, // 75% of screen width
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left side - Large temperature with city and status
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Weather icon above temperature (within column)
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              child: Text(
                                weather.weatherIcon,
                                style: const TextStyle(fontSize: 120),
                              ),
                            ),
                            
                            // Large temperature number with same size degree symbol
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${weather.temperature.round()}',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Color(0xFFf5f5f5),
                                      fontSize: 90,
                                      fontWeight: FontWeight.bold,
                                      height: 0.9,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: '°',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Color(0xFFffc107),
                                      fontSize: 90,
                                      fontWeight: FontWeight.bold,
                                      height: 0.9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // City and status closer to temperature
                            Text(
                              '${weather.city}, ${weather.country}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Color(0xFFf5f5f5),
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.5,
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            Text(
                              weather.description.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: const Color(0xFFffc107).withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Thin divider line
                      Container(
                        width: 1,
                        height: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFffc107).withOpacity(0.3),
                        ),
                      ),
                      
                      // Right side - Stats column
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildWeatherStat(
                              'HİSS EDİLİR',
                              '${weather.feelsLike.round()}°',
                              Icons.thermostat_outlined,
                            ),
                            
                            const SizedBox(height: 32),
                            
                            _buildWeatherStat(
                              'RÜTUBƏT',
                              '${weather.humidity}%',
                              Icons.water_drop_outlined,
                            ),
                            
                            const SizedBox(height: 32),
                            
                            _buildWeatherStat(
                              'KÜLƏK',
                              '${weather.windSpeed.round()} km/s',
                              Icons.air_outlined,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const Spacer(),
            
            // Bottom minimal line
            Container(
              height: 1,
              width: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFffc107).withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWeatherStat(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              icon,
              size: 16,
              color: const Color(0xFFffc107).withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: const Color(0xFFf5f5f5).withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFFf5f5f5),
            fontSize: 28,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherDetailCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.95), // Dark blue surface
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.blue[700],
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: Colors.blue[900],
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF3B82F6),
            strokeWidth: 4,
          ),
          SizedBox(height: 24),
          Text(
            'Hava məlumatları yüklənir...',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsContent() {
    return Consumer<AppStateService>(
      builder: (context, appState, child) {
        final news = appState.currentNews;
        
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF2a2e6a), // App background color
          ),
          child: news != null
              ? _buildNewsDisplay(news)
              : _buildNewsLoading(),
        );
      },
    );
  }

  Widget _buildNewsDisplay(NewsModel news) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modern Header - matching weather page
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFffc107).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.newspaper_outlined,
                    color: Color(0xFFffc107),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'XƏBƏRLƏR',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f5f5),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // Main content row - Text on left, Image on right
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left side - Text content
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title with matching styling
                        Text(
                          news.title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Color(0xFFf5f5f5),
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.left,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Date with yellow accent
                        if (news.formattedDate.isNotEmpty)
                          Text(
                            news.formattedDate.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: const Color(0xFFffc107).withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.0,
                            ),
                          ),
                        
                        const SizedBox(height: 24),
                        
                        // Description with proper styling
                        if (news.description != null && news.description!.isNotEmpty)
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                news.description!,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFFf5f5f5),
                                  fontSize: 16,
                                  height: 1.5,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Spacing between text and image
                  const SizedBox(width: 24),
                  
                  // Right side - News image
                  if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
                    Expanded(
                      flex: 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFffc107).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Image.network(
                            news.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  color: const Color(0xFFffc107),
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFFffc107).withOpacity(0.1),
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Color(0xFFffc107),
                                    size: 48,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Source with subtle styling
            Text(
              'Mənbə: ${_extractDomain(news.sourceUrl)}',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: const Color(0xFFf5f5f5).withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.left,
            ),
            
            const SizedBox(height: 20),
            
            // Bottom minimal line - matching weather page
            Container(
              height: 1,
              width: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFffc107).withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFFffc107),
            strokeWidth: 4,
          ),
          SizedBox(height: 24),
          Text(
            'Xəbərlər yüklənir...',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Color(0xFFf5f5f5),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (e) {
      return url;
    }
  }

  Widget _buildRideInfoContent() {
    return Consumer<AppStateService>(
      builder: (context, appState, child) {
        final driverProfile = appState.driverProfile;
        
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF2a2e6a), // App background color
          ),
          child: driverProfile != null
              ? _buildRideInfoDisplay(driverProfile)
              : _buildRideInfoLoading(),
        );
      },
    );
  }

  Widget _buildRideInfoDisplay(DriverProfileModel driverProfile) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modern Header - matching weather and news pages
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFffc107).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_car_outlined,
                    color: Color(0xFFffc107),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'SƏYAHƏT',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f5f5),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Title
            const Text(
              'Sifariş Məlumatları',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFFf5f5f5),
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Main content table with 3 sections
            Expanded(
              child: Column(
                children: [
                  // Section 1: Driver Information
                  Expanded(
                    child: _buildTableSection(
                      'Sürücü Məlumatları',
                      Icons.person_outline,
                      [
                        _buildTableRow('Ad', driverProfile.fullName, Icons.badge_outlined),
                        _buildTableRow('Telefon', driverProfile.driverPhone, Icons.phone_outlined),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Section 2: Vehicle Information
                  Expanded(
                    child: _buildTableSection(
                      'Avtomobil Məlumatları',
                      Icons.directions_car_outlined,
                      [
                        _buildTableRow('Model', driverProfile.fullCarModel, Icons.car_rental_outlined),
                        _buildTableRow('Qeydiyyat', driverProfile.carNormalizedNumber, Icons.confirmation_number_outlined),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Section 3: Company Information
                  Expanded(
                    child: _buildTableSection(
                      'Şirkət Məlumatları',
                      Icons.business_outlined,
                      [
                        _buildTableRow('Park', driverProfile.taxiParkName ?? 'Senior\'s', Icons.apartment_outlined),
                        _buildTableRow('Əlaqə', driverProfile.taxiParkPhone ?? '+994998666664', Icons.contact_phone_outlined),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Bottom minimal line - matching other pages
            Container(
              height: 1,
              width: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFffc107).withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideInfoLoading() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - matching other pages
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFffc107).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_car_outlined,
                    color: Color(0xFFffc107),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'SƏYAHƏT',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f5f5),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Title
            const Text(
              'Sifariş Məlumatları',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFFf5f5f5),
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            
            const Spacer(),
            
            // Loading indicator
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFffc107),
                    strokeWidth: 4,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Sürücü məlumatları yüklənir...',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFFf5f5f5),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Bottom minimal line
            Container(
              height: 1,
              width: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFffc107).withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTableSection(String title, IconData titleIcon, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFffc107).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFffc107).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Section header
          Row(
            children: [
              Icon(
                titleIcon,
                color: const Color(0xFFffc107),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFFffc107),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Section content
          Expanded(
            child: Column(
              children: [
                rows[0],
                _buildDivider(),
                rows[1],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          // Icon
          Icon(
            icon,
            color: const Color(0xFFffc107),
            size: 16,
          ),
          const SizedBox(width: 10),
          // Label
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: const Color(0xFFf5f5f5).withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Value
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFFf5f5f5),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFffc107).withOpacity(0.1),
      ),
    );
  }


  Widget _buildRateContent() {
    return Consumer<AppStateService>(
      builder: (context, appState, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF2a2e6a), // App background color
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modern Header - matching other pages with Admein logo
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFffc107).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.star_outline,
                          color: Color(0xFFffc107),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'REYTİNQ',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Color(0xFFf5f5f5),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const Spacer(), // Push the logo to the right side
                      // Admein logo on the right
                      Container(
                        height: 48,
                        width: 90,
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Title
                  const Text(
                    'Reklam Təcrübənizi Qiymətləndirin',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFFf5f5f5),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Rating sections in a 2x2 grid - scrollable
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 2.5, // Much higher ratio to make rows shorter
                      children: [
                        _buildSimpleRatingSection(
                          'Reklamlar maraqlarınıza uyğun idi?',
                          'interest',
                          appState,
                        ),
                        _buildSimpleRatingSection(
                          'Reklamlar diqqətinizi çəkdi?',
                          'attention',
                          appState,
                        ),
                        _buildSimpleRatingSection(
                          'Reklamların tezliyi normal idi?',
                          'frequency',
                          appState,
                        ),
                        _buildSimpleRatingSection(
                          'Keyfiyyət cəlbedici idi?',
                          'quality',
                          appState,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Bottom minimal line - matching other pages
                  Container(
                    height: 1,
                    width: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFffc107).withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Çox pis';
      case 2:
        return 'Pis';
      case 3:
        return 'Orta';
      case 4:
        return 'Yaxşı';
      case 5:
        return 'Mükəmməl';
      default:
        return '';
    }
  }

  Widget _buildSimpleRatingSection(String question, String ratingType, AppStateService appState) {
    final currentRating = appState.getRating(ratingType);
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Question text
        Text(
          question,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFFf5f5f5),
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 12),
        
        // Star rating
        Row(
          key: ValueKey('rating_row_${ratingType}_$currentRating'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            final isSelected = starIndex <= currentRating;
            
            return GestureDetector(
              onTap: () {
                print('Tapping star $starIndex for $ratingType'); // Debug
                appState.setRating(ratingType, starIndex);
              },
              child: CustomStar(
                key: ValueKey('star_${ratingType}_${starIndex}'),
                size: 42,
                color: const Color(0xFFffc107),
                filled: isSelected,
                delay: Duration(milliseconds: (index * 100)), // 100ms delay between each star
              ),
            );
          }),
        ),
        
        // Rating text that appears when stars are selected
        const SizedBox(height: 8),
        AnimatedOpacity(
          opacity: currentRating > 0 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Text(
            _getRatingText(currentRating),
            style: TextStyle(
              fontFamily: 'Poppins',
              color: const Color(0xFFffc107).withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

}

class CustomStar extends StatefulWidget {
  final double size;
  final Color color;
  final bool filled;
  final Duration delay;

  const CustomStar({
    super.key,
    required this.size,
    required this.color,
    this.filled = false,
    this.delay = Duration.zero,
  });

  @override
  State<CustomStar> createState() => _CustomStarState();
}

class _CustomStarState extends State<CustomStar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fillAnimation;
  bool _currentFilled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800), // Slower for easier visibility
      vsync: this,
    );
    _fillAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutBack,
    ));
    
    _currentFilled = widget.filled ?? false;
    if (widget.filled == true) {
      _controller.value = 1.0;
    } else {
      _controller.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(CustomStar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if ((oldWidget.filled ?? false) != (widget.filled ?? false)) {
      _animateToNewState();
    }
  }

  void _animateToNewState() async {
    print('Animating star with delay: ${widget.delay.inMilliseconds}ms, filled: ${widget.filled}');
    
    if (widget.delay > Duration.zero) {
      await Future.delayed(widget.delay);
    }
    
    if (mounted) {
      _currentFilled = widget.filled;
      print('Starting animation: filled=$_currentFilled');
      if (widget.filled) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fillAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: AnimatedStarPainter(
            color: widget.color,
            fillProgress: _fillAnimation.value,
            shouldFill: _currentFilled,
          ),
        );
      },
    );
  }
}

class AnimatedStarPainter extends CustomPainter {
  final Color color;
  final double fillProgress;
  final bool shouldFill;

  AnimatedStarPainter({
    required this.color,
    required this.fillProgress,
    required this.shouldFill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print('Painting star: shouldFill=$shouldFill, fillProgress=$fillProgress');
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;
    
    // Create cartoonish rounded star
    final path = _createRoundedStar(center, radius);
    
    // Background stroke (always visible)
    final strokePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    
    canvas.drawPath(path, strokePaint);
    
    // Simple fill without clipping for now to debug animation
    if (shouldFill) {
      final fillPaint = Paint()
        ..color = color.withOpacity(fillProgress)
        ..style = PaintingStyle.fill;
      
      canvas.drawPath(path, fillPaint);
      
      // Animated stroke gets brighter as it fills
      final brightStrokePaint = Paint()
        ..color = color.withOpacity(0.8 * fillProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      
      canvas.drawPath(path, brightStrokePaint);
    }
  }
  
  Path _createRoundedStar(Offset center, double radius) {
    final path = Path();
    final outerRadius = radius;
    final innerRadius = radius * 0.5; // Increased for more rounded shape
    final numPoints = 5;
    
    List<Offset> points = [];
    
    // Calculate all points first
    for (int i = 0; i < numPoints * 2; i++) {
      final angle = (i * math.pi / numPoints) - math.pi / 2;
      final isOuter = i % 2 == 0;
      final currentRadius = isOuter ? outerRadius : innerRadius;
      
      final x = center.dx + currentRadius * math.cos(angle);
      final y = center.dy + currentRadius * math.sin(angle);
      points.add(Offset(x, y));
    }
    
    // Create very smooth, rounded curves between points
    path.moveTo(points[0].dx, points[0].dy);
    
    for (int i = 1; i < points.length; i++) {
      final currentPoint = points[i];
      final prevPoint = points[i - 1];
      
      // Calculate control points for much smoother curves
      final controlDistance = 0.8; // Much higher for very rounded shape
      
      final cp1X = prevPoint.dx + (currentPoint.dx - prevPoint.dx) * controlDistance;
      final cp1Y = prevPoint.dy + (currentPoint.dy - prevPoint.dy) * controlDistance;
      
      final cp2X = currentPoint.dx - (currentPoint.dx - prevPoint.dx) * (1 - controlDistance);
      final cp2Y = currentPoint.dy - (currentPoint.dy - prevPoint.dy) * (1 - controlDistance);
      
      path.cubicTo(cp1X, cp1Y, cp2X, cp2Y, currentPoint.dx, currentPoint.dy);
    }
    
    // Close the path with a smooth curve back to start
    final lastPoint = points.last;
    final firstPoint = points.first;
    final cp1X = lastPoint.dx + (firstPoint.dx - lastPoint.dx) * 0.8;
    final cp1Y = lastPoint.dy + (firstPoint.dy - lastPoint.dy) * 0.8;
    final cp2X = firstPoint.dx - (firstPoint.dx - lastPoint.dx) * 0.2;
    final cp2Y = firstPoint.dy - (firstPoint.dy - lastPoint.dy) * 0.2;
    
    path.cubicTo(cp1X, cp1Y, cp2X, cp2Y, firstPoint.dx, firstPoint.dy);
    path.close();
    
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is AnimatedStarPainter) {
      return oldDelegate.color != color || 
             oldDelegate.fillProgress != fillProgress ||
             oldDelegate.shouldFill != shouldFill;
    }
    return true;
  }
}

class StarPainter extends CustomPainter {
  final Color color;
  final bool filled;

  StarPainter({required this.color, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;
    
    // Create cartoonish rounded star
    final path = _createRoundedStar(center, radius);
    
    // Fill paint for selected stars
    if (filled) {
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }
    
    // Stroke paint for outline
    final strokePaint = Paint()
      ..color = filled ? color.withOpacity(0.8) : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    
    canvas.drawPath(path, strokePaint);
  }
  
  Path _createRoundedStar(Offset center, double radius) {
    final path = Path();
    final outerRadius = radius;
    final innerRadius = radius * 0.4;
    final numPoints = 5;
    
    for (int i = 0; i < numPoints * 2; i++) {
      final angle = (i * math.pi / numPoints) - math.pi / 2;
      final isOuter = i % 2 == 0;
      final currentRadius = isOuter ? outerRadius : innerRadius;
      
      // Add slight randomness and rounding for cartoonish effect
      final adjustedRadius = currentRadius + (isOuter ? 2 : -1);
      
      final x = center.dx + adjustedRadius * math.cos(angle);
      final y = center.dy + adjustedRadius * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Create smooth curves instead of sharp points
        final prevAngle = ((i - 1) * math.pi / numPoints) - math.pi / 2;
        final prevRadius = (i - 1) % 2 == 0 ? outerRadius : innerRadius;
        final prevX = center.dx + prevRadius * math.cos(prevAngle);
        final prevY = center.dy + prevRadius * math.sin(prevAngle);
        
        // Control points for smooth curves
        final controlX1 = prevX + (x - prevX) * 0.3;
        final controlY1 = prevY + (y - prevY) * 0.3;
        final controlX2 = prevX + (x - prevX) * 0.7;
        final controlY2 = prevY + (y - prevY) * 0.7;
        
        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }
    
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is StarPainter) {
      return oldDelegate.color != color || oldDelegate.filled != filled;
    }
    return true;
  }
}

class CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;

  CircularRevealClipper({required this.fraction});

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide;
    final radius = maxRadius * fraction;
    
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
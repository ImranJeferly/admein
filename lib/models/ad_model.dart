import 'quiz_model.dart';

class AdModel {
  final String id;
  final String type; // 'video', 'image', or 'quiz'
  final String url; // Remote URL
  final String? localPath; // Local file path
  final int duration; // for images: 15s, videos: 30s, quizzes: 30s
  final String? qrLink;
  final String? text; // Text to display on QR screen
  final QuizModel? quiz; // Quiz data when type is 'quiz'
  final DateTime createdAt;

  AdModel({
    required this.id,
    required this.type,
    required this.url,
    this.localPath,
    required this.duration,
    this.qrLink,
    this.text,
    this.quiz,
    required this.createdAt,
  });

  factory AdModel.fromJson(Map<String, dynamic> json) {
    // Check if this is a quiz ad
    if (json['type'] == 'quiz' || json['quiz'] != null) {
      print('📦 [AD_MODEL] Processing quiz ad: ${json['id']}');
      
      QuizModel? quiz;
      if (json['quiz'] != null) {
        quiz = QuizModel.fromJson(json['quiz']);
      }
      
      return AdModel(
        id: json['id']?.toString() ?? 'unknown',
        type: 'quiz',
        url: '', // No URL needed for quiz ads
        localPath: null,
        duration: 30, // Quiz ads show for 30 seconds
        qrLink: json['qr_link'],
        text: json['text'],
        quiz: quiz,
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );
    }
    
    // Handle regular video/image ads
    final fileName = json['file_name'] ?? '';
    final localPath = json['local_path'] as String?;
    
    print('📦 [AD_MODEL] Processing file: $fileName');
    print('📦 [AD_MODEL] Local path: $localPath');
    
    // Check file extension from either filename or local path
    String fileToCheck = fileName;
    if (fileToCheck.isEmpty && localPath != null) {
      fileToCheck = localPath.split('/').last; // Get filename from local path
    }
    
    final isVideo = fileToCheck.toLowerCase().endsWith('.mp4') || 
                   fileToCheck.toLowerCase().endsWith('.mov') ||
                   fileToCheck.toLowerCase().endsWith('.avi') ||
                   fileToCheck.toLowerCase().endsWith('.mkv');
    
    print('📦 [AD_MODEL] Checking file: $fileToCheck');
    print('📦 [AD_MODEL] File type detected: ${isVideo ? 'VIDEO' : 'IMAGE'}');
    
    // Construct full URL for media files with correct paths
    String fullUrl = '';
    if (fileName.isNotEmpty) {
      if (isVideo) {
        fullUrl = 'http://connect.admein.az/storage/ads/videos/$fileName';
      } else {
        fullUrl = 'http://connect.admein.az/storage/ads/images/$fileName';
      }
    }
    
    print('📦 [AD_MODEL] Generated URL: $fullUrl');
    
    return AdModel(
      id: json['id']?.toString() ?? 'unknown',
      type: isVideo ? 'video' : 'image',
      url: fullUrl,
      localPath: localPath,
      duration: isVideo ? 30 : 15, // Videos: 30s default, Images: 15s
      qrLink: json['qr_link'], // QR link from API
      text: json['text'], // Text for QR screen from API
      quiz: null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    // Extract file_name from URL for database storage
    String? fileName;
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
      }
    }
    
    return {
      'id': id,
      'type': type,
      'url': url,
      'file_name': fileName, // Store file_name for proper reconstruction
      'local_path': localPath,
      'duration': duration,
      'qr_link': qrLink,
      'text': text,
      'quiz': quiz?.toJson(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper method to create a copy with updated local path
  AdModel copyWith({String? localPath}) {
    return AdModel(
      id: id,
      type: type,
      url: url,
      localPath: localPath ?? this.localPath,
      duration: duration,
      qrLink: qrLink,
      text: text,
      quiz: quiz,
      createdAt: createdAt,
    );
  }
}
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/app_state_service.dart';

class QrDisplayScreen extends StatelessWidget {
  const QrDisplayScreen({super.key});

  // Helper method to extract SVG content from data URI
  String? _extractSvgFromDataUri(String? dataUri) {
    if (dataUri == null) {
      return null;
    }
    
    // Handle both proper data URIs and malformed ones from backend
    if (!dataUri.startsWith('data:image/svg+xml')) {
      return null;
    }
    
    try {
      // Extract the content after the comma
      final commaIndex = dataUri.indexOf(',');
      if (commaIndex == -1) {
        return null;
      }
      
      final contentPart = dataUri.substring(commaIndex + 1);
      
      // The backend is sending raw XML with escaped characters instead of proper base64
      // First, unescape the JSON-escaped characters
      String unescapedContent = contentPart
          .replaceAll(r'\/', '/')
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\\', '\\');
      
      // Check if it's already XML content (backend sends raw XML even with base64 header)
      if (unescapedContent.trim().startsWith('<?xml') || unescapedContent.trim().startsWith('<svg')) {
        print('📱 [QR] Found raw XML content in malformed data URI, using directly');
        return unescapedContent;
      }
      
      // If the header says base64, try decoding first
      if (dataUri.contains('base64,')) {
        try {
          final decodedBytes = base64Decode(unescapedContent);
          final decodedString = utf8.decode(decodedBytes);
          print('📱 [QR] Successfully decoded base64 SVG content');
          return decodedString;
        } catch (base64Error) {
          print('📱 [QR] Base64 decode failed, checking for raw SVG content');
          // Backend is lying about base64 - check if it's actually raw SVG
          if (unescapedContent.contains('<svg') && unescapedContent.contains('</svg>')) {
            print('📱 [QR] Using raw SVG despite base64 header');
            return unescapedContent;
          }
        }
      } else {
        // URL encoded or plain SVG
        String decodedContent = Uri.decodeComponent(unescapedContent);
        if (decodedContent.trim().startsWith('<?xml') || decodedContent.trim().startsWith('<svg')) {
          print('📱 [QR] Found URL-encoded SVG content');
          return decodedContent;
        }
      }
      
    } catch (e) {
      print('❌ [QR] Error processing SVG data URI: $e');
    }
    
    return null;
  }

  // Helper method to modify SVG colors for better visibility
  String _modifySvgColors(String svgContent) {
    // Replace white colors with background color #2a2e6a
    String modifiedSvg = svgContent
        .replaceAll('fill="white"', 'fill="#2a2e6a"')
        .replaceAll('fill="#ffffff"', 'fill="#2a2e6a"')
        .replaceAll('fill="#FFFFFF"', 'fill="#2a2e6a"')
        .replaceAll('fill="rgb(255,255,255)"', 'fill="#2a2e6a"')
        .replaceAll('fill="rgb(255, 255, 255)"', 'fill="#2a2e6a"');
    
    // Replace black colors with white
    modifiedSvg = modifiedSvg
        .replaceAll('fill="black"', 'fill="white"')
        .replaceAll('fill="#000000"', 'fill="white"')
        .replaceAll('fill="#000"', 'fill="white"')
        .replaceAll('fill="rgb(0,0,0)"', 'fill="white"')
        .replaceAll('fill="rgb(0, 0, 0)"', 'fill="white"');
    
    print('📱 [QR] Modified SVG colors for better visibility');
    return modifiedSvg;
  }

  // Helper method to extract regular image bytes from data URI
  Uint8List? _extractImageBytesFromDataUri(String? dataUri) {
    if (dataUri == null) {
      return null;
    }
    
    try {
      // Handle PNG, JPEG, etc.
      if (dataUri.startsWith('data:image/') && !dataUri.contains('svg')) {
        // Extract the base64 part after the comma
        final base64Part = dataUri.split(',').last;
        // Decode from base64
        return base64Decode(base64Part);
      }
      
      return null;
    } catch (e) {
      print('❌ [QR] Error decoding image data URI: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateService>(
      builder: (context, appState, child) {
        // Debug logging for QR code and logo URLs
        if (appState.qrCodeUrl != null) {
          print('📱 [QR] QR code URL available (data URI format)');
        } else {
          print('📱 [QR] No QR code URL available');
        }
        
        if (appState.qrLogoUrl != null && appState.qrLogoUrl!.isNotEmpty) {
          print('📱 [QR] QR logo URL available: ${appState.qrLogoUrl}');
        } else {
          print('📱 [QR] No QR logo URL available');
        }
        return Scaffold(
          backgroundColor: const Color(0xFF2a2e6a), // App theme background
          body: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 600),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: const Color(0xFF2a2e6a), // App theme background
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                  Text(
                    appState.qrText?.isNotEmpty == true 
                        ? appState.qrText!
                        : 'QR Kodu Skan edin',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // QR Code and Logo side by side
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // QR Code
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Builder(
                          builder: (context) {
                            // Try SVG first
                            final svgContent = _extractSvgFromDataUri(appState.qrCodeUrl);
                            if (svgContent != null) {
                              // Modify SVG colors before displaying
                              final modifiedSvgContent = _modifySvgColors(svgContent);
                              print('📱 [QR] Displaying QR code as SVG with modified colors');
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 300,
                                  height: 300,
                                  color: Colors.transparent,
                                  child: SvgPicture.string(
                                    modifiedSvgContent,
                                    width: 300,
                                    height: 300,
                                    fit: BoxFit.contain,
                                    placeholderBuilder: (context) => const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            
                            // Try regular image formats
                            final imageBytes = _extractImageBytesFromDataUri(appState.qrCodeUrl);
                            if (imageBytes != null) {
                              print('📱 [QR] Displaying QR code as regular image');
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  imageBytes,
                                  width: 300,
                                  height: 300,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('❌ [QR] Error displaying QR code image: $error');
                                    return const SizedBox(
                                      width: 300,
                                      height: 300,
                                      child: Center(
                                        child: Icon(
                                          Icons.qr_code,
                                          size: 150,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                            
                            // Fallback if no valid format is found
                            print('❌ [QR] No valid QR code format found in: ${appState.qrCodeUrl?.substring(0, 50)}...');
                            return const SizedBox(
                              width: 300,
                              height: 300,
                              child: Center(
                                child: Icon(
                                  Icons.qr_code,
                                  size: 150,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // Logo section next to QR code
                      if (appState.qrLogoUrl != null && appState.qrLogoUrl!.isNotEmpty) ...[
                        const SizedBox(width: 40),
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 300,
                              height: 300,
                              child: Image.network(
                                appState.qrLogoUrl!,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  print('❌ [LOGO] Failed to load QR logo: $error');
                                  print('❌ [LOGO] URL: ${appState.qrLogoUrl}');
                                  return const Center(
                                    child: Icon(
                                      Icons.business,
                                      size: 150,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  Text(
                    'Bu məhsul haqqında daha çox öyrənin',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.grey[400],
                      fontSize: 18,
                    ),
                  ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
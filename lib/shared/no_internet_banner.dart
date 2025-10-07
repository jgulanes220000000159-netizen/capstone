import 'package:flutter/material.dart';
import 'connectivity_service.dart';

class NoInternetBanner extends StatelessWidget {
  final Widget child;
  final String? message;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double? topOffset;
  final bool forceShow; // For testing purposes

  const NoInternetBanner({
    Key? key,
    required this.child,
    this.message,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.topOffset,
    this.forceShow = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connectivityService,
      builder: (context, _) {
        try {
          // Check if service is initialized before accessing it
          if (!connectivityService.isInitialized) {
            return child; // Return child without banner if service not ready
          }

          print(
            '🌐 Banner build: isConnected = ${connectivityService.isConnected}',
          );
          final shouldShow = !connectivityService.isConnected || forceShow;
          return Stack(
            alignment: Alignment.topLeft,
            children: [
              child,
              if (shouldShow)
                Positioned(
                  top: topOffset ?? 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Material(
                      elevation: 8,
                      color: Colors.transparent,
                      child: SafeArea(
                        bottom: false,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: backgroundColor ?? Colors.red[600],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                icon ?? Icons.wifi_off,
                                color: textColor ?? Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  message ?? 'No Internet Connection',
                                  style: TextStyle(
                                    color: textColor ?? Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.signal_wifi_off,
                                color: textColor ?? Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        } catch (e) {
          print('🌐 Error in banner build: $e');
          return child; // Return child without banner if there's an error
        }
      },
    );
  }
}

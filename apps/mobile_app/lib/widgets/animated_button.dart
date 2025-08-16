import 'package:flutter/material.dart';
import '../core/theme.dart';

class AnimatedButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool enabled;
  final bool small;
  final Color? customColor;

  const AnimatedButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.enabled = true,
    this.small = false,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Determine button color based on text and enabled state
    Color buttonColor;
    if (!enabled) {
      buttonColor = theme.brightness == Brightness.light 
          ? Colors.grey[400]! 
          : Colors.grey[700]!;
    } else if (customColor != null) {
      buttonColor = customColor!;
    } else if (text == 'Pause') {
      buttonColor = AppColors.accent;
    } else if (text == 'Stop') {
      buttonColor = AppColors.error;
    } else if (text == 'Resume') {
      buttonColor = AppColors.success;
    } else {
      buttonColor = theme.primaryColor;
    }
    
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: small ? 16 : 32, 
          vertical: small ? 8 : 16
        ),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: enabled ? [
            BoxShadow(
              color: buttonColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold, 
            fontSize: small ? 14 : 18
          ),
        ),
      ),
    );
  }
}

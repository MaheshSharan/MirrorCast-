import 'package:flutter/material.dart';

enum ButtonVariant { primary, secondary }

class PrimaryButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final ButtonVariant variant;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.variant = ButtonVariant.primary,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = variant == ButtonVariant.primary;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return SizedBox(
      width: double.infinity,
      height: isSmallScreen ? 48 : 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? theme.primaryColor : Colors.transparent,
          foregroundColor: isPrimary ? Colors.white : theme.primaryColor,
          elevation: isPrimary ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.primaryColor,
              width: isPrimary ? 0 : 2,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 24,
            vertical: isSmallScreen ? 12 : 16,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: isSmallScreen ? 20 : 24,
                height: isSmallScreen ? 20 : 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isPrimary ? Colors.white : theme.primaryColor,
                  ),
                ),
              )
            else ...[
              Icon(icon, size: isSmallScreen ? 20 : 24),
              SizedBox(width: isSmallScreen ? 8 : 12),
            ],
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
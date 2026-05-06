import 'package:flutter/material.dart';

/// A reusable card banner for surfacing API fetch errors with an optional
/// retry action. Place it inline in a list or column wherever a data fetch
/// can fail (recommendations, coverage, substitution hints, etc.).
///
/// When [onRetry] is null the refresh icon button is hidden.
class ApiStatusBanner extends StatelessWidget {
  const ApiStatusBanner({
    super.key,
    required this.message,
    this.subtitle,
    this.onRetry,
  });

  /// The primary error message displayed as the tile title.
  final String message;

  /// Optional secondary text shown below the title.
  final String? subtitle;

  /// Called when the user taps the refresh icon. If null the button is hidden.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(message),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: onRetry != null
            ? IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Retry',
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../theme/app_theme.dart';

/// Full-screen login entry point.
///
/// Delegates all auth logic to [AuthBloc].  Tapping "Sign in" fires
/// [AuthSignInRequested] which opens the Cognito hosted UI via PKCE.
/// The router redirects automatically once the bloc emits [AuthStatus.authenticated].
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          // Navigation is handled by the router redirect — nothing to do here.
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppPadding.xl,
              vertical: AppPadding.x2l,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                // ── Logo / branding ────────────────────────────────────────
                Icon(
                  Icons.kitchen_rounded,
                  size: 72,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: AppPadding.md),
                Text(
                  'PantryPilot',
                  style: textTheme.headlineLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppPadding.sm),
                Text(
                  'Your smart kitchen companion',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                // ── Sign-in button ─────────────────────────────────────────
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppPadding.md),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text(
                              state.errorMessage!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppPadding.md),
                        ],
                        FilledButton.icon(
                          onPressed: () => context.read<AuthBloc>().add(
                            const AuthSignInRequested(),
                          ),
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Sign in'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppPadding.md),
                Text(
                  'By signing in you agree to our Terms of Service.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppPadding.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';

/// Configuration constants for Cognito OAuth2 / PKCE flow.
///
/// Replace [userPoolId] and [region] with values from Terraform outputs
/// once `terraform apply` has been run.
class CognitoConfig {
  // Override via `--dart-define=COGNITO_CLIENT_ID=...` at build time.
  static const clientId = String.fromEnvironment(
    'COGNITO_CLIENT_ID',
    defaultValue: 'REPLACE_ME',
  );
  static const userPoolId = String.fromEnvironment(
    'COGNITO_USER_POOL_ID',
    defaultValue: 'REPLACE_ME',
  );
  static const region = String.fromEnvironment(
    'COGNITO_REGION',
    defaultValue: 'us-east-1',
  );

  static const hostedUiDomainPrefix = String.fromEnvironment(
    'COGNITO_HOSTED_UI_DOMAIN_PREFIX',
    defaultValue: 'pantry-pilot-auth',
  );

  static String get hostedUiDomain =>
      '$hostedUiDomainPrefix.auth.$region.amazoncognito.com';

  /// Must match one of the `callback_urls` in Terraform.
  static const redirectUri = 'pantrypilot://auth';
  static const logoutRedirectUri = 'pantrypilot://auth/logout';

  static const scopes = <String>['openid', 'email', 'profile'];

  static bool get hasRequiredValues {
    debugPrint(
      'CognitoConfig: clientId=$clientId, userPoolId=$userPoolId, '
      'region=$region, hostedUiDomain=$hostedUiDomain',
    );
    return clientId != 'REPLACE_ME' &&
        userPoolId != 'REPLACE_ME' &&
        region.isNotEmpty;
  }

  static String get amplifyConfig {
    final config = <String, dynamic>{
      'auth': {
        'plugins': {
          'awsCognitoAuthPlugin': {
            'UserAgent': 'aws-amplify-flutter/2.x',
            'Version': '1.0',
            'CognitoUserPool': {
              'Default': {
                'PoolId': userPoolId,
                'AppClientId': clientId,
                'Region': region,
              },
            },
            'Auth': {
              'Default': {
                'OAuth': {
                  'WebDomain': hostedUiDomain,
                  'AppClientId': clientId,
                  'SignInRedirectURI': redirectUri,
                  'SignOutRedirectURI': logoutRedirectUri,
                  'Scopes': scopes,
                  'ResponseType': 'code',
                },
              },
            },
          },
        },
      },
    };
    return jsonEncode(config);
  }
}

/// Amplify-backed auth repository.
///
/// This repository initializes Amplify Auth (Cognito), performs hosted-UI
/// sign in, and exposes the current access token for API requests.
class AuthRepository {
  AuthRepository();

  bool _initialized = false;
  String? _lastError;

  String? get lastError => _lastError;

  Future<void> initialize() async {
    if (_initialized || Amplify.isConfigured) {
      _initialized = true;
      return;
    }

    if (!CognitoConfig.hasRequiredValues) {
      // Keep local development functional with backend X-User-Id fallback.
      _lastError =
          'Cognito configuration is missing. Set COGNITO_CLIENT_ID, '
          'COGNITO_USER_POOL_ID, and COGNITO_REGION.';
      return;
    }

    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.configure(CognitoConfig.amplifyConfig);
      _initialized = true;
      _lastError = null;
    } on AmplifyException catch (error) {
      _lastError = error.message;
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns true when a valid (or refreshable) session exists.
  Future<bool> isAuthenticated() async {
    if (!Amplify.isConfigured) {
      return false;
    }
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } on AuthException {
      return false;
    }
  }

  Future<String?> getAccessToken() async {
    if (!Amplify.isConfigured) {
      return null;
    }
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      if (!session.isSignedIn) {
        return null;
      }
      return session.userPoolTokensResult.value.accessToken.raw;
    } on AuthException {
      return null;
    }
  }

  /// Opens the Cognito hosted UI for sign-in / sign-up.
  /// Returns true on success.
  Future<bool> signIn() async {
    if (!Amplify.isConfigured) {
      await initialize();
    }
    if (!Amplify.isConfigured) {
      _lastError =
          _lastError ?? 'Amplify Auth is not configured for this build.';
      return false;
    }
    try {
      final result = await Amplify.Auth.signInWithWebUI();
      _lastError = null;
      return result.isSignedIn;
    } on AuthException catch (error) {
      _lastError = error.message;
      return false;
    }
  }

  /// Clears stored tokens and ends the Cognito session.
  Future<void> signOut() async {
    if (!Amplify.isConfigured) {
      return;
    }
    try {
      await Amplify.Auth.signOut(
        options: const SignOutOptions(globalSignOut: true),
      );
      _lastError = null;
    } on AuthException {
      // Best-effort sign out.
    }
  }
}

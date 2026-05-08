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

  static const scopes = <String>[
    'openid',
    'email',
    'profile',
    'aws.cognito.signin.user.admin',
  ];

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

  /// Loads common user profile attributes from Cognito.
  Future<AuthUserProfile?> fetchUserProfile() async {
    if (!Amplify.isConfigured) {
      return null;
    }

    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final email = _readAttribute(attributes, CognitoUserAttributeKey.email);
      final firstName = _readAttribute(
        attributes,
        CognitoUserAttributeKey.givenName,
      );
      final lastName = _readAttribute(
        attributes,
        CognitoUserAttributeKey.familyName,
      );

      return AuthUserProfile(
        firstName: firstName,
        lastName: lastName,
        email: email,
      );
    } on AuthException catch (error) {
      _lastError = error.message;
      return null;
    }
  }

  /// Updates editable Cognito profile attributes.
  Future<bool> updateUserProfile({String? firstName, String? lastName}) async {
    if (!Amplify.isConfigured) {
      await initialize();
    }
    if (!Amplify.isConfigured) {
      _lastError =
          _lastError ?? 'Amplify Auth is not configured for this build.';
      return false;
    }

    final updates = <AuthUserAttributeKey, String>{
      if (firstName != null && firstName.trim().isNotEmpty)
        CognitoUserAttributeKey.givenName: firstName.trim(),
      if (lastName != null && lastName.trim().isNotEmpty)
        CognitoUserAttributeKey.familyName: lastName.trim(),
    };

    try {
      for (final entry in updates.entries) {
        await Amplify.Auth.updateUserAttribute(
          userAttributeKey: entry.key,
          value: entry.value,
        );
      }
      _lastError = null;
      return true;
    } on AuthException catch (error) {
      _lastError = error.message;
      return false;
    }
  }

  String? _readAttribute(
    List<AuthUserAttribute> attributes,
    AuthUserAttributeKey key,
  ) {
    for (final attribute in attributes) {
      if (attribute.userAttributeKey.key == key.key) {
        return attribute.value;
      }
    }
    return null;
  }
}

class AuthUserProfile {
  const AuthUserProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  final String? firstName;
  final String? lastName;
  final String? email;

  String get fullName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) {
      return combined;
    }
    if ((email?.trim().isNotEmpty ?? false)) {
      return email!.trim();
    }
    return 'User';
  }

  String get initials {
    final source = fullName;
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'U';
    }
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

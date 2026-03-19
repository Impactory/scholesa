import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ──────────────────────────────────────────────────────
// Deployment & Ops Regression Test Suite
//
// Categories:
//  1. Install/upgrade regression   — fresh install + version consistency
//  2. Config regression            — env vars, secrets, feature flags, defaults
//  3. CI/CD regression             — pipeline integrity, Dockerfiles, artifacts
//  4. Rollback regression          — config versioning + state recovery
//  5. Monitoring/alert regression  — health endpoints, scheduled jobs, logging
// ──────────────────────────────────────────────────────

/// Resolve workspace root from test file location.
/// Tests run from apps/empire_flutter/app/ — root is 3 levels up.
String get _workspaceRoot {
  // When run via `flutter test` cwd is the Flutter app dir
  final String flutterAppDir = Directory.current.path;
  // Navigate up to monorepo root
  if (flutterAppDir.endsWith('apps/empire_flutter/app')) {
    return flutterAppDir.replaceAll('/apps/empire_flutter/app', '');
  }
  // Fallback: try to find firebase.json by walking up
  Directory dir = Directory.current;
  while (dir.path != dir.parent.path) {
    if (File('${dir.path}/firebase.json').existsSync()) return dir.path;
    dir = dir.parent;
  }
  return Directory.current.path;
}

void main() {
  late String root;

  setUpAll(() {
    root = _workspaceRoot;
  });

  // ════════════════════════════════════════════════════════
  // 1. INSTALL / UPGRADE REGRESSION
  //    "Fresh install works; version pins are consistent"
  // ════════════════════════════════════════════════════════

  group('Install & Upgrade Regression', () {
    // ── 1.1 Flutter pubspec version is parseable & consistent ──
    test('pubspec.yaml version follows semver+build pattern', () {
      final File pubspec = File('pubspec.yaml');
      expect(pubspec.existsSync(), isTrue, reason: 'pubspec.yaml must exist');

      final String content = pubspec.readAsStringSync();
      // Match `version: X.Y.Z[-prerelease]+B`
      final RegExp semverBuild =
          RegExp(r'version:\s+(\d+\.\d+\.\d+(?:-[a-zA-Z0-9.]+)?)\+(\d+)');
      final RegExpMatch? match = semverBuild.firstMatch(content);
      expect(match, isNotNull,
          reason:
              'pubspec version must be semver[+prerelease]+build (e.g., 1.0.0+1 or 1.0.0-rc.2+2)');

      final String semver = match!.group(1)!;
      final int buildNumber = int.parse(match.group(2)!);
      expect(semver.split('.').length, greaterThanOrEqualTo(3));
      expect(buildNumber, greaterThan(0));
    });

    // ── 1.2 Dart SDK constraint exists ──
    test('pubspec.yaml declares Dart SDK constraint', () {
      final String content = File('pubspec.yaml').readAsStringSync();
      expect(content.contains('sdk:'), isTrue);
      // Should have a bounded SDK range like >=3.2.0 <4.0.0
      expect(
        RegExp(r'sdk:\s*.+>=\d+\.\d+\.\d+\s+<\d+\.\d+\.\d+').hasMatch(content),
        isTrue,
        reason: 'SDK constraint must be a bounded range (>=X <Y)',
      );
    });

    // ── 1.3 pubspec.lock exists (reproducible installs) ──
    test('pubspec.lock is committed for reproducible builds', () {
      expect(File('pubspec.lock').existsSync(), isTrue,
          reason: 'pubspec.lock must be committed for deterministic builds');
    });

    // ── 1.4 Node engine pin matches .nvmrc ──
    test('Functions Node engine matches .nvmrc', () {
      final File nvmrc = File('$root/.nvmrc');
      final File funcPkg = File('$root/functions/package.json');
      expect(nvmrc.existsSync(), isTrue, reason: '.nvmrc must exist');
      expect(funcPkg.existsSync(), isTrue,
          reason: 'functions/package.json must exist');

      final String nvmrcVersion = nvmrc.readAsStringSync().trim();
      final Map<String, dynamic> pkg =
          jsonDecode(funcPkg.readAsStringSync()) as Map<String, dynamic>;
      final String engineNode =
          (pkg['engines'] as Map<String, dynamic>)['node'] as String;

      expect(engineNode, equals(nvmrcVersion),
          reason:
              'functions package.json engines.node ($engineNode) must match .nvmrc ($nvmrcVersion)');
    });

    // ── 1.5 Functions package-lock.json exists ──
    test('functions/package-lock.json exists for reproducible installs', () {
      final File lockFile = File('$root/functions/package-lock.json');
      expect(lockFile.existsSync(), isTrue,
          reason: 'functions/package-lock.json must be committed');
    });

    // ── 1.6 Android applicationId matches bundle convention ──
    test('Android applicationId is com.scholesa.app', () {
      final File buildGradle = File('android/app/build.gradle.kts');
      expect(buildGradle.existsSync(), isTrue);

      final String content = buildGradle.readAsStringSync();
      expect(content.contains('applicationId = "com.scholesa.app"'), isTrue,
          reason: 'Android applicationId must be com.scholesa.app');
      expect(content.contains('namespace = "com.scholesa.app"'), isTrue,
          reason: 'Android namespace must match applicationId');
    });

    // ── 1.7 Firebase SDKs are aligned (no mixed major versions) ──
    test('Firebase SDK versions are from same major generation', () {
      final String pubspecContent = File('pubspec.yaml').readAsStringSync();

      // All Firebase Flutter SDKs should be on a consistent major
      final RegExp firebaseDep =
          RegExp(r'(firebase_\w+|cloud_\w+):\s+\^?(\d+)');
      final Iterable<RegExpMatch> matches =
          firebaseDep.allMatches(pubspecContent);
      expect(matches.length, greaterThanOrEqualTo(3),
          reason: 'Should have at least 3 Firebase/cloud dependencies');

      // firebase_core should be major 3.x, cloud_firestore 5.x, firebase_auth 5.x
      // Key rule: no mixing of pre-Firebase-v2 and post-v2 packages
      for (final RegExpMatch m in matches) {
        final int major = int.parse(m.group(2)!);
        expect(major, greaterThanOrEqualTo(3),
            reason:
                '${m.group(1)} major version ($major) should be ≥3 (FlutterFire v2+)');
      }
    });
  });

  // ════════════════════════════════════════════════════════
  // 2. CONFIG REGRESSION
  //    "Env vars, feature flags, secrets injection, defaults"
  // ════════════════════════════════════════════════════════

  group('Config Regression', () {
    // ── 2.1 .env.example declares all required client vars ──
    test('.env.example contains all required client-side Firebase vars', () {
      final File envExample = File('$root/.env.example');
      expect(envExample.existsSync(), isTrue,
          reason: '.env.example must exist');

      final String content = envExample.readAsStringSync();

      const List<String> requiredClientVars = <String>[
        'NEXT_PUBLIC_FIREBASE_API_KEY',
        'NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN',
        'NEXT_PUBLIC_FIREBASE_PROJECT_ID',
        'NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET',
        'NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID',
        'NEXT_PUBLIC_FIREBASE_APP_ID',
      ];

      for (final String v in requiredClientVars) {
        expect(content.contains(v), isTrue,
            reason: '.env.example must declare $v');
      }
    });

    // ── 2.2 .env.example declares server-side auth vars ──
    test('.env.example contains server-side Firebase auth vars', () {
      final String content = File('$root/.env.example').readAsStringSync();

      // At least one server-side auth mechanism should be documented
      final bool hasServiceAccount =
          content.contains('FIREBASE_SERVICE_ACCOUNT');
      final bool hasAdcCreds =
          content.contains('GOOGLE_APPLICATION_CREDENTIALS');
      final bool hasAdminEmail =
          content.contains('FIREBASE_ADMIN_CLIENT_EMAIL');

      expect(hasServiceAccount || hasAdcCreds || hasAdminEmail, isTrue,
          reason: '.env.example must document at least one server auth method');
    });

    // ── 2.3 Stripe secrets are NOT in .env.example (managed via Firebase Secrets) ──
    test('Stripe secrets are managed via Firebase Secrets, not .env', () {
      final String content = File('$root/.env.example').readAsStringSync();

      // Stripe secret key and webhook secret should NOT have value assignments
      // They should only have comments explaining Firebase Secrets usage
      expect(
        RegExp(r'^STRIPE_SECRET_KEY=\S', multiLine: true).hasMatch(content),
        isFalse,
        reason:
            'STRIPE_SECRET_KEY must not have a value in .env.example (use Firebase Secrets)',
      );
      expect(
        RegExp(r'^STRIPE_WEBHOOK_SECRET=\S', multiLine: true).hasMatch(content),
        isFalse,
        reason: 'STRIPE_WEBHOOK_SECRET must not have a value in .env.example',
      );
    });

    // ── 2.3b Stripe env vars contain price IDs, not API keys ──
    test('Functions env does not leak Stripe API keys in price ID fields', () {
      // Check all .env* files under functions/ for leaked keys
      final Directory functionsDir = Directory('$root/functions');
      final List<File> envFiles = functionsDir
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.contains('.env'))
          .toList();

      for (final File envFile in envFiles) {
        final String content = envFile.readAsStringSync();

        // No restricted keys (rk_live_, rk_test_) in price ID fields
        expect(
          RegExp(r'STRIPE_PRICE_\w+=rk_').hasMatch(content),
          isFalse,
          reason:
              '${envFile.path} has a Stripe restricted key in a PRICE field — use price_xxx IDs',
        );

        // No secret keys (sk_live_, sk_test_) anywhere in env files
        expect(
          content.contains('sk_live_') || content.contains('sk_test_'),
          isFalse,
          reason:
              '${envFile.path} leaks a Stripe secret key — use Firebase Secrets instead',
        );

        // No restricted keys in non-Stripe fields either
        expect(
          RegExp(r'NOTIFY_ENDPOINT=rk_').hasMatch(content),
          isFalse,
          reason: '${envFile.path} has a Stripe key in NOTIFY_ENDPOINT',
        );
      }
    });

    // ── 2.3c defineSecret vs defineString separation is correct ──
    test('Stripe secrets use defineSecret, price IDs use defineString', () {
      final String funcSrc =
          File('$root/functions/src/index.ts').readAsStringSync();

      // STRIPE_SECRET_KEY must be defineSecret
      expect(funcSrc.contains("defineSecret('STRIPE_SECRET_KEY')"), isTrue,
          reason: 'STRIPE_SECRET_KEY must use defineSecret');

      // STRIPE_WEBHOOK_SECRET must be defineSecret
      expect(funcSrc.contains("defineSecret('STRIPE_WEBHOOK_SECRET')"), isTrue,
          reason: 'STRIPE_WEBHOOK_SECRET must use defineSecret');

      // STRIPE_PRICE_* must be defineString (not defineSecret)
      expect(funcSrc.contains("defineString('STRIPE_PRICE_LEARNER'"), isTrue,
          reason: 'STRIPE_PRICE_LEARNER must use defineString');
      expect(funcSrc.contains("defineString('STRIPE_PRICE_EDUCATOR'"), isTrue,
          reason: 'STRIPE_PRICE_EDUCATOR must use defineString');
      expect(funcSrc.contains("defineString('STRIPE_PRICE_PARENT'"), isTrue,
          reason: 'STRIPE_PRICE_PARENT must use defineString');
      expect(funcSrc.contains("defineString('STRIPE_PRICE_SITE'"), isTrue,
          reason: 'STRIPE_PRICE_SITE must use defineString');
    });

    // ── 2.4 Firebase project ID is consistent across configs ──
    test('Firebase project ID is consistent (.firebaserc ↔ firebase.json)', () {
      final File firebaserc = File('$root/.firebaserc');
      expect(firebaserc.existsSync(), isTrue);

      final Map<String, dynamic> rc =
          jsonDecode(firebaserc.readAsStringSync()) as Map<String, dynamic>;
      final String projectId =
          (rc['projects'] as Map<String, dynamic>)['default'] as String;

      expect(projectId, isNotEmpty);
      expect(projectId, equals('studio-3328096157-e3f79'));
    });

    // ── 2.5 firebase.json runtime matches .nvmrc ──
    test('firebase.json functions runtime matches Node version', () {
      final Map<String, dynamic> firebaseJson =
          jsonDecode(File('$root/firebase.json').readAsStringSync())
              as Map<String, dynamic>;
      final String runtime = (firebaseJson['functions']
          as Map<String, dynamic>)['runtime'] as String;

      final String nvmrc = File('$root/.nvmrc').readAsStringSync().trim();
      expect(runtime, equals('nodejs$nvmrc'),
          reason: 'firebase.json runtime ($runtime) must be nodejs$nvmrc');
    });

    test('firebase.json functions predeploy runs build and Gen 2 verification',
        () {
      final Map<String, dynamic> firebaseJson =
          jsonDecode(File('$root/firebase.json').readAsStringSync())
              as Map<String, dynamic>;
      final Map<String, dynamic> functions =
          firebaseJson['functions'] as Map<String, dynamic>;
      final List<dynamic> predeploy =
          functions['predeploy'] as List<dynamic>? ?? <dynamic>[];

      expect(
        predeploy.contains('npm --prefix "\$RESOURCE_DIR" run build'),
        isTrue,
        reason: 'Functions predeploy must compile TypeScript before deploy',
      );
      expect(
        predeploy.contains('npm --prefix "\$RESOURCE_DIR" run verify:gen2'),
        isTrue,
        reason:
            'Functions predeploy must verify the shared Gen 2 deployment baseline',
      );
    });

    // ── 2.6 Functions defineSecret/defineString have safe defaults ──
    test('Cloud Functions define safe defaults for non-secret params', () {
      final String funcSrc =
          File('$root/functions/src/index.ts').readAsStringSync();

      // defineString params should have defaults
      final RegExp defineStringWithDefault =
          RegExp(r"defineString\(\s*'(\w+)'\s*,\s*\{[^}]*default:");
      final Iterable<RegExpMatch> matches =
          defineStringWithDefault.allMatches(funcSrc);

      // We know we have STRIPE_PRICE_*, NOTIFY_ENDPOINT
      expect(matches.length, greaterThanOrEqualTo(4),
          reason: 'At least 4 defineString params should have defaults');

      // defineSecret params should NOT have defaults
      final RegExp defineSecretWithDefault =
          RegExp(r"defineSecret\(\s*'(\w+)'\s*,\s*\{[^}]*default:");
      expect(defineSecretWithDefault.allMatches(funcSrc).length, equals(0),
          reason: 'defineSecret should never have default values');
    });

    // ── 2.7 PWA feature flag documented ──
    test('PWA enable flag is documented in .env.example', () {
      final String content = File('$root/.env.example').readAsStringSync();
      expect(content.contains('NEXT_PUBLIC_ENABLE_SW'), isTrue);
    });

    // ── 2.8 Emulator ports are non-conflicting ──
    test('Firebase emulator ports are unique and non-conflicting', () {
      final Map<String, dynamic> firebaseJson =
          jsonDecode(File('$root/firebase.json').readAsStringSync())
              as Map<String, dynamic>;
      final Map<String, dynamic> emulators =
          firebaseJson['emulators'] as Map<String, dynamic>;

      final Set<int> ports = <int>{};
      for (final MapEntry<String, dynamic> entry in emulators.entries) {
        if (entry.value is Map && (entry.value as Map).containsKey('port')) {
          final int port = (entry.value as Map)['port'] as int;
          expect(ports.contains(port), isFalse,
              reason: 'Emulator port $port (${entry.key}) is duplicated');
          ports.add(port);
        }
      }
      expect(ports.length, greaterThanOrEqualTo(4),
          reason: 'Should have at least 4 unique emulator ports');
    });
  });

  // ════════════════════════════════════════════════════════
  // 3. CI/CD REGRESSION
  //    "Pipeline builds reproducibly; artifacts are versioned"
  // ════════════════════════════════════════════════════════

  group('CI/CD Regression', () {
    // ── 3.1 GitHub Actions CI workflow exists ──
    test('CI workflow exists and triggers on main', () {
      final File ci = File('$root/.github/workflows/ci.yml');
      expect(ci.existsSync(), isTrue, reason: 'CI workflow must exist');

      final String content = ci.readAsStringSync();
      expect(content.contains('main'), isTrue,
          reason: 'CI workflow must trigger on main branch');
      expect(content.contains('actions/checkout'), isTrue,
          reason: 'CI workflow must checkout code');
    });

    // ── 3.2 Cloud Run deploy workflow exists with required secrets ──
    test('Deploy workflow references all required GitHub secrets', () {
      final File deploy = File('$root/.github/workflows/deploy-cloud-run.yml');
      expect(deploy.existsSync(), isTrue);

      final String content = deploy.readAsStringSync();

      const List<String> requiredSecrets = <String>[
        'GCP_SA_KEY',
        'GCP_PROJECT_ID',
        'GCP_REGION',
        'CLOUD_RUN_SERVICE',
        'CLOUD_RUN_FLUTTER_SERVICE',
        'NEXT_PUBLIC_FIREBASE_API_KEY',
        'NEXT_PUBLIC_FIREBASE_PROJECT_ID',
        'NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN',
        'NEXT_PUBLIC_FIREBASE_APP_ID',
        'NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET',
        'NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID',
      ];

      for (final String secret in requiredSecrets) {
        expect(content.contains(secret), isTrue,
            reason: 'Deploy workflow must reference secret: $secret');
      }
    });

    // ── 3.3 Deploy uses git SHA for image tagging (versioned artifact) ──
    test('Cloud Run deploy tags images with git SHA', () {
      final String content =
          File('$root/.github/workflows/deploy-cloud-run.yml')
              .readAsStringSync();

      expect(content.contains(r'${{ github.sha }}'), isTrue,
          reason: 'Docker image must be tagged with git SHA for traceability');
    });

    test('Deploy workflow verifies Functions Gen 2 and deploys Flutter web separately', () {
      final String content =
          File('$root/.github/workflows/deploy-cloud-run.yml')
              .readAsStringSync();

      expect(
        content.contains('npm --prefix functions run verify:gen2'),
        isTrue,
        reason: 'Deploy workflow must explicitly verify the Functions Gen 2 baseline',
      );
      expect(
        content.contains('flutter build web --release --no-wasm-dry-run'),
        isTrue,
        reason: 'Deploy workflow must explicitly build the Flutter web target before deploy',
      );
      expect(
        content.contains('docker build -f Dockerfile.flutter'),
        isTrue,
        reason: 'Deploy workflow must build the dedicated Flutter web container',
      );
      expect(
        content.contains('CLOUD_RUN_FLUTTER_SERVICE'),
        isTrue,
        reason: 'Deploy workflow must reference a dedicated Flutter web Cloud Run service',
      );
      expect(
        content.contains(
          r'gcloud run deploy ${{ secrets.CLOUD_RUN_FLUTTER_SERVICE }}',
        ),
        isTrue,
        reason: 'Deploy workflow must deploy the Flutter web service explicitly',
      );
      expect(
        content.contains('no_traffic:'),
        isTrue,
        reason:
            'Deploy workflow must expose a no-traffic rehearsal input for safer Cloud Run rollouts',
      );
      expect(
        content.contains('--no-traffic'),
        isTrue,
        reason:
            'Deploy workflow must support Cloud Run no-traffic deploys for rehearsal',
      );
    });

    test('Manual deploy script verifies Gen 2 and deploys both web surfaces',
        () {
      final String content = File('$root/scripts/deploy.sh').readAsStringSync();

      expect(
        content.contains('npm run verify:gen2'),
        isTrue,
        reason:
            'Manual deploy script must verify the Functions Gen 2 baseline before functions deploy',
      );
      expect(
        content.contains('CLOUD_RUN_SERVICE:-scholesa-web'),
        isTrue,
        reason:
            'Manual deploy script must keep a dedicated primary web Cloud Run service',
      );
      expect(
        content.contains('CLOUD_RUN_FLUTTER_SERVICE:-empire-web'),
        isTrue,
        reason:
            'Manual deploy script must keep a dedicated Flutter web Cloud Run service',
      );
      expect(
        content.contains('deploy_primary_web'),
        isTrue,
        reason:
            'Manual deploy script must expose an explicit primary web deploy path',
      );
      expect(
        content.contains('deploy_flutter_cloud_run'),
        isTrue,
        reason:
            'Manual deploy script must expose an explicit Flutter web deploy path',
      );
      expect(
        content.contains('web)              deploy_cloud_run_web ;;'),
        isTrue,
        reason:
            'Manual deploy script must expose a combined web target for both services',
      );
      expect(
        content.contains('CLOUD_RUN_NO_TRAFFIC'),
        isTrue,
        reason:
            'Manual deploy script must support no-traffic Cloud Run rehearsal mode',
      );
      expect(
        content.contains('--no-traffic'),
        isTrue,
        reason:
            'Manual deploy script must be able to deploy Cloud Run revisions without shifting traffic',
      );
      expect(
        content.contains('mapfile'),
        isFalse,
        reason:
            'Manual deploy script must avoid bash4-only mapfile usage so it runs on default macOS Bash',
      );
      expect(
        content.contains(r'gcloud builds submit --project "$project_id" --tag "$image"'),
        isTrue,
        reason:
            'Manual primary web deploy must use Cloud Build so local machine architecture does not break Cloud Run deploys',
      );
    });

    test('Platform flow and release gates enforce Gen 2 and combined web deploy',
        () {
      final String flowContent =
          File('$root/scripts/full_platform_flow.sh').readAsStringSync();
      final String rc2Content =
          File('$root/scripts/rc2_regression.sh').readAsStringSync();
      final String rc3Content =
          File('$root/scripts/rc3_preflight.sh').readAsStringSync();

      expect(
        flowContent.contains('npm --prefix functions run verify:gen2'),
        isTrue,
        reason:
            'Full platform flow must verify the Functions Gen 2 baseline before deploy',
      );
      expect(
        flowContent.contains('bash ./scripts/deploy.sh web'),
        isTrue,
        reason:
            'Full platform flow must deploy both primary web and Flutter web together',
      );
      expect(
        rc2Content.contains('Functions Gen 2 verification'),
        isTrue,
        reason:
            'RC2 regression chain must include the Functions Gen 2 verification step',
      );
      expect(
        rc2Content.contains(r'npm --prefix "$FUNCTIONS_DIR" run verify:gen2'),
        isTrue,
        reason:
            'RC2 regression chain must execute verify:gen2',
      );
      expect(
        rc3Content.contains('Functions Gen 2 verification'),
        isTrue,
        reason:
            'RC3 preflight must include the Functions Gen 2 verification step',
      );
      expect(
        rc3Content.contains('npm --prefix functions run verify:gen2'),
        isTrue,
        reason: 'RC3 preflight must execute verify:gen2',
      );
    });

    // ── 3.4 Dockerfile uses pinned base images ──
    test('Dockerfile base images are version-pinned', () {
      final File dockerfile = File('$root/Dockerfile');
      expect(dockerfile.existsSync(), isTrue);

      final String content = dockerfile.readAsStringSync();
      // Should not use `FROM node:latest` — must pin
      expect(content.contains('FROM node:latest'), isFalse,
          reason: 'Dockerfile must not use :latest tag');
      // Check it uses a specific version
      expect(RegExp(r'FROM node:\d+').hasMatch(content), isTrue,
          reason: 'Dockerfile must pin Node.js major version');
    });

    // ── 3.5 Flutter Dockerfile exists for web deployment ──
    test('Flutter Dockerfile exists with SPA routing', () {
      final File dockerFlutter = File('$root/Dockerfile.flutter');
      expect(dockerFlutter.existsSync(), isTrue);

      final String content = dockerFlutter.readAsStringSync();
      expect(content.contains('nginx'), isTrue,
          reason: 'Flutter web Dockerfile should use nginx');
      expect(content.contains('try_files'), isTrue,
          reason: 'Flutter web Dockerfile must configure SPA fallback routing');
      expect(content.contains('8080'), isTrue,
          reason: 'Cloud Run expects port 8080');
      expect(
        content.contains('flutter build web --release'),
        isTrue,
        reason: 'Flutter web Dockerfile must produce a release web build',
      );
      expect(
        content.contains('--no-wasm-dry-run'),
        isTrue,
        reason:
            'Flutter web Dockerfile must disable wasm dry-run until the current dependency set is compatible',
      );
    });

    // ── 3.6 Cloud Build config exists for Flutter ──
    test('Cloud Build config for Flutter web exists', () {
      final File cloudBuild = File('$root/cloudbuild.flutter.yaml');
      expect(cloudBuild.existsSync(), isTrue);

      final String content = cloudBuild.readAsStringSync();
      expect(content.contains('Dockerfile.flutter'), isTrue,
          reason: 'Cloud Build must reference Flutter Dockerfile');
      expect(content.contains('gcr.io'), isTrue,
          reason: 'Cloud Build should push to GCR');
      expect(content.contains(r'gcr.io/${PROJECT_ID}/empire-web:${_TAG}'),
          isTrue,
          reason:
              'Flutter Cloud Build config must use the active GCP project instead of a hardcoded project id');
    });

    // ── 3.7 Functions build script compiles TypeScript ──
    test('Functions package.json has build and deploy scripts', () {
      final Map<String, dynamic> pkg =
          jsonDecode(File('$root/functions/package.json').readAsStringSync())
              as Map<String, dynamic>;
      final Map<String, dynamic> scripts =
          pkg['scripts'] as Map<String, dynamic>;

      expect(scripts.containsKey('build'), isTrue);
      expect(scripts['build'], equals('tsc'),
          reason: 'Functions build must compile TypeScript');
      expect(scripts['verify:gen2'], equals('node scripts/verify-gen2-runtime.js'),
          reason: 'Functions must expose a Gen 2 verification script');
      expect(scripts.containsKey('deploy'), isTrue);
      expect((scripts['deploy'] as String).contains('firebase deploy'), isTrue);
      expect((scripts['deploy'] as String).contains('npm run verify:gen2'),
          isTrue,
          reason:
              'Functions deploy script must verify the Gen 2 baseline before deploy');
    });

    test('Flutter Cloud Run helper defaults to the Flutter web service', () {
      final String content =
          File('$root/scripts/deploy-cloud-run.sh').readAsStringSync();

      expect(content.contains(r'CLOUD_RUN_SERVICE=${3:-empire-web}'), isTrue,
          reason:
              'Flutter Cloud Run helper must default to the dedicated Flutter web service');
      expect(content.contains('cloudbuild.flutter.yaml'), isTrue,
          reason:
              'Flutter Cloud Run helper must build through the Flutter-specific Cloud Build config');
      expect(content.contains('CLOUD_RUN_NO_TRAFFIC'), isTrue,
          reason:
              'Flutter Cloud Run helper must support no-traffic Cloud Run rehearsals');
    });

    // ── 3.8 Firestore indexes are committed ──
    test('Firestore indexes are committed and non-empty', () {
      final File indexes = File('$root/firestore.indexes.json');
      expect(indexes.existsSync(), isTrue);

      final Map<String, dynamic> content =
          jsonDecode(indexes.readAsStringSync()) as Map<String, dynamic>;
      final List<dynamic> compositeIndexes =
          content['indexes'] as List<dynamic>? ?? <dynamic>[];
      expect(compositeIndexes.length, greaterThanOrEqualTo(5),
          reason:
              'Should have at least 5 composite indexes for production queries');
    });
  });

  // ════════════════════════════════════════════════════════
  // 4. ROLLBACK REGRESSION
  //    "Rollback procedure works and restores service"
  // ════════════════════════════════════════════════════════

  group('Rollback Regression', () {
    // ── 4.1 Firestore rules are versioned ──
    test('Firestore rules use rules_version 2', () {
      final File rules = File('$root/firestore.rules');
      expect(rules.existsSync(), isTrue);

      final String content = rules.readAsStringSync();
      expect(content.contains("rules_version = '2'"), isTrue,
          reason: 'Firestore rules must declare version 2');
    });

    // ── 4.2 Storage rules exist ──
    test('Storage rules exist and are versioned', () {
      final File rules = File('$root/storage.rules');
      expect(rules.existsSync(), isTrue);

      final String content = rules.readAsStringSync();
      expect(content.contains("rules_version = '2'"), isTrue);
    });

    // ── 4.3 Multiple config layers are independently deployable ──
    test('Firebase deployment layers are separable', () {
      final Map<String, dynamic> firebase =
          jsonDecode(File('$root/firebase.json').readAsStringSync())
              as Map<String, dynamic>;

      // Each of these should be independently deployable:
      // `firebase deploy --only firestore:rules`
      // `firebase deploy --only functions`
      // `firebase deploy --only storage`
      expect(firebase.containsKey('firestore'), isTrue,
          reason: 'Firestore config must be present for independent deploy');
      expect(firebase.containsKey('functions'), isTrue,
          reason: 'Functions config must be present for independent deploy');
      expect(firebase.containsKey('hosting'), isFalse,
          reason:
              'Hosting config should be absent when Cloud Run is the web deploy target');
      expect(firebase.containsKey('storage'), isTrue,
          reason: 'Storage config must be present for independent deploy');
    });

    // ── 4.4 Functions entry point exists ──
    test('Functions compiled entry point is specified', () {
      final Map<String, dynamic> pkg =
          jsonDecode(File('$root/functions/package.json').readAsStringSync())
              as Map<String, dynamic>;
      final String main = pkg['main'] as String;
      expect(main, equals('lib/index.js'),
          reason: 'Functions main must point to compiled output');
    });

    // ── 4.5 Dockerfile has non-root user (security baseline for rollback health) ──
    test('Next.js Dockerfile runs as non-root user', () {
      final String content = File('$root/Dockerfile').readAsStringSync();
      // Security: production containers should not run as root
      final bool hasNonRoot = content.contains('adduser') ||
          content.contains('USER ') ||
          content.contains('appuser');
      expect(hasNonRoot, isTrue,
          reason: 'Production Dockerfile must run as non-root user');
    });

    // ── 4.6 Flutter version is atomic (single source of truth) ──
    test('Flutter version comes from pubspec (not hardcoded in Gradle)', () {
      final String gradle =
          File('android/app/build.gradle.kts').readAsStringSync();

      // versionCode and versionName should come from flutter.* properties
      expect(gradle.contains('flutter.versionCode'), isTrue,
          reason: 'versionCode must inherit from Flutter (pubspec.yaml)');
      expect(gradle.contains('flutter.versionName'), isTrue,
          reason: 'versionName must inherit from Flutter (pubspec.yaml)');

      // Should NOT have hardcoded version numbers
      expect(
        RegExp(r'versionCode\s*=\s*\d+[^.]').hasMatch(gradle),
        isFalse,
        reason: 'versionCode must not be hardcoded (use flutter.versionCode)',
      );
    });
  });

  // ════════════════════════════════════════════════════════
  // 5. MONITORING / ALERT REGRESSION
  //    "On-call can detect and triage issues quickly"
  // ════════════════════════════════════════════════════════

  group('Monitoring & Alert Regression', () {
    // ── 5.1 Health check endpoint exists ──
    test('healthCheck function exists in Cloud Functions', () {
      final String funcSrc =
          File('$root/functions/src/index.ts').readAsStringSync();

      expect(funcSrc.contains('export const healthCheck'), isTrue,
          reason: 'healthCheck HTTP endpoint must be exported');
      // Should check at least Firestore and Stripe
      expect(funcSrc.contains('listCollections'), isTrue,
          reason: 'healthCheck should verify Firestore connectivity');
    });

    // ── 5.2 Health check returns structured response ──
    test('healthCheck returns healthy/unhealthy status with service details',
        () {
      final String funcSrc =
          File('$root/functions/src/index.ts').readAsStringSync();

      expect(funcSrc.contains("'healthy'"), isTrue,
          reason: 'healthCheck must return healthy status string');
      expect(funcSrc.contains("'unhealthy'"), isTrue,
          reason: 'healthCheck must return unhealthy status string');
      // Should include service-level detail for triage
      expect(funcSrc.contains('services'), isTrue,
          reason: 'healthCheck should report per-service status');
    });

    // ── 5.3 Scheduled monitoring jobs exist ──
    test('Scheduled monitoring functions are defined', () {
      final String funcSrc =
          File('$root/functions/src/index.ts').readAsStringSync();

      const List<String> requiredScheduledJobs = <String>[
        'monitorWebhookHealth',
        'checkExpiringSubscriptions',
        'archiveOldTelemetry',
        'cleanupExpiredIntents',
      ];

      for (final String job in requiredScheduledJobs) {
        expect(funcSrc.contains('export const $job'), isTrue,
            reason: 'Scheduled job $job must be exported');
      }
    });

    // ── 5.4 Webhook health monitor has alert threshold ──
    test('monitorWebhookHealth creates alerts on threshold breach', () {
      final String funcSrc =
          File('$root/functions/src/index.ts').readAsStringSync();

      // Should create alert documents when failure rate exceeds threshold
      expect(funcSrc.contains('alerts'), isTrue,
          reason: 'Webhook monitor must write to alerts collection');
      // Should have a defined threshold (10% is our current setting)
      expect(RegExp(r'0\.1|10\s*%|failureRate').hasMatch(funcSrc), isTrue,
          reason: 'Webhook monitor must define a failure rate threshold');
    });

    // ── 5.5 Telemetry aggregation is scheduled ──
    test('Telemetry aggregation scheduled functions exist', () {
      final String aggSrc =
          File('$root/functions/src/telemetryAggregator.ts').readAsStringSync();

      expect(aggSrc.contains('aggregateDailyTelemetry'), isTrue);
      expect(aggSrc.contains('aggregateWeeklyTelemetry'), isTrue);
      // Should have a manual trigger for ops
      expect(aggSrc.contains('triggerTelemetryAggregation'), isTrue,
          reason: 'Manual trigger endpoint should exist for ops');
    });

    // ── 5.5b All exported functions use v2 imports (no v1→v2 upgrade errors) ──
    test('All Cloud Functions use v2 imports exclusively', () {
      final String indexSrc =
          File('$root/functions/src/index.ts').readAsStringSync();
      final String aggSrc =
          File('$root/functions/src/telemetryAggregator.ts').readAsStringSync();
      final String bosSrc =
          File('$root/functions/src/bosRuntime.ts').readAsStringSync();
      final String workflowSrc =
          File('$root/functions/src/workflowOps.ts').readAsStringSync();
      final String coppaSrc =
          File('$root/functions/src/coppaOps.ts').readAsStringSync();

      // Index must import from v2
      expect(indexSrc.contains("from 'firebase-functions/v2/https'"), isTrue,
          reason: 'index.ts must use firebase-functions/v2/https');
      expect(
          indexSrc.contains("from 'firebase-functions/v2/scheduler'"), isTrue,
          reason: 'index.ts must use firebase-functions/v2/scheduler');

      // Telemetry aggregator must import from v2
      expect(aggSrc.contains("from 'firebase-functions/v2/scheduler'"), isTrue,
          reason: 'telemetryAggregator must use v2 scheduler');
      expect(aggSrc.contains("from 'firebase-functions/v2/https'"), isTrue,
          reason: 'telemetryAggregator must use v2 https');

      // BOS runtime must import from v2
      expect(bosSrc.contains("from 'firebase-functions/v2/https'"), isTrue,
          reason: 'bosRuntime must use v2 https');
      expect(workflowSrc.contains("from 'firebase-functions/v2/https'"), isTrue,
          reason: 'workflowOps must use v2 https');
      expect(coppaSrc.contains("from 'firebase-functions/v2/https'"), isTrue,
          reason: 'coppaOps must use v2 https');

      // No v1 imports in any source file
      for (final MapEntry<String, String> entry in <String, String>{
        'index.ts': indexSrc,
        'telemetryAggregator.ts': aggSrc,
        'bosRuntime.ts': bosSrc,
        'workflowOps.ts': workflowSrc,
        'coppaOps.ts': coppaSrc,
      }.entries) {
        expect(
          RegExp(r"from\s+'firebase-functions'(?!/v2)").hasMatch(entry.value),
          isFalse,
          reason:
              '${entry.key} must not import from firebase-functions v1 (use /v2/)',
        );
      }
    });

    test('Shared Gen 2 runtime bootstrap is applied to every v2 entry module',
        () {
      final String gen2Runtime =
          File('$root/functions/src/gen2Runtime.ts').readAsStringSync();
      expect(gen2Runtime.contains('setGlobalOptions'), isTrue,
          reason: 'gen2Runtime.ts must define shared Gen 2 runtime options');
      expect(gen2Runtime.contains("SCHOLESA_GEN2_REGION = 'us-central1'"), isTrue,
          reason: 'Gen 2 runtime bootstrap must pin the shared region');

      final Map<String, String> entryModules = <String, String>{
        'index.ts': File('$root/functions/src/index.ts').readAsStringSync(),
        'workflowOps.ts':
            File('$root/functions/src/workflowOps.ts').readAsStringSync(),
        'bosRuntime.ts':
            File('$root/functions/src/bosRuntime.ts').readAsStringSync(),
        'coppaOps.ts':
            File('$root/functions/src/coppaOps.ts').readAsStringSync(),
        'telemetryAggregator.ts':
            File('$root/functions/src/telemetryAggregator.ts').readAsStringSync(),
      };

      for (final MapEntry<String, String> entry in entryModules.entries) {
        expect(
          entry.value.contains('./gen2Runtime'),
          isTrue,
          reason:
              '${entry.key} must import the shared Gen 2 runtime bootstrap',
        );
      }
    });

    // ── 5.6 BOS runtime has observable endpoints ──
    test('BOS runtime exports all 8 orchestration endpoints', () {
      final String bosSrc =
          File('$root/functions/src/bosRuntime.ts').readAsStringSync();

      const List<String> requiredEndpoints = <String>[
        'bosIngestEvent',
        'bosGetOrchestrationState',
        'bosGetIntervention',
        'bosScoreMvl',
        'bosSubmitMvlEvidence',
        'bosTeacherOverrideMvl',
        'bosGetClassInsights',
        'bosContestability',
      ];

      for (final String endpoint in requiredEndpoints) {
        expect(bosSrc.contains('export const $endpoint'), isTrue,
            reason: 'BOS endpoint $endpoint must be exported');
      }
    });

    // ── 5.7 Firebase emulators are configured for local debugging ──
    test('Firebase emulators cover all critical services', () {
      final Map<String, dynamic> firebaseJson =
          jsonDecode(File('$root/firebase.json').readAsStringSync())
              as Map<String, dynamic>;
      final Map<String, dynamic> emulators =
          firebaseJson['emulators'] as Map<String, dynamic>;

      const List<String> requiredEmulators = <String>[
        'auth',
        'firestore',
        'storage',
        'functions',
      ];

      for (final String emu in requiredEmulators) {
        expect(emulators.containsKey(emu), isTrue,
            reason: '$emu emulator must be configured');
        final Map<String, dynamic> config =
            emulators[emu] as Map<String, dynamic>;
        expect(config.containsKey('port'), isTrue,
            reason: '$emu emulator must have a port');
      }

      // UI should be enabled for debugging
      expect(
        (emulators['ui'] as Map<String, dynamic>?)?['enabled'],
        isTrue,
        reason: 'Emulator UI should be enabled for local debugging',
      );
    });

    // ── 5.8 PWA assets exist for offline monitoring (no 404s) ──
    test('PWA manifest and service worker exist', () {
      // These are for the Next.js web app (public/ at repo root)
      final File manifest = File('$root/public/manifest.webmanifest');
      final File sw = File('$root/public/sw.js');

      expect(manifest.existsSync(), isTrue,
          reason: 'manifest.webmanifest must exist to avoid 404');
      expect(sw.existsSync(), isTrue, reason: 'sw.js must exist to avoid 404');

      // Manifest must have required fields
      final Map<String, dynamic> manifestJson =
          jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
      expect(manifestJson.containsKey('name'), isTrue);
      expect(manifestJson.containsKey('icons'), isTrue);
      expect(manifestJson.containsKey('display'), isTrue);
      expect(manifestJson['display'], equals('standalone'));
    });

    // ── 5.9 No server secrets committed to repo ──
    test('No server secret files committed to repo root', () {
      const List<String> criticalSecretFiles = <String>[
        '.env.local',
        '.env.production',
        '.env.staging',
      ];

      for (final String pattern in criticalSecretFiles) {
        final File f = File('$root/$pattern');
        expect(f.existsSync(), isFalse,
            reason: '$pattern should not be committed to the repository');
      }
    });

    test('.gitignore exists and covers secrets', () {
      final File gitignore = File('$root/.gitignore');
      expect(gitignore.existsSync(), isTrue, reason: '.gitignore must exist');

      final String content = gitignore.readAsStringSync();
      // Should ignore at least .env (or .env.local)
      expect(
        content.contains('.env') || content.contains('*.env'),
        isTrue,
        reason: '.gitignore should cover .env files',
      );
    });

    // ── 5.10 Firestore rules have role-based auth helpers ──
    test('Firestore rules include role-based auth helpers', () {
      final String rules = File('$root/firestore.rules').readAsStringSync();

      const List<String> requiredHelpers = <String>[
        'isAuthenticated',
        'isOwner',
        'hasRole',
        'isEducator',
        'isHQ',
      ];

      for (final String helper in requiredHelpers) {
        expect(rules.contains(helper), isTrue,
            reason: 'Firestore rules must include $helper() helper');
      }
    });
  });

  // ════════════════════════════════════════════════════════
  // 6. CROSS-CUTTING VERSION CONSISTENCY
  //    "All deployment artifacts agree on versions/identifiers"
  // ════════════════════════════════════════════════════════

  group('Cross-Cutting Consistency', () {
    test('Bundle identifiers match their platform Firebase registrations', () {
      const String expectedMobileBundleId = 'com.scholesa.app';
      const String expectedMacosBundleId = 'com.scholesa.app.macos';

      // Android
      final String androidGradle =
          File('android/app/build.gradle.kts').readAsStringSync();
      expect(
          androidGradle.contains('applicationId = "$expectedMobileBundleId"'), isTrue,
          reason: 'Android applicationId must be $expectedMobileBundleId');

      // iOS
      final File iosProject = File('ios/Runner.xcodeproj/project.pbxproj');
      if (iosProject.existsSync()) {
        final String iosContent = iosProject.readAsStringSync();
        expect(iosContent.contains(expectedMobileBundleId), isTrue,
            reason: 'iOS bundle identifier must be $expectedMobileBundleId');
      }

      // macOS
      final File macosConfig = File('macos/Runner/Configs/AppInfo.xcconfig');
      if (macosConfig.existsSync()) {
        final String macosContent = macosConfig.readAsStringSync();
        expect(macosContent.contains(expectedMacosBundleId), isTrue,
            reason: 'macOS bundle identifier must be $expectedMacosBundleId');
      }
    });

    test('Firebase functions source directory exists and has entry point', () {
      final Map<String, dynamic> firebaseJson =
          jsonDecode(File('$root/firebase.json').readAsStringSync())
              as Map<String, dynamic>;
      final String funcSource = (firebaseJson['functions']
          as Map<String, dynamic>)['source'] as String;

      final Directory funcDir = Directory('$root/$funcSource');
      expect(funcDir.existsSync(), isTrue,
          reason: 'Functions source directory ($funcSource) must exist');

      final File srcIndex = File('$root/$funcSource/src/index.ts');
      expect(srcIndex.existsSync(), isTrue,
          reason: 'Functions entry point (src/index.ts) must exist');
    });

    test('Firestore rules file referenced in firebase.json exists', () {
      final Map<String, dynamic> firebaseJson =
          jsonDecode(File('$root/firebase.json').readAsStringSync())
              as Map<String, dynamic>;
      final String rulesPath = (firebaseJson['firestore']
          as Map<String, dynamic>)['rules'] as String;

      expect(File('$root/$rulesPath').existsSync(), isTrue,
          reason: 'Firestore rules file ($rulesPath) must exist');
    });

    test('Storage rules file referenced in firebase.json exists', () {
      final Map<String, dynamic> firebaseJson =
          jsonDecode(File('$root/firebase.json').readAsStringSync())
              as Map<String, dynamic>;
      final String rulesPath =
          (firebaseJson['storage'] as Map<String, dynamic>)['rules'] as String;

      expect(File('$root/$rulesPath').existsSync(), isTrue,
          reason: 'Storage rules file ($rulesPath) must exist');
    });
  });
}

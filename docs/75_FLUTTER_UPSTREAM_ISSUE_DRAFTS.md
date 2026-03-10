# Flutter Upstream Issue Drafts

Last reviewed: 2026-03-09
Scope: `apps/empire_flutter/app`

## Purpose

These drafts are prefilled issue bodies for upstream maintainers whose Android Gradle scripts still emit deprecation warnings under Gradle 8.14 warning mode. They are based on Scholesa's current verified Flutter app baseline, not on modified plugin source.

## Shared Environment Block

Use this block in every issue unless a maintainer requests a smaller repro:

```text
Environment:
- Flutter 3.38.9
- Dart stable toolchain shipped with Flutter 3.38.9
- Java 21
- Gradle 8.14
- Android build command:
  ./gradlew app:compileDebugJavaWithJavac --warning-mode all --console=plain

Observed behavior:
- The consuming Flutter app still builds successfully.
- The plugin emits Gradle deprecation warnings that are scheduled to become errors in Gradle 10.

Expected behavior:
- Plugin Android Gradle scripts build cleanly under Gradle 8.14 warning mode.
- Plugin avoids APIs and DSL syntax scheduled for removal in Gradle 10.
```

## Exact Warning Excerpts From Scholesa

These excerpts were captured from Scholesa's current app using:

```text
cd apps/empire_flutter/app/android
./gradlew app:compileDebugJavaWithJavac --warning-mode all --console=plain
```

Representative excerpt for Groovy assignment deprecations:

```text
Properties should be assigned using the 'propName = value' syntax. Setting a property via the Gradle-generated 'propName value' or 'propName(value)' syntax in Groovy DSL has been deprecated. This is scheduled to be removed in Gradle 10.0.
```

Representative excerpt for execution-time task access:

```text
Invocation of Task.project at execution time has been deprecated. This will fail with an error in Gradle 10.0. This API is incompatible with the configuration cache.
```

## Draft 1: `speech_to_text`

Suggested title:

```text
Android Gradle deprecation cleanup for Gradle 8.14 / Gradle 10 compatibility
```

Suggested body:

```text
Environment:
- Flutter 3.38.9
- Java 21
- Gradle 8.14

Build command used:
./gradlew app:compileDebugJavaWithJavac --warning-mode all --console=plain

Observed behavior:
- `speech_to_text` builds successfully in a consuming Flutter app.
- The plugin emits Gradle deprecation warnings during configuration/execution.
- In Scholesa's current runtime audit, this package is the highest-value warning source because it also surfaces a `Task.project` execution-time deprecation in addition to Groovy DSL warning noise.

Representative excerpt:
- `> Configure project :speech_to_text`
- `Properties should be assigned using the 'propName = value' syntax...`
- `Invocation of Task.project at execution time has been deprecated. This will fail with an error in Gradle 10.0.`

Expected behavior:
- Android Gradle scripts and task wiring should avoid APIs/syntax scheduled for removal in Gradle 10.

Notes:
- This report comes from a consuming app without modifying plugin source.
- The app runtime is healthy; the request is only for Gradle modernization.
```

## Draft 2: Shared FlutterFire Android Scripts

Suggested title:

```text
Shared Android Gradle script cleanup across FlutterFire packages for Gradle 8.14 / Gradle 10 compatibility
```

Suggested target packages:

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `cloud_functions`
- `firebase_storage`

Suggested body:

```text
Environment:
- Flutter 3.38.9
- Java 21
- Gradle 8.14

Build command used:
./gradlew app:compileDebugJavaWithJavac --warning-mode all --console=plain

Observed behavior:
- The consuming Flutter app builds successfully.
- Multiple FlutterFire Android package scripts still emit Gradle deprecation warnings.
- The warning shape appears shared across package templates, including deprecated Groovy assignment patterns and older Android Gradle DSL access patterns.

Representative excerpt:
- `> Configure project :cloud_firestore`
- `> Configure project :cloud_functions`
- `> Configure project :firebase_auth`
- `> Configure project :firebase_core`
- `> Configure project :firebase_storage`
- `Properties should be assigned using the 'propName = value' syntax...`

Packages observed in the warning surface:
- firebase_core 4.5.0
- firebase_auth 6.2.0
- cloud_firestore 6.1.3
- cloud_functions 6.0.7
- firebase_storage 13.1.0

Expected behavior:
- FlutterFire Android package scripts should build cleanly under Gradle 8.14 warning mode and avoid patterns scheduled to fail under Gradle 10.

Notes:
- This was reproduced from a consuming app without patching FlutterFire locally.
- Scholesa already aligns these packages in a lockstep tested set; the remaining issue is build-script modernization, not runtime compatibility.
```

## Draft 3: `audioplayers`

Suggested title:

```text
Android plugin Gradle DSL cleanup for Gradle 8.14 / Gradle 10 compatibility
```

Suggested body:

```text
Environment:
- Flutter 3.38.9
- Java 21
- Gradle 8.14

Observed behavior:
- The app builds and audio runtime still works in the consuming app.
- `audioplayers_android` emits deprecation warnings from Groovy space-assignment syntax in its Android build script.

Representative excerpt:
- `> Configure project :audioplayers_android`
- `Properties should be assigned using the 'propName = value' syntax... Use assignment ('group = <value>') instead.`
- `Properties should be assigned using the 'propName = value' syntax... Use assignment ('version = <value>') instead.`
- `Properties should be assigned using the 'propName = value' syntax... Use assignment ('compileSdk = <value>') instead.`
- `Properties should be assigned using the 'propName = value' syntax... Use assignment ('namespace = <value>') instead.`

Resolved package versions in the consuming app:
- audioplayers 6.6.0
- audioplayers_android 5.2.1

Expected behavior:
- Android build scripts should use Gradle syntax compatible with current warning mode and future Gradle 10 behavior.
```

## Draft 4: `flutter_tts`

Suggested title:

```text
Android Gradle script warning cleanup for Gradle 8.14 / Gradle 10 compatibility
```

Suggested body:

```text
Environment:
- Flutter 3.38.9
- Java 21
- Gradle 8.14

Observed behavior:
- `flutter_tts` remains runtime-functional in the consuming app.
- The Android plugin Gradle file emits deprecated Groovy DSL assignment warnings under `--warning-mode all`.

Representative excerpt:
- `> Configure project :flutter_tts`
- `Properties should be assigned using the 'propName = value' syntax... Use assignment ('group = <value>') instead.`
- `Properties should be assigned using the 'propName = value' syntax... Use assignment ('version = <value>') instead.`
- `Properties should be assigned using the 'propName = value' syntax... Use assignment ('compileSdk = <value>') instead.`
- `Properties should be assigned using the 'propName = value' syntax... Use assignment ('namespace = <value>') instead.`

Resolved package version in consuming app:
- flutter_tts 4.2.5

Expected behavior:
- Android build scripts should no longer emit deprecation warnings under Gradle 8.14 warning mode.
```

## Draft 5: `file_picker` And `connectivity_plus`

Suggested title:

```text
Android Gradle warning cleanup for Gradle 8.14 / Gradle 10 compatibility
```

Suggested body:

```text
Environment:
- Flutter 3.38.9
- Java 21
- Gradle 8.14

Observed behavior:
- The plugin remains functional in a consuming app.
- The Android build script still emits deprecated Groovy assignment syntax warnings under `--warning-mode all`.

Resolved package version in consuming app:
- file_picker 10.3.10
- connectivity_plus 7.0.0

Representative excerpt:
- `> Configure project :file_picker`
- `Properties should be assigned using the 'propName = value' syntax... Use assignment ('compileSdk = <value>') instead.`
- `Properties should be assigned using the 'propName = value' syntax... Use assignment ('minSdk = <value>') instead.`
- `Properties should be assigned using the 'propName = value' syntax... Use assignment ('namespace = <value>') instead.`
- `> Configure project :connectivity_plus`
- `Properties should be assigned using the 'propName = value' syntax... Use assignment ('minSdk = <value>') instead.`

Expected behavior:
- Plugin Android scripts should build cleanly with current Gradle warning mode and avoid syntax scheduled for removal in Gradle 10.
```

## Filing Order

Recommended order for upstream reporting:

1. `speech_to_text`
2. Shared FlutterFire issue
3. `audioplayers`
4. `flutter_tts`
5. `file_picker`
6. `connectivity_plus`

This order prioritizes the packages with the highest value for Scholesa's voice runtime and the broadest warning footprint.
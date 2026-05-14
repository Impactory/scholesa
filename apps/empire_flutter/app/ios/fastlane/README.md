fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios verify_api_key

```sh
[bundle exec] fastlane ios verify_api_key
```

Validate local or CI App Store Connect API key configuration

### ios prepare_ios_signing

```sh
[bundle exec] fastlane ios prepare_ios_signing
```

Prepare iOS App Store signing from App Store Connect API key

### ios prepare_macos_developer_id

```sh
[bundle exec] fastlane ios prepare_macos_developer_id
```

Prepare macOS Developer ID signing from App Store Connect API key

### ios upload_testflight

```sh
[bundle exec] fastlane ios upload_testflight
```

Build a signed iOS release IPA and upload it to TestFlight

### ios verify_testflight_build

```sh
[bundle exec] fastlane ios verify_testflight_build
```

Verify the expected Flutter build number is visible in TestFlight

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

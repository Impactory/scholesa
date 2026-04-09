// Web Speech API bridge — conditional import.
//
// On web/WASM: uses `dart:js_interop` + `package:web` for native browser
// `SpeechRecognition` and `speechSynthesis`.
// On native: stub that returns `isSupported = false`.
export 'web_speech_stub.dart'
    if (dart.library.js_interop) 'web_speech_interop.dart';

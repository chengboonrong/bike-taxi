// Demo values: they only work with the Firebase emulators (project "demo-bike-taxi").
// For a real project, take them from Firebase console → Project settings → General → Your apps:
// the web app's config snippet (apiKey, appId, messagingSenderId, projectId, authDomain), and each
// Android app's google-services.json (current_key = apiKey, mobilesdk_app_id = appId,
// project_number = messagingSenderId). Also set the project id in .firebaserc.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show appFlavor;

const _projectId = 'demo-bike-taxi';
const _senderId = '000000000000';

FirebaseOptions get firebaseOptions => kIsWeb
    ? const FirebaseOptions(
        apiKey: 'AIzaSyDemo-emulator-only-web-key-000000',
        appId: '1:000000000000:web:0000000000000003',
        messagingSenderId: _senderId,
        projectId: _projectId,
        authDomain: '$_projectId.firebaseapp.com',
      )
    : FirebaseOptions(
        apiKey: 'AIzaSyDemo-emulator-only-android-key-00',
        appId: appFlavor == 'driver'
            ? '1:000000000000:android:0000000000000002'
            : '1:000000000000:android:0000000000000001',
        messagingSenderId: _senderId,
        projectId: _projectId,
      );

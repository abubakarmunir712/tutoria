import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api_config.dart';

void main() {
  // Which server this build talks to: the first thing to check when sign-in "can't connect".
  debugPrint('Tutoria API server: $apiBaseUrl');
  runApp(const TutoriaApp());
}

import 'package:flutter/material.dart';
import 'package:tutor_camera/tutor_camera.dart';

/// GoAbacUs Camera Lab: the desk camera's "what the camera sees" screen on
/// its own, for testing with printed sheets before the desk box exists.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    title: 'GoAbacUs Камера',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF8C510A), useMaterial3: true),
    home: const DeskCameraScreen(title: 'GoAbacUs Камера'),
  ));
}

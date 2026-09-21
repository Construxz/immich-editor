import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Editor for Immich',
      home: Scaffold(body: Center(child: Text('Editor for Immich'))),
    );
  }
}

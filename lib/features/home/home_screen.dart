import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Distance')),
      body: Center(
        child: Text(
          'Encuentra un plan cerca de ti',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

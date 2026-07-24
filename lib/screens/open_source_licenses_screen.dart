import 'package:flutter/material.dart';

class OpenSourceLicensesScreen extends StatelessWidget {
  const OpenSourceLicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Source Licenses'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Text(
            'PDF Master Tools is built using Flutter and carefully selected open-source libraries.\n\n'
            'We sincerely appreciate the Flutter team and the global open-source community for their valuable work and contributions.\n\n'
            'All third-party libraries and components used in this application remain the property of their respective authors and are used in accordance with their applicable open-source licenses.\n\n'
            'Thank you to everyone who helps make open-source software possible.',
            style: TextStyle(
              fontSize: 16,
              height: 1.7,
            ),
          ),
        ),
      ),
    );
  }
}

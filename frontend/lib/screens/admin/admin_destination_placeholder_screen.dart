import 'package:flutter/material.dart';

/// A simple placeholder screen used for admin features that are not yet implemented.
/// It displays a centered [message] with an [AppBar] title.
class AdminDestinationPlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;

  const AdminDestinationPlaceholderScreen({Key? key, required this.title, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Standard app scaffold offering a subtle background gradient to give depth to glassmorphic cards.
class AppScaffold extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final EdgeInsetsGeometry padding;
  final Widget? bottomNavigationBar;

  const AppScaffold({
    super.key,
    this.title,
    this.titleWidget,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showBackButton = false,
    this.onBackPressed,
    this.padding = const EdgeInsets.all(AppTheme.space16),
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader =
        title != null ||
        titleWidget != null ||
        showBackButton ||
        (actions != null && actions!.isNotEmpty);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: hasHeader
          ? AppBar(
              backgroundColor: Colors.white.withValues(alpha: 0.85),
              elevation: 0,
              scrolledUnderElevation: 1,
              centerTitle: false,
              leading: showBackButton
                  ? const BackButton()
                  : null,
              title:
                  titleWidget ??
                  (title != null
                      ? Text(
                          title!,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        )
                      : null),
              actions: (() {
                final List<Widget> merged = [];
                if (showBackButton) {
                  merged.add(
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                    ),
                  );
                }
                if (actions != null) merged.addAll(actions!);
                return merged.isNotEmpty ? merged : null;
              })(),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF1F5F9), // Slate 100
              Color(0xFFE2E8F0), // Slate 200
              Color(0xFFEDF2F7), // Cool gray
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(padding: padding, child: body),
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

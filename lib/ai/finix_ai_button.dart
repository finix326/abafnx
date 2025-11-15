import 'package:flutter/material.dart';

import 'ai_prompt_sheet.dart';

class FinixAIButton extends StatelessWidget {
  const FinixAIButton({
    super.key,
    required this.contextDescription,
    this.initialText,
    this.onResult,
    this.size = 48,
    this.iconSize = 24,
    this.icon,
  });

  final String contextDescription;
  final String? initialText;
  final void Function(String aiText)? onResult;
  final double size;
  final double iconSize;
  final IconData? icon;

  factory FinixAIButton.small({
    Key? key,
    required String contextDescription,
    String? initialText,
    void Function(String aiText)? onResult,
  }) {
    return FinixAIButton(
      key: key,
      contextDescription: contextDescription,
      initialText: initialText,
      onResult: onResult,
      size: 40,
      iconSize: 20,
    );
  }

  factory FinixAIButton.iconOnly({
    Key? key,
    required String contextDescription,
    String? initialText,
    void Function(String aiText)? onResult,
    IconData icon = Icons.psychology_alt_outlined,
  }) {
    return FinixAIButton(
      key: key,
      contextDescription: contextDescription,
      initialText: initialText,
      onResult: onResult,
      size: 48,
      iconSize: 24,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIcon = icon ?? Icons.auto_awesome;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: theme.colorScheme.primaryContainer,
        shape: const CircleBorder(),
        elevation: 1,
        shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            showAIPromptSheet(
              context: context,
              contextDescription: contextDescription,
              initialText: initialText,
              onResult: onResult,
            );
          },
          child: Center(
            child: Icon(
              effectiveIcon,
              size: iconSize,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

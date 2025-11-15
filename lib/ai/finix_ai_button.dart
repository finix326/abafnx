import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state/current_student.dart';
import '../services/finix_data_service.dart';

import 'ai_prompt_sheet.dart';

class FinixAIButton extends StatelessWidget {
  const FinixAIButton({
    super.key,
    required this.contextDescription,
    required this.module,
    this.initialText,
    this.onResult,
    this.size = 48,
    this.iconSize = 24,
    this.icon,
    this.programName,
    this.programNameBuilder,
    this.logMetadata,
  });

  final String contextDescription;
  final String module;
  final String? initialText;
  final void Function(String aiText)? onResult;
  final double size;
  final double iconSize;
  final IconData? icon;
  final String? programName;
  final String? Function()? programNameBuilder;
  final Map<String, dynamic>? logMetadata;

  factory FinixAIButton.small({
    Key? key,
    required String contextDescription,
    required String module,
    String? initialText,
    void Function(String aiText)? onResult,
    String? programName,
    String? Function()? programNameBuilder,
    Map<String, dynamic>? logMetadata,
  }) {
    return FinixAIButton(
      key: key,
      contextDescription: contextDescription,
      module: module,
      initialText: initialText,
      onResult: onResult,
      size: 40,
      iconSize: 20,
      programName: programName,
      programNameBuilder: programNameBuilder,
      logMetadata: logMetadata,
    );
  }

  factory FinixAIButton.iconOnly({
    Key? key,
    required String contextDescription,
    required String module,
    String? initialText,
    void Function(String aiText)? onResult,
    IconData icon = Icons.psychology_alt_outlined,
    String? programName,
    String? Function()? programNameBuilder,
    Map<String, dynamic>? logMetadata,
  }) {
    return FinixAIButton(
      key: key,
      contextDescription: contextDescription,
      module: module,
      initialText: initialText,
      onResult: onResult,
      size: 48,
      iconSize: 24,
      icon: icon,
      programName: programName,
      programNameBuilder: programNameBuilder,
      logMetadata: logMetadata,
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
          onTap: () async {
            final sheetResult = await showAIPromptSheet(
              context: context,
              contextDescription: contextDescription,
              initialText: initialText,
              onResult: onResult,
            );

            if (sheetResult == null) {
              return;
            }

            final trimmedModule = module.trim();
            if (trimmedModule.isEmpty) {
              return;
            }

            final trimmedResult = sheetResult.result.trim();
            if (trimmedResult.isEmpty) {
              return;
            }

            final resolvedProgramName =
                programNameBuilder?.call() ?? programName?.trim();

            final currentStudent =
                Provider.maybeOf<CurrentStudent>(context, listen: false);
            final studentId = currentStudent?.currentStudentId?.trim();

            final payload = <String, dynamic>{
              'action': 'ai_suggestion',
              'prompt': sheetResult.prompt,
              'contextDescription': sheetResult.contextDescription,
              'initialText': sheetResult.initialText,
              'initialTextLength': (sheetResult.initialText ?? '').length,
              'result': trimmedResult,
              'resultLength': trimmedResult.length,
            };

            if (logMetadata != null && logMetadata!.isNotEmpty) {
              payload['metadata'] = Map<String, dynamic>.from(logMetadata!);
            }

            try {
              final record = FinixDataService.buildRecord(
                module: trimmedModule,
                data: payload,
                studentId: studentId,
                programName: resolvedProgramName,
              );
              unawaited(
                FinixDataService.saveRecord(record).catchError((error, stackTrace) {
                  debugPrint('FinixAIButton log save failed: $error\n$stackTrace');
                }),
              );
            } catch (error, stackTrace) {
              debugPrint('FinixAIButton log build failed: $error\n$stackTrace');
            }
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

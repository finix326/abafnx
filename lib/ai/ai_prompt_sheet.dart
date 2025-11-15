import 'package:flutter/material.dart';

import 'ai_engine.dart';

class AIPromptSheetResult {
  const AIPromptSheetResult({
    required this.prompt,
    required this.result,
    required this.contextDescription,
    this.initialText,
  });

  final String prompt;
  final String result;
  final String contextDescription;
  final String? initialText;
}

Future<AIPromptSheetResult?> showAIPromptSheet({
  required BuildContext context,
  required String contextDescription,
  String? initialText,
  void Function(String result)? onResult,
}) async {
  final promptController = TextEditingController();
  final contextController = TextEditingController(text: initialText ?? '');
  String? aiResult;
  bool isLoading = false;

  final result = await showModalBottomSheet<AIPromptSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setState) {
          Future<void> runPrompt() async {
            final instructions = promptController.text.trim();
            final trimmedContext = contextDescription.trim();

            if (trimmedContext.isEmpty && instructions.isEmpty) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                const SnackBar(content: Text('Lütfen bir komut yazın.')),
              );
              return;
            }

            final buffer = StringBuffer(trimmedContext);
            if (instructions.isNotEmpty) {
              buffer
                ..writeln('\n\n--- Kullanıcı Komutu ---')
                ..writeln(instructions);
            }

            final existing = contextController.text.trim();
            if (existing.isNotEmpty) {
              buffer
                ..writeln('\n\n--- Mevcut Metin ---')
                ..writeln(existing);
            }

            setState(() {
              isLoading = true;
            });

            try {
              final response = await AIEngine.generateText(buffer.toString());
              setState(() {
                aiResult = response.trim();
              });
            } catch (error) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(content: Text('AI isteği başarısız oldu: $error')),
              );
            } finally {
              setState(() {
                isLoading = false;
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Theme.of(sheetContext).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Finix AI Asistanı',
                          style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ) ??
                              const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    contextDescription,
                    style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: promptController,
                    maxLines: 4,
                    minLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Prompt metni',
                      hintText: 'AI\'ye göndermek istediğiniz yönergeyi yazın',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contextController,
                    maxLines: 4,
                    minLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Var olan metin (opsiyonel)',
                      hintText: 'AI\'ye göndermek istediğiniz mevcut içeriği yazın',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: isLoading ? null : runPrompt,
                    icon: isLoading
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(sheetContext).colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(isLoading ? 'Oluşturuluyor...' : 'AI\'den iste'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if ((aiResult ?? '').isNotEmpty) ...[
                    Text(
                      'AI sonucu',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(sheetContext).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        aiResult!,
                        style: Theme.of(sheetContext).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        final resolved = aiResult?.trim();
                        if (resolved == null || resolved.isEmpty) return;

                        final prompt = promptController.text.trim();
                        final initial = contextController.text.trim();

                        onResult?.call(resolved);
                        Navigator.of(sheetContext).pop(
                          AIPromptSheetResult(
                            prompt: prompt,
                            result: resolved,
                            contextDescription: contextDescription.trim(),
                            initialText: initial.isEmpty ? null : initial,
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Sonucu uygula'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );

  promptController.dispose();
  contextController.dispose();

  return result;
}

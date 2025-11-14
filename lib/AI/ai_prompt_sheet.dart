import 'package:flutter/material.dart';
import 'ai_engine.dart';

Future<void> showAIPromptSheet({
  required BuildContext context,
  required Function(String result) onCompleted,
}) async {
  final TextEditingController controller = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BAŞLIK
            const Text(
              "Yapay Zekâ İçerik Üretimi",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            // PROMPT ALANI
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Örn: 4 adet duygu kartı üret",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // OLUŞTUR BUTONU
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Oluştur",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: () async {
                final String prompt = controller.text.trim();

                if (prompt.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Lütfen bir komut yazın.")),
                  );
                  return;
                }

                Navigator.pop(context);

                // YAPAY ZEKA ÇAĞRISI
                String aiResponse = await AIEngine.generateText(prompt);

                onCompleted(aiResponse);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
    },
  );
}
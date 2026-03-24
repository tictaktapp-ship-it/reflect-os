import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

Future<void> showEmojiPickerSheet(
  BuildContext context, {
  required void Function(String emoji) onEmojiSelected,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    builder: (_) => SizedBox(
      height: 260,
      child: EmojiPicker(
        onEmojiSelected: (_, emoji) {
          onEmojiSelected(emoji.emoji);
          Navigator.of(context).pop();
        },
        config: Config(
          height: 260,
          checkPlatformCompatibility: true,
          emojiViewConfig: const EmojiViewConfig(
            emojiSizeMax: 28,
          ),
          bottomActionBarConfig:
              const BottomActionBarConfig(showBackspaceButton: false),
        ),
      ),
    ),
  );
}

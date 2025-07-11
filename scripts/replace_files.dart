import 'dart:io';

void main() async {
  final replacements = [
    {
      'source': '.github/replace/AndroidManifest.xml',
      'target': 'apps/mobile_app/android/app/src/main/AndroidManifest.xml',
    },
    {
      'source': '.github/replace/build.gradle.kts',
      'target': 'apps/mobile_app/android/app/build.gradle.kts',
    },  
    {
      'source': '.github/replace/drawable/ic_notification.png',
      'target': 'apps/mobile_app/android/app/src/main/res/drawable/ic_notification.png',
    },
    {
      'source': '.github/replace/drawable/ic_pause.png',
      'target': 'apps/mobile_app/android/app/src/main/res/drawable/ic_pause.png',
    },
    {
      'source': '.github/replace/drawable/ic_stop.png',
      'target': 'apps/mobile_app/android/app/src/main/res/drawable/ic_stop.png',
    },
  ];

  for (var file in replacements) {
    final sourceFile = File(file['source']!);
    final targetFile = File(file['target']!);

    if (!await sourceFile.exists()) {
      print('Source file not found: ${file['source']}');
      continue;
    }

    await targetFile.parent.create(recursive: true);

    final content = await sourceFile.readAsBytes();
    await targetFile.writeAsBytes(content);

    print('Replaced: ${file['target']}');
  }
}
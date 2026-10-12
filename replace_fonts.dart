import 'dart:io';

void main() {
  final dir = Directory('lib');
  for (var file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      String content = file.readAsStringSync();
      // Remove hardcoded fonts
      content = content.replaceAll(RegExp(r"fontFamily:\s*'Lalezar',?"), '');
      content = content.replaceAll(RegExp(r"fontFamily:\s*'DancingScript',?"), '');
      content = content.replaceAll(RegExp(r'fontFamily:\s*"Lalezar",?'), '');
      content = content.replaceAll(RegExp(r'fontFamily:\s*"DancingScript",?'), '');
      
      file.writeAsStringSync(content);
    }
  }
}

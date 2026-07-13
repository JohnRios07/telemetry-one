import 'dart:math';

const _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
final _random = Random();

String _generateRandomSuffix({int length = 8}) {
  return List.generate(
    length,
    (_) => _chars[_random.nextInt(_chars.length)],
  ).join();
}

String generateLocalSessionId() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return 'local_${now}_${_generateRandomSuffix()}';
}

bool isLocalSessionId(String id) => id.startsWith('local_');

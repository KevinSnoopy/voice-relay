import 'package:flutter_test/flutter_test.dart';
import 'package:voicerelay/screen/screen_client.dart';

void main() {
  test('screen window JSON maps to a display title', () {
    final window = ScreenWindow.fromJson(<String, dynamic>{
      'id': 42,
      'app': 'Safari',
      'title': '',
      'w': 1280,
      'h': 800,
      'focused': true,
      'current': false,
    });
    expect(window.id, 42);
    expect(window.displayTitle, 'Safari');
    expect(window.focused, isTrue);
  });
}

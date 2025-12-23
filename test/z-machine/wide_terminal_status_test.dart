import 'package:test/test.dart';
import 'package:zart/src/io/z_screen_model.dart';

void main() {
  test('ZScreenModel.resize should expand existing Window 1 rows', () {
    // 1. Initialize with default 80 cols
    final screen = ZScreenModel(cols: 80, rows: 24);

    // Split window to create at least one row in Window 1
    screen.splitWindow(1);
    expect(screen.window1Grid.length, 1);
    expect(screen.window1Grid[0].length, 80);

    // 2. Resize to 120 columns
    screen.resize(120, 24);
    expect(screen.cols, 120);
    expect(
      screen.window1Grid[0].length,
      120,
      reason: 'Row 0 should be resized to 120',
    );

    // 3. Write to a column > 80
    screen.setCursor(1, 100);
    screen.writeToWindow1('SCORE');

    // 4. Verify content at col 100
    // (setCursor is 1-indexed, so col 100 is index 99)
    expect(screen.window1Grid[0][99].char, 'S');
    expect(screen.window1Grid[0][100].char, 'C');
    expect(screen.window1Grid[0][101].char, 'O');
    expect(screen.window1Grid[0][102].char, 'R');
    expect(screen.window1Grid[0][103].char, 'E');
  });

  test('ZScreenModel.resize should truncate existing Window 1 rows', () {
    final screen = ZScreenModel(cols: 80, rows: 24);
    screen.splitWindow(1);

    screen.resize(40, 24);
    expect(screen.cols, 40);
    expect(screen.window1Grid[0].length, 40);
  });
}

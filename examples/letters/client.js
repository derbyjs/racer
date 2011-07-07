var board, col, colors, letters, row;
colors = ['red', 'yellow', 'blue', 'orange', 'green'];
letters = {};
for (row = 0; row <= 4; row++) {
  for (col = 0; col <= 25; col++) {
    letters[row * col] = {
      color: colors[row],
      value: String.fromCharCode(65 + col),
      x: col * 24,
      y: row * 36
    };
  }
}
board = $('#board');
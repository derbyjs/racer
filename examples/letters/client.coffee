colors = ['red', 'yellow', 'blue', 'orange', 'green']
letters = {}
for row in [0..4]
  for col in [0..25]
    letters[row * col] =
      color: colors[row]
      value: String.fromCharCode 65 + col
      x: col * 24
      y: row * 36

board = $('#board')


var app, express, fs, rally, script, style;
rally = require('rally');
express = require('express');
fs = require('fs');
script = rally.js() + fs.readFileSync('client.js');
style = fs.readFileSync('style.css');
rally({
  ioPort: 3001
});
app = express.createServer();
app.get('/', function(req, res) {
  return rally.subscribe('letters', function(err, model) {
    return model.json(function(json) {
      return res.send("<!DOCTYPE html>\n<title>Letters game</title>\n<style>" + style + "</style>\n<link href=http://fonts.googleapis.com/css?family=Anton&v1 rel=stylesheet>\n<div id=back>\n  <div id=page>\n    <p id=info>\n    <div id=board></div>\n  </div>\n</div>\n<script>\n  " + script + "\n  rally.init(" + json + ");\n</script>");
    });
  });
});
rally.store.flush(function() {
  var col, colors, letters, row;
  colors = ['red', 'yellow', 'blue', 'orange', 'green'];
  letters = {};
  for (row = 0; row <= 4; row++) {
    for (col = 0; col <= 25; col++) {
      letters[row * 26 + col] = {
        color: colors[row],
        value: String.fromCharCode(65 + col),
        left: col * 24 + 72,
        top: row * 32 + 8
      };
    }
  }
  return rally.store.set('letters', letters, function(err) {
    if (err) {
      throw err;
    }
    return app.listen(3000);
  });
});
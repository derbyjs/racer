var app, col, colors, express, fs, letters, rally, row;
rally = require('../../../rally');
express = require('express');
fs = require('fs');
app = express.createServer();
app.get('/', function(req, res) {
  return fs.readFile('client.js', 'utf8', function(err, clientScript) {
    return fs.readFile('style.css', 'utf8', function(err, style) {
      return rally.subscribe('letters', function(err, model) {
        var modelScript;
        modelScript = rally.js() + model.js();
        return res.send("<!DOCTYPE html>\n<title>Letters game</title>\n<style>" + style + "</style>\n<link href=http://fonts.googleapis.com/css?family=Anton&v1 rel=stylesheet>\n<div id=back>\n  <div id=page>\n    <p id=info>\n    <div id=board></div>\n  </div>\n</div>\n<script>" + (modelScript + clientScript) + "</script>");
      });
    });
  });
});
rally.store.flush();
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
rally.store.set('letters', letters, function(err) {
  if (err) {
    throw err;
  }
  return app.listen(3000);
});
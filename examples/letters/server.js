var app, boardHtml, express, fs;
express = require('express');
fs = require('fs');
app = express.createServer();
boardHtml = function() {
  var col, colors, html, id, letter, letters, row;
  colors = ['red', 'yellow', 'blue', 'orange', 'green'];
  letters = {};
  for (row = 0; row <= 4; row++) {
    for (col = 0; col <= 25; col++) {
      letters[row * 26 + col] = {
        color: colors[row],
        value: String.fromCharCode(65 + col),
        x: col * 24 + 72,
        y: row * 32 + 12
      };
    }
  }
  html = '';
  for (id in letters) {
    letter = letters[id];
    html += "<p class=\"" + letter.color + " letter\" id=" + id + "\nstyle=left:" + letter.x + "px;top:" + letter.y + "px>" + letter.value;
  }
  return html;
};
app.get('/', function(req, res) {
  return fs.readFile('client.js', 'utf8', function(err, script) {
    return fs.readFile('style.css', 'utf8', function(err, style) {
      return res.send("<!DOCTYPE html>\n<title>Letters game</title>\n<style>" + style + "</style>\n<link href=http://fonts.googleapis.com/css?family=Anton&v1 rel=stylesheet>\n<div id=back>\n  <div id=page>\n    <p id=info>\n    <div id=board>" + (boardHtml()) + "</div>\n  </div>\n</div>\n<script src=https://ajax.googleapis.com/ajax/libs/jquery/1.6.2/jquery.min.js></script>\n<script>" + script + "</script>");
    });
  });
});
app.listen(3000);
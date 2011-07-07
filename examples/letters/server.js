var app, express, fs;
express = require('express');
fs = require('fs');
app = express.createServer();
app.get('/', function(req, res) {
  return fs.readFile('client.js', 'utf8', function(err, script) {
    return fs.readFile('style.css', 'utf8', function(err, style) {
      return res.send("<!DOCTYPE html>\n<style>" + style + "</style>\n<title>Letters game</title>\n<div id=back>\n  <div id=page>\n    <p id=info>\n    <div id=board></div>\n  </div>\n</div>\n<script src=https://ajax.googleapis.com/ajax/libs/jquery/1.6.2/jquery.min.js></script>\n<script>" + script + "</script>");
    });
  });
});
app.listen(3000);
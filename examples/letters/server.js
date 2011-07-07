var app, express, fs;
express = require('express');
fs = require('fs');
app = express.createServer();
app.get('/', function(req, res) {
  return fs.readFile('client.js', 'utf8', function(err, script) {
    return fs.readFile('style.css', 'utf8', function(err, style) {
      return res.send("<!DOCTYPE html>\n<title>Letters game</title>\n<style>" + style + "</style>\n<link href=http://fonts.googleapis.com/css?family=Anton&v1 rel=stylesheet>\n<div id=back>\n  <div id=page>\n    <p id=info>\n    <div id=board></div>\n  </div>\n</div>\n<script>" + script + "</script>");
    });
  });
});
app.listen(3000);
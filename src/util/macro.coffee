fs = require 'fs'
path = require 'path'
existsSync = fs.existsSync || path.existsSync
{normalize, join} = path

exports.files = files = (dir, extension, out = []) ->
  fs.readdirSync(dir)
    .forEach (p) ->
      p = join dir, p
      if fs.statSync(p).isDirectory()
        files p, extension, out
      else if extension.test p
        out.push p
  return out

exports.watch = watch = (dir, extension, onChange) ->
  options = interval: 100
  files(dir, extension).forEach (file) ->
    fs.watchFile file, options, (curr, prev) ->
      onChange file  if prev.mtime < curr.mtime

condition = (s) ->
  s.replace(/\s+or\s+/g, "' || def == '").replace(/\s+and\s+/g, "' && def == '")

exports.compile = compile = (filename) ->
  console.log 'Compiling macro: ' + filename
  content = fs.readFileSync filename, 'utf8'

  warn = "##  WARNING:\\n" +
         "##  ========\\n" +
         "##  This file was compiled from a macro.\\n" +
         "##  Do not edit it directly.\\n\\n"
  script = "(function(){var out = '#{warn}';"
  for line in content.split '\n'
    if ~line.indexOf('#end')
      script += "}"
    else if match = /#if\s+(.*)/.exec line
      script += "if (def == '#{condition match[1]}') {"
    else if match = /#elseif\s+(.*)/.exec line
      script += "} else if (def == '#{condition match[1]}') {"
    else if ~line.indexOf('#else')
      script += "} else {"
    else if match = /#for\s+(.*)/.exec line
      defs = "['" + match[1].replace(/\s+/g, "','") + "']"
      script += "for (var defs = #{defs}, i = 0; def = defs[i++];) {"
    else
      line = line.replace /'/g, "\\'"
      script += "out += '#{line}\\n';"
  script += "return out;})()"
  content = eval script

  unless existsSync './dev'
    fs.mkdirSync './dev'
  filename = (filename[0..-7] + '.coffee').replace('/racer/src/', '/racer/dev/')
  fs.writeFileSync filename, content, 'utf8'

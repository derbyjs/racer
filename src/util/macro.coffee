fs = require 'fs'
path = require 'path'
coffee = require 'coffee-script'

condition = (s) ->
  s.replace(/\s+or\s+/g, "' || def == '").replace(/\s+and\s+/g, "' && def == '")

require.extensions['.macro'] = compileMacro = (module, filename) ->
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

  filename = filename.substr(0, filename.length - 6) + '.coffee'
  fs.writeFileSync filename, content, 'utf8'
  content = coffee.compile content, {filename}
  module._compile content, filename

require.extensions['.coffee'] = (module, filename) ->
  macroPath = filename.substr(0, filename.length - 7) + '.macro'
  if path.existsSync macroPath
    return compileMacro module, macroPath
  content = fs.readFileSync filename, 'utf8'
  content = coffee.compile content, {filename}
  module._compile content, filename

require '../../src/racer'

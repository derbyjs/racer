var fs = require('fs')
  , path = require('path')
  , existsSync = fs.existsSync || path.existsSync
  , normalize = path.normalize
  , join = path.join

exports.files = files
exports.watch = watch
exports.compile = compile

function files(dir, extension, out) {
  out = (out || [])

  fs.readdirSync(dir)
    .forEach(function(p) {
      p = join(dir, p)
      if (fs.statSync(p).isDirectory()) {
        files(p, extension, out)
      } else if (extension.test(p)) {
        out.push(p)
      }
    })
  return out
}

function watch(dir, extension, onChange) {
  var options = {interval: 100}
  files(dir, extension).forEach(function(file) {
    fs.watchFile(file, options, function(curr, prev) {
      if (prev.mtime < curr.mtime) {
        onChange(file)
      }
    })
  })
}

function condition(s) {
  return s.replace(/\s+or\s+/g, "' || def == '").replace(/\s+and\s+/g, "' && def == '")
}

function compile(filename) {
  console.log('Compiling macro: ' + filename)
  var content = fs.readFileSync(filename, 'utf8')
    , warn =
        "##  WARNING:\\n" +
        "##  ========\\n" +
        "##  This file was compiled from a macro.\\n" +
        "##  Do not edit it directly.\\n\\n"
    , script = "(function(){var out = '" + warn + "';\n"

  content.split('\n').forEach(function(line) {
    if (~line.indexOf('#end')) {
      script += "}\n"
    } else if (match = /#if\s+(.*)/.exec(line)) {
      script += "if (def == '" + condition(match[1]) + "') {\n"
    } else if (match = /#elseif\s+(.*)/.exec(line)) {
      script += "} else if (def == '" + condition(match[1]) + "') {\n"
    } else if (~line.indexOf('#else')) {
      script += "} else {\n"
    } else if (match = /#for\s+(.*)/.exec(line)) {
      defs = "['" + match[1].replace(/\s+/g, "','") + "']"
      script += "for (var defs = " + defs + ", i = 0; def = defs[i++];) {\n"
    } else {
      line = line.replace(/'/g, "\\'")
      script += "out += '" + line + "\\n';\n"
    }
  })
  script += "return out;})()"
  content = eval(script)

  if (!existsSync('./dev')) fs.mkdirSync('./dev')
  filename = (filename.slice(0, -6) + '.coffee').replace('/racer/src/', '/racer/dev/')
  fs.writeFileSync(filename, content, 'utf8')
}

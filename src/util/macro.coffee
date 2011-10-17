fs = require 'fs'
coffee = require 'coffee-script'

require.extensions['.coffee'] = (module, filename) ->
  content = fs.readFileSync filename, 'utf8'
  content = coffee.compile content, {filename}
  module._compile content, filename

require.extensions['.macro'] = (module, filename) ->
  console.log 'macro: ' + filename
  content = fs.readFileSync filename, 'utf8'
  content = coffee.compile content, {filename}
  module._compile content, filename

racer = require '../../src/racer'

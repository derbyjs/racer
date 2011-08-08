fs = require 'fs'
coffee = require 'coffee-script'

require.extensions['.coffee'] = (module, filename) ->
  content = fs.readFileSync filename, 'utf8'
  re = /# *debug: */gm
  content = content.replace re, ''
  content = coffee.compile content, {filename}
  module._compile content, filename

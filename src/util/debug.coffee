fs = require 'fs'
coffee = require 'coffee-script'

tags = []

require.extensions['.coffee'] = (module, filename) ->
  content = fs.readFileSync filename, 'utf8'
  unless tags.length
    re = /# *debug: */gm
  else
    re = new RegExp "# *debug (#{tags.join '|'}): *", 'gm'
  content = content.replace re, ''
  content = coffee.compile content, {filename}
  module._compile content, filename

module.exports = (_tags...) ->
  tags = tags.concat _tags

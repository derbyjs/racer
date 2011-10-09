should = require 'should'
pathParser = require 'pathParser'
require 'pathParser.server'

module.exports =
  'paths containing a segment starting with an underscore should be private': ->
    pathParser.isPrivate('_stuff').should.be.true
    pathParser.isPrivate('item._stu_ff').should.be.true
    pathParser.isPrivate('a.b.c.d._e.f.g').should.be.true
    pathParser.isPrivate('a').should.be.false
    pathParser.isPrivate('item.stuff').should.be.false
    pathParser.isPrivate('item_.stuff').should.be.false
    pathParser.isPrivate('item.stuff_').should.be.false
    pathParser.isPrivate('item_sdf.s_tuff').should.be.false
  
  'test pathParser.expand': ->
    
  
  # 'test compiling of path patterns into RegEx': ->
  #   reList = pattern for pattern in [
  #     'color'
  #     '*'
  #     '*.color.*'
  #     '**'
  #     '**.color.**'
  #     /^(colors?)$/
  #   ]
  #   sources = [
  #     '^color$'
  #     '^([^\\.]+)$'
  #     '^([^\\.]+)\\.color\\.([^\\.]+)$'
  #     '^(.+)$'
  #     '^(.+?)\\.color\\.(.+)$'
  #     '^(colors?)$'
  #   ]
  #   matches = [
  #     ['color': []]
  #     ['any-thing': ['any-thing']]
  #     ['x.color.y': ['x', 'y'],
  #      'any-thing.color.x': ['any-thing', 'x']]
  #     ['x': ['x'],
  #      'x.y': ['x.y']]
  #     ['x.color.y': ['x', 'y'],
  #      'a.b-c.color.x.y': ['a.b-c', 'x.y']]
  #     ['color': ['color'],
  #      'colors': ['colors']]
  #   ]
  #   nonMatches = [
  #     ['', 'xcolor', 'colorx', '.color', 'color.', 'x.color', 'color.x']
  #     ['', 'x.y', '.x', 'x.']
  #     ['x.colorx.y', 'x.xcolor.y', 'x.color', 'color.y',
  #      '.color.y', 'x.color.', 'a.x.color.y', 'x.color.y.b']
  #     ['']
  #     ['x.colorx.y', 'x.xcolor.y', 'x.color', 'color.y', '.color.y', 'x.color.']
  #     ['colorx']
  #   ]
  #   for re, i in reList
  #     re.source.should.equal sources[i]
  #     for obj in matches[i]
  #       for match, captures of obj
  #         re.exec(match).slice(1).should.eql captures
  #     re.test(nonMatch).should.be.false for nonMatch in nonMatches[i]

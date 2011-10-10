should = require 'should'
{isPrivate, expand} = require 'pathParser.server'

module.exports =
  'paths containing a segment starting with an underscore should be private': ->
    isPrivate('_stuff').should.be.true
    isPrivate('item._stu_ff').should.be.true
    isPrivate('a.b.c.d._e.f.g').should.be.true
    isPrivate('a').should.be.false
    isPrivate('item.stuff').should.be.false
    isPrivate('item_.stuff').should.be.false
    isPrivate('item.stuff_').should.be.false
    isPrivate('item_sdf.s_tuff').should.be.false
  
  'test expand': ->
    expand('colors.green').should.eql [
      'colors.green'
    ]
    expand('colors.(green,red)').should.eql [
      'colors.green'
      'colors.red'
    ]
    expand('colors.(green.(hex,name),red.*)').should.eql [
      'colors.green.hex'
      'colors.green.name'
      'colors.red.*'
    ]
    expand('colors.((hex,name).green,*.red)').should.eql [
      'colors.hex.green'
      'colors.name.green'
      'colors.*.red'
    ]
    expand('colors.(green.(hex,name),red.*).stuff').should.eql [
      'colors.green.hex.stuff'
      'colors.green.name.stuff'
      'colors.red.*.stuff'
    ]
    expand( 'colors.(
              green.(
                hex,
                name
              ),
              red.*,
              a.(
                more,
                over,
                here
              ).fun
            ).stuff.(
              and,
              here
            )').sort().should.eql [
      'colors.green.hex.stuff.and'
      'colors.green.hex.stuff.here'
      'colors.green.name.stuff.and'
      'colors.green.name.stuff.here'
      'colors.red.*.stuff.and'
      'colors.red.*.stuff.here'
      'colors.a.more.fun.stuff.and'
      'colors.a.more.fun.stuff.here'
      'colors.a.over.fun.stuff.and'
      'colors.a.over.fun.stuff.here'
      'colors.a.here.fun.stuff.and'
      'colors.a.here.fun.stuff.here'
    ].sort()
    expand( '(
              green.(
                hex,
                name
              ),(
                more,
                over,
                here
              ).fun
            ).stuff').sort().should.eql [
      'green.hex.stuff'
      'green.name.stuff'
      'more.fun.stuff'
      'over.fun.stuff'
      'here.fun.stuff'
    ].sort()
  
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

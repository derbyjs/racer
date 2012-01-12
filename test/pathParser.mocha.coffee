should = require 'should'
{isPrivate, regExp, eventRegExp, split, expand} = require '../src/pathParser'

testRegExps = (reList, sources, matches, nonMatches) ->
  for re, i in reList
    re.source.should.equal sources[i]
    for obj in matches[i]
      for match, captures of obj
        re.exec(match).slice(1).should.eql captures
    re.test(nonMatch).should.be.false for nonMatch in nonMatches[i]

describe 'pathParser', ->

  it 'paths containing a segment starting with an underscore should be private', ->
    isPrivate('_stuff').should.be.true
    isPrivate('item._stu_ff').should.be.true
    isPrivate('a.b.c.d._e.f.g').should.be.true
    isPrivate('a').should.be.false
    isPrivate('item.stuff').should.be.false
    isPrivate('item_.stuff').should.be.false
    isPrivate('item.stuff_').should.be.false
    isPrivate('item_sdf.s_tuff').should.be.false

  it 'test split', ->
    split('colors.green').should.eql ['colors.green']
    split('*.colors').should.eql ['', 'colors']
    split('colors.(green,red)').should.eql ['colors', 'green,red)']
    split('colors.*.hex').should.eql ['colors', 'hex']
  
  it 'test expand', ->
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
    expand('colors.(green(,.name))').should.eql [
      'colors.green'
      'colors.green.name'
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
              green.(hex,name),
              (more,over,here).fun
            ).stuff').sort().should.eql [
      'green.hex.stuff'
      'green.name.stuff'
      'more.fun.stuff'
      'over.fun.stuff'
      'here.fun.stuff'
    ].sort()

  it 'test compiling of path patterns into RegEx', ->
    reList = (regExp pattern for pattern in [
      ''
      'color'
      '*.color'
      'color.*.name'
    ])
    sources = [
      '^'
      '^color(?:\\.|$)'
      '^[^.]+\\.color(?:\\.|$)'
      '^color\\.[^.]+\\.name(?:\\.|$)'
    ]
    matches = [
      ['x': [],
       'x.y': []]
      ['color': [],
       'color.x': [],
       'color.x.y': []]
      ['x.color.y': [],
       'any-thing.color.x.y.z': []]
      ['color.x.name': [],
       'color.x.name.z': []]
    ]
    nonMatches = [
      []
      ['', 'xcolor', 'colorx', 'x.color']
      ['color', 'x.colorx', 'x.xcolor', 'a.x.color']
      ['colorx.x.name', 'color.x.namex', 'color.x.y.name']
    ]
    testRegExps reList, sources, matches, nonMatches

  it 'test compiling of event patterns into RegEx', ->
    reList = (eventRegExp pattern for pattern in [
      'color'
      '*'
      '*.color.*'
      'color.*.name'
      'colors.(red,green)'
      /^(colors?)$/
    ])
    sources = [
      '^color$'
      '^(.+)$'
      '^([^.]+)\\.color\\.(.+)$'
      '^color\\.([^.]+)\\.name$'
      '^colors\\.(red|green)$'
      '^(colors?)$'
    ]
    matches = [
      ['color': []]
      ['x': ['x'],
       'x.y': ['x.y']]
      ['x.color.y': ['x', 'y'],
       'any-thing.color.x.y': ['any-thing', 'x.y']]
      ['color.x.name': ['x']]
      ['colors.red': ['red'],
       'colors.green': ['green']]
      ['color': ['color'],
       'colors': ['colors']]
    ]
    nonMatches = [
      ['', 'xcolor', 'colorx', '.color', 'color.', 'x.color', 'color.x']
      ['']
      ['x.colorx.y', 'x.xcolor.y', 'x.color', 'color.y',
       '.color.y', 'x.color.', 'a.x.color.y']
      ['colorx.x.name', 'color.x.namex', 'color.x.y.name']
      ['colors.yellow', 'colors.']
      ['colorx']
    ]
    testRegExps reList, sources, matches, nonMatches

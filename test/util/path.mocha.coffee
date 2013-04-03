{expect} = require './util'
{ isPrivate
, regExp
, eventRegExp
, split
, expand
, objectExcept
, join} = require '../lib/path'

testRegExps = (reList, sources, matches, nonMatches) ->
  for re, i in reList
    expect(re.source).to.equal sources[i]
    for obj in matches[i]
      for match, captures of obj
        expect(re.exec(match).slice 1).to.eql captures
    expect(re.test nonMatch).to.be.false for nonMatch in nonMatches[i]

describe 'path', ->

  it 'paths containing a segment starting with an underscore should be private', ->
    expect(isPrivate '_stuff').to.be.true
    expect(isPrivate 'item._stu_ff').to.be.true
    expect(isPrivate 'a.b.c.d._e.f.g').to.be.true
    expect(isPrivate 'a').to.be.false
    expect(isPrivate 'item.stuff').to.be.false
    expect(isPrivate 'item_.stuff').to.be.false
    expect(isPrivate 'item.stuff_').to.be.false
    expect(isPrivate 'item_sdf.s_tuff').to.be.false

  it 'test split', ->
    expect(split 'colors.green').to.eql ['colors.green']
    expect(split '*.colors').to.eql ['', 'colors']
    expect(split 'colors.(green,red)').to.eql ['colors', 'green,red)']
    expect(split 'colors.*.hex').to.eql ['colors', 'hex']

  it 'test expand', ->
    expect(expand 'colors.green').to.eql [
      'colors.green'
    ]
    expect(expand 'colors.(green,red)').to.eql [
      'colors.green'
      'colors.red'
    ]
    expect(expand 'colors.(green.(hex,name),red.*)').to.eql [
      'colors.green.hex'
      'colors.green.name'
      'colors.red.*'
    ]
    expect(expand 'colors.((hex,name).green,*.red)').to.eql [
      'colors.hex.green'
      'colors.name.green'
      'colors.*.red'
    ]
    expect(expand 'colors.(green.(hex,name),red.*).stuff').to.eql [
      'colors.green.hex.stuff'
      'colors.green.name.stuff'
      'colors.red.*.stuff'
    ]
    expect(expand 'colors.(green(,.name))').to.eql [
      'colors.green'
      'colors.green.name'
    ]
    expect(expand(
      'colors.(
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
      )').sort()).to.eql [
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
    expect(expand(
      '(
        green.(hex,name),
        (more,over,here).fun
      ).stuff').sort()).to.eql [
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

  describe 'path.objectExcept', ->
    it 'should return a new Object without the exceptions', ->
      obj = a: 1, b: 2, c: 3
      exceptions = ['a', 'c']
      newObj = objectExcept obj, exceptions
      expect(newObj).to.only.have.key('b')

    it 'should handle nested exceptions', ->
      obj =
        city: 'SF'
        name:
          first: 'B'
          middle: 'N'
          last: 'N'
      exceptions = ['name.first', 'name.middle']
      newObj = objectExcept obj, exceptions
      expect(newObj).to.only.have.key('city', 'name')
      expect(newObj.name).to.only.have.key('last')

    it 'should handle array index exceptions'

  describe '#join', ->
    it 'should work on 2 strings', ->
      expect(join 'a', 'b').to.equal 'a.b'

    it 'should work on 2 arrays', ->
      expect(join ['a', 'b'], ['c', 'd']).to.equal 'a.b.c.d'

    it 'should work on a string and an array', ->
      expect(join 'a.b', ['c', 'd']).to.equal 'a.b.c.d'

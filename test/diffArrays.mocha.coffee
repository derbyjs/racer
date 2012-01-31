{diffArrays} = require '../src/diffMatchPatch'
should = require 'should'
{calls} = require './util'

describe 'diffArrays', ->

  test = ({before, after, expect}) ->
    calls expect.length, (done) ->
      i = 0
      diffArrays before, after, (args...) ->
        args.unshift 'ins'
        args.should.eql expect[i++]
        done()
      , (args...) ->
        args.unshift 'rem'
        args.should.eql expect[i++]
        done()
      , (args...) ->
        args.unshift 'mov'
        args.should.eql expect[i++]
        done()

  log = ({before, after}) -> ->
    console.log ''
    diffArrays before, after, (args...) ->
      args.unshift 'ins'
      console.log args
    , (args...) ->
      args.unshift 'rem'
      console.log args
    , (args...) ->
      args.unshift 'mov'
      console.log args

  it 'detects insert in middle', test
    before: [0, 1, 2]
    after:  [0, 3, 1, 2]
    expect: [['ins', 1, [3]]]

  it 'detects insert at end', test
    before: [0, 1, 2]
    after:  [0, 1, 2, 3]
    expect: [['ins', 3, [3]]]

  it 'detects multiple item insert', test
    before: [0, 1, 2]
    after:  [3, 4, 0, 1, 2]
    expect: [['ins', 0, [3, 4]]]

  it 'detects multiple inserts', test
    before: [0, 1, 2]
    after:  [3, 0, 4, 5, 1, 2, 6]
    expect: [
      ['ins', 0, [3]]
      ['ins', 2, [4, 5]]
      ['ins', 6, [6]]
    ]

  it 'detects remove in middle', test
    before: [0, 3, 1, 2]
    after:  [0, 1, 2]
    expect: [['rem', 1, 1]]

  it 'detects remove at end', test
    before: [0, 1, 2, 3]
    after:  [0, 1, 2]
    expect: [['rem', 3, 1]]

  it 'detects multiple item remove', test
    before: [3, 4, 0, 1, 2]
    after:  [0, 1, 2]
    expect: [['rem', 0, 2]]

  it 'detects multiple removes', test
    before: [3, 0, 4, 5, 1, 2, 6]
    after:  [0, 1, 2]
    expect: [
      ['rem', 0, 1]
      ['rem', 1, 2]
      ['rem', 3, 1]
    ]

  it 'detects insert then remove', test
    before: [0, 1, 2, 5, 6]
    after:  [0, 3, 4, 1, 2]
    expect: [
      ['ins', 1, [3, 4]]
      ['rem', 5, 2]
    ]
  
  it 'detects remove then insert', test
    before: [0, 3, 4, 1, 2]
    after:  [0, 1, 2, 5, 6]
    expect: [
      ['rem', 1, 2]
      ['ins', 3, [5, 6]]
    ]

  it 'detects insert and remove at same position', test
    before: [0, 5, 6, 1, 2]
    after:  [0, 3, 4, 1, 2]
    expect: [
      ['ins', 1, [3, 4]]
      ['rem', 3, 2]
    ]

  it 'detects insert then remove overlapping', test
    before: [0, 5, 1, 2]
    after:  [0, 3, 4, 1, 2]
    expect: [
      ['ins', 1, [3, 4]]
      ['rem', 3, 1]
    ]

  it 'detects remove then insert overlapping', test
    before: [0, 3, 4, 5, 1, 2]
    after:  [0, 1, 6, 2]
    expect: [
      ['rem', 1, 3]
      ['ins', 2, [6]]
    ]

  it 'detects single move', test
    before: [1, 2, 0, 3]
    after:  [0, 1, 2, 3]
    expect: [['mov', 2, 0, 1]]

  it 'detects multiple move middle', test
    before: [0, 1, 2, 3]
    after:  [1, 2, 0, 3]
    expect: [['mov', 1, 0, 2]]

  it 'detects multiple move from end', test
    before: [0, 1, 2, 3]
    after:  [2, 3, 0, 1]
    expect: [['mov', 2, 0, 2]]

  it 'detects move from end to start', test
    before: [0, 1, 2, 3]
    after:  [3, 0, 1, 2]
    expect: [
      ['mov', 3, 0, 1]
    ]

  it 'detects move from start to end', test
    before: [3, 0, 1, 2]
    after:  [0, 1, 2, 3]
    expect: [
      ['mov', 1, 0, 3]
    ]

  it 'detects overlapping moves', test
    before: [0, 1, 2, 3]
    after:  [3, 2, 1, 0]
    expect: [
      ['mov', 3, 0, 1]
      ['mov', 3, 1, 1]
      ['mov', 3, 2, 1]
    ]

  it 'detects insert then move', test
    before: [0, 1, 2]
    after:  [3, 1, 2, 0]
    expect: [
      ['ins', 0, [3]]
      ['mov', 2, 1, 2]
    ]

  it 'detects move then insert', test
    before: [0, 1, 2]
    after:  [1, 2, 0, 3]
    expect: [
      ['mov', 1, 0, 2]
      ['ins', 3, [3]]
    ]

  it 'detects insert within move', test
    before: [0, 1, 2]
    after:  [2, 3, 0, 1]
    expect: [
      ['mov', 2, 0, 1]
      ['ins', 1, [3]]
    ]

  it 'detects insert within move then move', test
    before: [0, 1, 2]
    after:  [2, 3, 1, 0]
    expect: [
      ['mov', 2, 0, 1]
      ['ins', 1, [3]]
      ['mov', 3, 2, 1]
    ]

  it 'detects remove then move', test
    before: [0, 1, 2]
    after:  [2, 1]
    expect: [
      ['rem', 0, 1]
      ['mov', 1, 0, 1]
    ]

  it 'detects move then remove', test
    before: [0, 1, 2]
    after:  [2, 0]
    expect: [
      ['mov', 2, 0, 1]
      ['rem', 2, 1]
    ]

  it 'detects remove within move', test
    before: [0, 1, 2, 3, 4]
    after: [4, 0, 2, 3]
    expect: [
      ['mov', 4, 0, 1]
      ['rem', 2, 1]
    ]

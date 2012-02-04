{diffArrays} = require '../src/diffMatchPatch'
should = require 'should'
{calls} = require './util'

describe 'diffArrays', ->

  test = ({before, after, expect}) -> ->
    diffArrays(before, after).should.specEql expect

  log = ({before, after}) -> ->
    console.log ''
    console.log diffArrays before, after

  it 'detects insert in middle', test
    before: [0, 1, 2]
    after:  [0, 3, 1, 2]
    expect: [['insert', 1, 3]]

  it 'detects insert at end', test
    before: [0, 1, 2]
    after:  [0, 1, 2, 3]
    expect: [['insert', 3, 3]]

  it 'detects multiple item insert', test
    before: [0, 1, 2]
    after:  [3, 4, 0, 1, 2]
    expect: [['insert', 0, 3, 4]]

  it 'detects multiple inserts', test
    before: [0, 1, 2]
    after:  [3, 0, 4, 5, 1, 2, 6]
    expect: [
      ['insert', 0, 3]
      ['insert', 2, 4, 5]
      ['insert', 6, 6]
    ]

  it 'detects remove in middle', test
    before: [0, 3, 1, 2]
    after:  [0, 1, 2]
    expect: [['remove', 1, 1]]

  it 'detects remove at end', test
    before: [0, 1, 2, 3]
    after:  [0, 1, 2]
    expect: [['remove', 3, 1]]

  it 'detects multiple item remove', test
    before: [3, 4, 0, 1, 2]
    after:  [0, 1, 2]
    expect: [['remove', 0, 2]]

  it 'detects multiple removes', test
    before: [3, 0, 4, 5, 1, 2, 6]
    after:  [0, 1, 2]
    expect: [
      ['remove', 0, 1]
      ['remove', 1, 2]
      ['remove', 3, 1]
    ]

  it 'detects insert then remove', test
    before: [0, 1, 2, 5, 6]
    after:  [0, 3, 4, 1, 2]
    expect: [
      ['insert', 1, 3, 4]
      ['remove', 5, 2]
    ]

  it 'detects remove then insert', test
    before: [0, 3, 4, 1, 2]
    after:  [0, 1, 2, 5, 6]
    expect: [
      ['remove', 1, 2]
      ['insert', 3, 5, 6]
    ]

  it 'detects insert and remove at same position', test
    before: [0, 5, 6, 1, 2]
    after:  [0, 3, 4, 1, 2]
    expect: [
      ['insert', 1, 3, 4]
      ['remove', 3, 2]
    ]
  
  it 'detects insert and remove all', test
    before: [1, 2, 3]
    after:  [4, 5]
    expect: [
      ['insert', 0, 4, 5]
      ['remove', 2, 3]
    ]

  it 'detects insert then remove overlapping', test
    before: [0, 5, 1, 2]
    after:  [0, 3, 4, 1, 2]
    expect: [
      ['insert', 1, 3, 4]
      ['remove', 3, 1]
    ]

  it 'detects remove then insert overlapping', test
    before: [0, 3, 4, 5, 1, 2]
    after:  [0, 1, 6, 2]
    expect: [
      ['remove', 1, 3]
      ['insert', 2, 6]
    ]

  it 'detects single move forward', test
    before: [0, 1, 2, 3]
    after:  [1, 2, 0, 3]
    expect: [['move', 0, 2, 1]]

  it 'detects sinlge move backward', test
    before: [1, 2, 0, 3]
    after:  [0, 1, 2, 3]
    expect: [['move', 2, 0, 1]]

  it 'detects multiple move forward', test
    before: [0, 1, 2, 3, 4]
    after:  [2, 3, 4, 0, 1]
    expect: [['move', 0, 3, 2]]

  it 'detects insert then move forward', test
    before: [0, 1, 2, 3]
    after:  [4, 1, 2, 0, 3]
    expect: [
      ['insert', 0, 4]
      ['move', 1, 3, 1]
    ]

  it 'detects insert then move backward', test
    before: [1, 2, 0, 3]
    after:  [4, 0, 1, 2, 3]
    expect: [
      ['insert', 0, 4]
      ['move', 3, 1, 1]
    ]

  it 'detects remove then move forward', test
    before: [0, 1, 2, 3]
    after:  [2, 3, 1]
    expect: [
      ['remove', 0, 1]
      ['move', 0, 2, 1]
    ]

  it 'detects remove then move backward', test
    before: [0, 1, 2, 3]
    after:  [3, 1, 2]
    expect: [
      ['remove', 0, 1]
      ['move', 2, 0, 1]
    ]

  it 'detects move from start to end & middle forward', test
    before: [0, 1, 2, 3, 4]
    after:  [1, 3, 4, 2, 0]
    expect: [
      ['move', 0, 4, 1]
      ['move', 1, 3, 1]
    ]

  it 'detects move from start to end & middle backward', test
    before: [0, 1, 2, 3, 4]
    after:  [1, 4, 2, 3, 0]
    expect: [
      ['move', 0, 4, 1]
      ['move', 3, 1, 1]
    ]

  it 'detects move from end to start & middle forward', test
    before: [0, 1, 2, 3, 4]
    after:  [4, 0, 2, 3, 1]
    expect: [
      ['move', 4, 0, 1]
      ['move', 2, 4, 1]
    ]

  it 'detects move from end to start & middle backward', test
    before: [0, 1, 2, 3, 4]
    after:  [4, 0, 3, 1, 2]
    expect: [
      ['move', 4, 0, 1]
      ['move', 4, 2, 1]
    ]

  it 'detects move forward and backward from start', test
    before: [0, 1, 2, 3, 4]
    after:  [3, 2, 4, 0, 1]
    expect: [
      ['move', 0, 3, 2]
      ['move', 1, 0, 1]
    ]

  it 'detects reversing', test
    before: [0, 1, 2, 3, 4, 5]
    after:  [5, 4, 3, 2, 1, 0]
    expect: [
      ['move', 0, 5, 1]
      ['move', 4, 0, 1]
      ['move', 1, 4, 1]
      ['move', 3, 1, 1]
      ['move', 2, 3, 1]
    ]

  it 'detects move from start to middle & middle to end', test
    before: [0, 1, 2, 3, 4]
    after:  [1, 2, 0, 4, 3]
    expect: [
      ['move', 0, 2, 1]
      ['move', 3, 4, 1]
    ]

  it 'detects move both ways from start to middle & middle to end', test
    before: [0, 1, 2, 3, 4]
    after:  [2, 1, 0, 4, 3]
    expect: [
      ['move', 0, 2, 1]
      ['move', 1, 0, 1]
      ['move', 3, 4, 1]
    ]

  it 'detects move both ways from start to middle & middle to end overlapping', test
    before: [0, 1, 2, 3, 4]
    after:  [2, 1, 4, 3, 0]
    expect: [
      ['move', 0, 4, 1]
      ['move', 1, 0, 1]
      ['move', 2, 3, 1]
    ]

  it 'detects move from start to middle & both ways', test
    before: [0, 1, 2, 3, 4]
    after:  [1, 3, 0, 4, 2]
    expect: [
      ['move', 0, 2, 1]
      ['move', 1, 4, 1]
      ['move', 2, 1, 1]
    ]

  it 'detects insert within forward move', test
    before: [0, 1, 2]
    after:  [1, 3, 2, 0]
    expect: [
      ['move', 0, 2, 1]
      ['insert', 1, 3]
    ]

  it 'detects insert within multiple forward move', test
    before: [0, 1, 2]
    after:  [2, 3, 0, 1]
    expect: [
      ['move', 0, 1, 2]
      ['insert', 1, 3]
    ]

  it 'detects insert within backward move', test
    before: [0, 1, 2, 3, 4]
    after:  [3, 0, 1, 2, 5, 4]
    expect: [
      ['move', 3, 0, 1]
      ['insert', 4, 5]
    ]

  it 'detects remove within backward move', test
    before: [0, 1, 2, 3]
    after:  [3, 0, 2]
    expect: [
      ['move', 3, 0, 1]
      ['remove', 2, 1]
    ]

  it 'detects remove within forward move', test
    before: [0, 1, 2, 3]
    after:  [1, 3, 0]
    expect: [
      ['move', 0, 3, 1]
      ['remove', 1, 1]
    ]

  it 'detects multiple overlapping moves', test
    before: [0, 1, 2, 3, 4, 5, 6, 7]
    after:  [1, 6, 2, 7, 3, 4, 0, 5]
    expect: [
      ['move', 0, 5, 1]
      ['move', 6, 1, 1]
      ['move', 7, 3, 1]
    ]

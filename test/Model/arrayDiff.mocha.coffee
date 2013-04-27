{expect} = require '../util'
arrayDiff = require '../../lib/Model/arrayDiff'

{InsertDiff, RemoveDiff, MoveDiff} = arrayDiff

insert = (array, index, values) ->
  array.splice.apply array, [index, 0].concat(values)
remove = (array, index, howMany) ->
  array.splice index, howMany
move = (array, from, to, howMany) ->
  values = remove array, from, howMany
  insert array, to, values

applyDiff = (before, diff) ->
  out = before.slice()
  for item in diff
    console.log 'applying:', out, item
    if item instanceof InsertDiff
      insert out, item.index, item.values
    else if item instanceof RemoveDiff
      remove out, item.index, item.howMany
    else if item instanceof MoveDiff
      move out, item.from, item.to, item.howMany
  return out

randomWhole = (max) ->
  Math.floor Math.random() * (max + 1)

randomArray = ->
  i = randomWhole 10
  return (randomWhole 10 while i--)

describe 'arrayDiff', ->

  testDiff = (before, after) ->
    diff = arrayDiff(before, after)
    console.log('DIFF', diff)
    expected = applyDiff before, diff
    console.log(expected)
    expect(expected).to.eql after

  # it "diffs", ->
  #   before = [ 2, 2, 0, 1, 5 ]
  #   after = [ 4, 1, 5, 2, 0 ]
  #   testDiff before, after

  # it "diffs", ->
  #   before = [ 2, 0, 4, 2 ]
  #   after = [ 4, 2, 1, 0 ]
  #   testDiff before, after

  it "diffs random arrays of numbers", ->
    i = 1000
    while i--
      before = randomArray()
      after = randomArray()
      testDiff before, after

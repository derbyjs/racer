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
    # console.log 'applying:', out, item
    if item instanceof InsertDiff
      insert out, item.index, item.values
    else if item instanceof RemoveDiff
      remove out, item.index, item.howMany
    else if item instanceof MoveDiff
      move out, item.from, item.to, item.howMany
  return out

randomWhole = (max) ->
  Math.floor Math.random() * (max + 1)

randomArray = (maxLength = 20, maxValues = maxLength) ->
  i = randomWhole maxLength
  return (randomWhole maxValues while i--)

testDiff = (before, after) ->
  # console.log()
  # console.log 'before =', before
  # console.log 'after =', after
  diff = arrayDiff before, after
  expected = applyDiff before, diff
  expect(expected).to.eql after

describe 'arrayDiff', ->

  it 'diffs empty arrays', ->
    testDiff [], []
    testDiff [], [0, 1, 2]
    testDiff [0, 1, 2], []

  it 'diffs randomly rearranged arrays of numbers', ->
    i = 1000
    while i--
      # before = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19]
      before = randomArray 50
      after = before.slice().sort(-> Math.random() - 0.5)
      testDiff before, after
    return

  it "diffs random arrays of numbers", ->
    i = 1000
    while i--
      before = randomArray 50, 20
      after = randomArray 50, 20
      testDiff before, after
    return

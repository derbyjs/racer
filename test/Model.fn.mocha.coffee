Model = require '../src/Model'
should = require 'should'
{calls, isNaN} = require './util'

describe 'Model.fn', ->

  it 'supports get with single input', ->
    model = new Model
    model.set 'arg', 3
    out = model.fn '_out', 'arg', (arg) -> arg * 5
    out.should.eql 15
    model.get('_out').should.eql 15

  it 'supports get with multiple inputs', ->
    model = new Model
    model.set 'arg1', 3
    model.set 'arg2', 5
    out = model.fn '_out', 'arg1', 'arg2', (arg1, arg2) -> arg1 * arg2
    out.should.eql 15
    model.get('_out').should.eql 15

  it 'updates on input set and del', ->
    model = new Model
    model.set 'arg1', 3
    model.set 'arg2', 5
    model.fn '_out', 'arg1', 'arg2', (arg1, arg2) -> arg1 * arg2

    model.set 'arg1', 4
    model.get('_out').should.eql 20

    model.del 'arg2'
    isNaN model.get('_out')

    model.set 'arg2', 7
    model.get('_out').should.eql 28

  it 'updates on property change of input', ->
    model = new Model
    model.set 'items', [1, 2, 3]
    model.fn '_reversed', 'items', (items) -> items.slice().reverse()

    model.get('items').should.specEql [1, 2, 3]
    model.get('_reversed').should.specEql [3, 2, 1]

    model.set 'items.2', 4
    model.get('items').should.specEql [1, 2, 4]
    model.get('_reversed').should.specEql [4, 2, 1]

  it 'updates on nested property of input', ->
    model = new Model
    model.set 'items', [
      {score: 0, name: 'x'}
      {score: 2, name: 'y'}
      {score: 1, name: 'z'}
    ]
    model.fn '_sorted', 'items', (items) ->
      items.slice().sort (a, b) -> a.score - b.score
  
    model.get('items').should.specEql [
      {score: 0, name: 'x'}
      {score: 2, name: 'y'}
      {score: 1, name: 'z'}
    ]
    model.get('_sorted').should.specEql [
      {score: 0, name: 'x'}
      {score: 1, name: 'z'}
      {score: 2, name: 'y'}
    ]

    model.set 'items.0.score', 10
    model.get('items').should.specEql [
      {score: 10, name: 'x'}
      {score: 2, name: 'y'}
      {score: 1, name: 'z'}
    ]
    model.get('_sorted').should.specEql [
      {score: 1, name: 'z'}
      {score: 2, name: 'y'}
      {score: 10, name: 'x'}
    ]

{expect} = require '../util'

{Model} = require('../../lib/racer').protected

describe 'Model#context', ->
  it 'should default Model#currContext to "default" before the block', ->
    model = new Model
    expect(model.currContext).to.eql name: 'default'

  it 'should set Model#currContext inside the block', ->
    model = new Model
    model.context 'inception', ->
      expect(model.currContext).to.eql name: 'inception'

  it 'should set Model#currContext to "default" after the block', ->
    model = new Model
    expect(model.currContext).to.eql name: 'default'


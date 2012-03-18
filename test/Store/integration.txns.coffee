{expect} = require '../util'
{mockFullSetup} = require '../util/model'

module.exports = (getStore) ->

  it 'events should be emitted in remote subscribed models',
    mockFullSetup getStore, (modelA, modelB, done) ->
      modelA.on 'set', '_test.color', (value, previous, isLocal) ->
        expect(value).to.equal 'green'
        expect(previous).to.equal undefined
        expect(isLocal).to.equal false
        expect(modelA.get '_test.color').to.equal 'green'
        done()
      modelB.set '_test.color', 'green'

  # TODO: Lots of tests needed

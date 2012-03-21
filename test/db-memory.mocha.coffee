#require('./dbAdapter') type: 'Memory'
shouldBehaveLikeDbAdapter = require './dbAdapter'
racer = require '../lib/racer'

describe "Memory db adapter", ->

  shouldBehaveLikeDbAdapter()

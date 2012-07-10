sinon = require 'sinon'
createMiddleware = require '../lib/middleware'
{expect} = require './util'

describe 'middleware', ->
  it 'should pass control along via next', ->
    middleware = createMiddleware()
    spyA = sinon.spy()
    spyB = sinon.spy()
    middleware.add (req, res, next) ->
      spyA()
      next()
    middleware.add (req, res, next) ->
      spyB()
      next()
    middleware {}, {}
    expect(spyA).to.be.calledOnce()
    expect(spyB).to.be.calledOnce()

  it 'should be able to nest a middleware chain inside another one', ->
    chainA = createMiddleware()
    spyA1 = sinon.spy()
    spyA2 = sinon.spy()
    chainA.add (req, res, next) ->
      spyA1()
      next()
    chainA.add (req, res, next) ->
      spyA2()
      next()

    spyB1 = sinon.spy()
    spyB2 = sinon.spy()
    chainB = createMiddleware()
    chainB.add (req, res, next) ->
      spyB1()
      next()

    chainB.add chainA

    chainB.add (req, res, next) ->
      spyB2()
      next()

    chainB {}, {}
    expect(spyA1).to.be.calledOnce()
    expect(spyA2).to.be.calledOnce()
    expect(spyB1).to.be.calledOnce()
    expect(spyB2).to.be.calledOnce()

should = require 'should'
inspect = require('util').inspect
specHelper = require '../../src/specHelper'

exports.wrapTest = (fn, numCallbacks = 1) ->
  (beforeExit) ->
    n = 0
    fn -> n++
    beforeExit ->
      n.should.equal numCallbacks

flatten = (a) ->
  if typeof a is 'object'
    obj = if specHelper.isArray a then [] else {}
  else
    return a
  if specHelper.isArray a
    for val, i in a
      obj[i] = flatten val
  else
    for key, val of a
      obj[key] = flatten val
  return obj

exports.protoInspect = protoInspect = (a) -> inspect flatten(a), false, null

removeReserved = (a) ->
  if typeof a == 'object'
    for key, val of a
      unless -1 == specHelper.reserved.indexOf key
        delete a[key]
        continue
      a[key] = removeReserved val
  return a
exports.specInspect = specInspect = (a) -> inspect removeReserved(flatten(a)), false, null

protoSubset = (a, b, exception) ->
  checkProp = (i) ->
    if typeof a[i] is 'object'
      return false unless typeof b[i] is 'object'
      return false unless protoSubset a[i], b[i], exception
    else
      return false unless exception && exception(a, b, i) || a[i] == b[i]
  if specHelper.isArray a
    for v, i in a
      return false if checkProp(i) == false
  else
    for i of a
      return false if checkProp(i) == false
  return true

protoEql = (a, b) -> protoSubset(a, b) && protoSubset(b, a)

should.Assertion::protoEql = (val) ->
  @assert protoEql(val, @obj),
    """expected \n
    #{protoInspect @obj} \n
    to prototypically equal \n
    #{protoInspect val} \n""",
    """expected \n
    #{protoInspect @obj} \n
    to not prototypically equal \n
    #{protoInspect val} \n"""
  return this


specEql = (a, b) ->
  exception = (objA, objB, prop) ->
    return true unless -1 == specHelper.reserved.indexOf prop
    return false
  protoSubset(a, b, exception) && protoSubset(b, a, exception)

should.Assertion::specEql = (val) ->
  @assert specEql(val, @obj),
    """expected \n
    #{specInspect @obj} \n
    to speculatively equal \n
    #{specInspect val} \n""",
    """expected \n
    #{specInspect @obj} \n
    to not speculatively equal \n
    #{specInspect val} \n"""
  return this

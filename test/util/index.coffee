should = require 'should'
inspect = require('util').inspect

exports.wrapTest = (fn, numCallbacks = 1) ->
  (beforeExit) ->
    n = 0
    fn -> n++
    beforeExit ->
      n.should.equal numCallbacks

flatten = (a) ->
  if typeof a is 'object'
    obj = if Array.isArray a then [] else {}
  else
    return a
  for key, val of a
    obj[key] = flatten val
  return obj

exports.protoInspect = protoInspect = (a) -> inspect flatten a

protoSubset = (a, b) ->
  for i of a
    if typeof a[i] is 'object'
      return false unless typeof b[i] is 'object'
      return false unless protoSubset a[i], b[i]
    else
      return false unless a[i] == b[i]
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
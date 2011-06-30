should = require 'should'
inspect = require('util').inspect

exports.wrapTest = (fn, numCallbacks = 1) ->
  (beforeExit) ->
    n = 0
    fn -> n++
    beforeExit ->
      n.should.equal numCallbacks

protoSubset = (a, b) ->
  for i of a
    if typeof a[i] is 'object'
      return false unless typeof b[i] is 'object'
      return protoSubset a[i], b[i]
    else
      return false unless a[i] == b[i]
  return true

protoEql = (a, b) -> protoSubset(a, b) && protoSubset(b, a)

should.Assertion::protoEql = (val) ->
  @assert protoEql(val, @obj),
    'expected ' + @inspect + ' to prototypically equal ' + inspect(val),
    'expected ' + @inspect + ' to not prototypically equal ' + inspect(val);
  return this
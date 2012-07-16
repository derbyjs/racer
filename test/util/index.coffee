{inspect} = require 'util'
speculative = require '../../lib/util/speculative'
exports.expect = expect = require 'expect.js'

ignore = '$out': 1, '$deref': 1
ignore[speculative.identifier] = 1

# For Mocha
exports.calls = (num, fn) ->
  (done) ->
    done() if num == n = 0
    fn.call @, ->
      done() if ++n >= num

modulesToClear = [
  require.resolve '../../lib/racer'
  require.resolve '../../lib/racer.server'
  require.resolve '../../lib/util'
  require.resolve '../../lib/plugin'
  require.resolve '../../lib/Model'
  require.resolve '../../lib/Store'
]

exports.clearRequireCache = ->
  cache = require.cache
  for k in modulesToClear
    delete cache[k]
  return

exports.changeEnvTo = (type) ->
  console.assert(type == 'browser' || type == 'server')

  switch env = type
    when 'browser' then global.window = {}
    when 'server' then delete global.window

  return exports.clearRequireCache()

flatten = (a) ->
  if typeof a is 'object'
    obj = if Array.isArray a then [] else {}
  else
    return a
  if Array.isArray a
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
      if ignore[key]
        delete a[key]
        continue
      a[key] = removeReserved val
  return a
exports.specInspect = specInspect = (a) -> inspect removeReserved(flatten(a)), false, null

protoSubset = (a, b, exception) ->
  checkProp = (i) ->
    return if a[i] == b[i] || (exception && exception a, b, i)
    if typeof a[i] is 'object'
      return if typeof b[i] is 'object' && protoSubset a[i], b[i], exception
    return false
  if Array.isArray a
    return false if !Array.isArray(b)
    for v, i in a
      return false if checkProp(i) == false
  else
    for i of a
      return false if checkProp(i) == false
  return true

protoEql = (a, b) -> protoSubset(a, b) && protoSubset(b, a)

expect.Assertion::protoEql = (val) ->
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
  exception = (objA, objB, prop) -> ignore[prop] || typeof objA[prop] == 'function'
  protoSubset(a, b, exception) && protoSubset(b, a, exception)

expect.Assertion::specEql = (val) ->
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

{deepEqual} = require '../../lib/util'
expect.Assertion::deepEql = (val) ->
  @assert deepEqual(val, @obj),
    """expected \n
    #{inspect @obj, false, null} \n
    to deep equal \n
    #{inspect val, false, null}""",
    """expected \n
    #{inspect @obj, false, null} \n
    to not deep equal \n
    #{inspect val, false, null}"""
  return this

expect.Assertion::NaN = ->
  @assert @obj != @obj,
    'expected ' + inspect(@obj) + ' to be NaN',
    'expected ' + inspect(@obj) + ' to not be NaN'
  return

expect.Assertion::null = ->
  @assert `this.obj == null`,
    'expected ' + inspect(@obj) + ' to be null or undefined',
    'expected ' + inspect(@obj) + ' to not be null or undefined'
  return

sinon = require 'sinon'
expect.Assertion::calledWith = (args) ->
  @assert @obj.calledWith(args),
    'expected ' + sinon.functionName(@obj) + ' to be called with ' + inspect(args) + ', not with ' + inspect(args),
    'expected ' + sinon.functionName(@obj) + ' to not be called with ' + inspect(args)
  return

expect.Assertion::calledWithEql = (args) ->
  argsDidMatch = false
  for actualArgs in @obj.args
    if expect.eql(actualArgs, args)
      argsDidMatch = true
      break
  @assert argsDidMatch,
    'expected ' + sinon.functionName(@obj) + ' to be called with \n' + inspect(args, true, null, true) + ', not with \n' + inspect(actualArgs, true, null, true),
    'expected ' + sinon.functionName(@obj) + ' to not be called with ' + inspect(args)
  return

[['calledOnce', 'called once'], ['calledTwice', 'called twice']].forEach ([property, phrase]) ->
  expect.Assertion::[property] = ->
    @assert @obj[property],
      'expected ' + sinon.functionName(@obj) + ' to be ' + phrase,
      'expected ' + sinon.functionName(@obj) + ' to not be ' + phrase
    return

expect.Assertion::callCount = (count) ->
  @assert @obj.callCount == count,
    'expected ' + sinon.functionName(@obj) + ' to be called ' + count + ' times; actually called ' + @obj.callCount + ' times.',
    'expected ' + sinon.functionName(@obj) + ' to not be called ' + count + ' times; actually called ' + @obj.callCount + ' times.'

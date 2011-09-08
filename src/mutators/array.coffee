# - Move argsNormalizer code here
# - 
module.exports =
  push:
    normalizeArgs: normArgsPush = (path, values..., ver, options) ->
      if options is undefined
        options = {}
      if options.constructor != Object
        values.push ver
        ver = options
        options = {}
      return {path, methodArgs: values, ver, options}
    splitArgs: (args) -> [[], args]
    sliceFrom: 1

  pop:
    normalizeArgs: normArgsPop = (path, ver, options = {}) ->
      return {path, methodArgs: [], ver, options}
    splitArgs: splitArgsDefault = (args) -> [args, []]

  insertAfter:
    normalizeArgs: normArgsInsert = (path, pivotIndex, value, ver, options = {}) ->
      return {path, methodArgs: [pivotIndex, value], ver, options}
    # Extracts or sets the arguments in args that represent indexes
    indexesInArgs: indexInArgs = indexesInArgsForInsert = (args, newVals) ->
      if newVals
        args[0] = newVals[0]
        return args
      return [args[0]]
    splitArgs: splitArgsForInsert = (args) -> [[args[0]], args.slice 1]

  insertBefore:
    normalizeArgs: normArgsInsert
    indexesInArgs: indexInArgs
    splitArgs: splitArgsForInsert

  remove:
    normalizeArgs: (path, startIndex, howMany, ver, options = {}) ->
      return {path, methodArgs: [startIndex, howMany], ver, options}
    indexesInArgs: indexInArgs
    splitArgs: splitArgsDefault

  splice:
    normalizeArgs: (path, startIndex, removeCount, newMembers..., ver, options) ->
      if options is undefined
        options = {}
      if options.constructor != Object
        newMembers.push ver
        ver = options
        options = {}
      return {path, methodArgs: [startIndex, removeCount, newMembers...], ver, options}
    indexesInArgs: indexInArgs
    splitArgs: (args) -> [args[0..1], args.slice 2]

  unshift:
    normalizeArgs: normArgsPush
    splitArgs: splitArgsDefault

  shift:
    normalizeArgs: normArgsPop
    splitArgs: splitArgsDefault
    sliceFrom: 1

  move:
    compound: true
    normalizeArgs: (path, from, to, ver, options = {}) ->
      return {path, methodArgs: [from, to], ver, options}
    indexesInArgs: (args, newVals) ->
      if newVals
        args[0..1] = newVals[0..1]
        return args
      return args[0..1]
    splitArgs: splitArgsDefault

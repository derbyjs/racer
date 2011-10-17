module.exports =
  push:
    normalizeArgs: normArgsPush = (path, values..., ver, data) ->
      if typeof data is 'number'
        values.push ver
        ver = data
        data = undefined
      return {path, methodArgs: values, ver, data}
    splitArgs: (args) -> [[], args]
    sliceFrom: 1
    argsToForeignKeys: argsToFKeys = (args, path, $r) ->
      oldArgs = args.slice @sliceFrom
      newArgs = oldArgs.map (refObjToAdd) ->
        if refObjToAdd.$r is undefined
          throw new Error 'Trying to push a non-ref onto an array ref'
        if $r != refObjToAdd.$r
          throw new Error "Trying to use elements of type #{refToObj.$r} with path #{path} that is an array ref of type #{$r}"
        return refObjToAdd.$k
      args.splice @sliceFrom, oldArgs.length, newArgs...
      return args

  pop:
    normalizeArgs: normArgsPop = (path, ver, data) ->
      return {path, methodArgs: [], ver, data}
    splitArgs: splitArgsDefault = (args) -> [args, []]

  insertAfter:
    normalizeArgs: normArgsInsert = (path, pivotIndex, value, ver, data) ->
      return {path, methodArgs: [pivotIndex, value], ver, data}
    # Extracts or sets the arguments in args that represent indexes
    indexesInArgs: indexInArgs = indexesInArgsForInsert = (args, newVals) ->
      if newVals
        args[0] = newVals[0]
        return args
      return [args[0]]
    splitArgs: splitArgsForInsert = (args) -> [[args[0]], args.slice 1]
    sliceFrom: 2
    argsToForeignKeys: argsToFKeys

  insertBefore:
    normalizeArgs: normArgsInsert
    indexesInArgs: indexInArgs
    splitArgs: splitArgsForInsert
    sliceFrom: 2
    argsToForeignKeys: argsToFKeys

  remove:
    normalizeArgs: (path, startIndex, howMany, ver, data) ->
      return {path, methodArgs: [startIndex, howMany], ver, data}
    indexesInArgs: indexInArgs
    splitArgs: splitArgsDefault

  splice:
    normalizeArgs: (path, startIndex, removeCount, newMembers..., ver, data) ->
      if typeof data is 'number'
        newMembers.push ver
        ver = data
        data = undefined
      return {path, methodArgs: [startIndex, removeCount, newMembers...], ver, data}
    indexesInArgs: indexInArgs
    splitArgs: (args) -> [args[0..1], args.slice 2]
    sliceFrom: 3
    argsToForeignKeys: argsToFKeys

  unshift:
    normalizeArgs: normArgsPush
    splitArgs: splitArgsDefault
    sliceFrom: 1
    argsToForeignKeys: argsToFKeys

  shift:
    normalizeArgs: normArgsPop
    splitArgs: splitArgsDefault

  move:
    compound: true
    normalizeArgs: (path, from, to, ver, data) ->
      return {path, methodArgs: [from, to], ver, data}
    indexesInArgs: (args, newVals) ->
      if newVals
        args[0..1] = newVals[0..1]
        return args
      return args[0..1]
    splitArgs: splitArgsDefault

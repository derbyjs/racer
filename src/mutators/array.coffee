module.exports =
  push:
    normalizeArgs: normArgsPush = (path, values..., ver, data, options) ->
      if data is undefined || data.constructor != Object
        if options is undefined
          if data isnt undefined
            values.push ver
            if options isnt undefined
              ver = options
            else
              ver = data
        else
          values.push ver, data
          ver = options
        data = undefined
        options = {}
      if options is undefined
        options = {}
      return {path, methodArgs: values, ver, data, options}
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
    normalizeArgs: normArgsPop = (path, ver, data, options = {}) ->
      return {path, methodArgs: [], ver, data, options}
    splitArgs: splitArgsDefault = (args) -> [args, []]

  insertAfter:
    normalizeArgs: normArgsInsert = (path, pivotIndex, value, ver, data, options = {}) ->
      return {path, methodArgs: [pivotIndex, value], ver, data, options}
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
    normalizeArgs: (path, startIndex, howMany, ver, data, options = {}) ->
      return {path, methodArgs: [startIndex, howMany], ver, data, options}
    indexesInArgs: indexInArgs
    splitArgs: splitArgsDefault

  splice:
    # data and options are optional
    normalizeArgs: (path, startIndex, removeCount, newMembers..., ver, data, options) ->
      if data is undefined || data.constructor != Object
        if options is undefined
          # ..., 9, undefined
          # ..., undefined, undefined
          if data isnt undefined
            newMembers.push ver
            if options isnt undefined
              ver = options
            else
              ver = data
        else
          newMembers.push ver, data
          ver = options
        data = undefined
        options = {}
      if options is undefined
        options = {}
      return {path, methodArgs: [startIndex, removeCount, newMembers...], ver, data, options}
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
    normalizeArgs: (path, from, to, ver, data, options = {}) ->
      return {path, methodArgs: [from, to], ver, data, options}
    indexesInArgs: (args, newVals) ->
      if newVals
        args[0..1] = newVals[0..1]
        return args
      return args[0..1]
    splitArgs: splitArgsDefault

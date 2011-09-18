module.exports =
  push:
    normalizeArgs: normArgsPush = (path, values..., ver, obj, options) ->
      if obj is undefined || obj.constructor != Object
        if options is undefined
          if obj isnt undefined
            values.push ver
            if options isnt undefined
              ver = options
            else
              ver = obj
        else
          values.push ver, obj
          ver = options
        obj = undefined
        options = {}
      if options is undefined
        options = {}
      return {path, methodArgs: values, ver, obj, options}
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
    normalizeArgs: normArgsPop = (path, ver, obj, options = {}) ->
      return {path, methodArgs: [], ver, obj, options}
    splitArgs: splitArgsDefault = (args) -> [args, []]

  insertAfter:
    normalizeArgs: normArgsInsert = (path, pivotIndex, value, ver, obj, options = {}) ->
      return {path, methodArgs: [pivotIndex, value], ver, obj, options}
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
    normalizeArgs: (path, startIndex, howMany, ver, obj, options = {}) ->
      return {path, methodArgs: [startIndex, howMany], ver, obj, options}
    indexesInArgs: indexInArgs
    splitArgs: splitArgsDefault

  splice:
    # obj and options are optional
    normalizeArgs: (path, startIndex, removeCount, newMembers..., ver, obj, options) ->
      if obj is undefined || obj.constructor != Object
        if options is undefined
          # ..., 9, undefined
          # ..., undefined, undefined
          if obj isnt undefined
            newMembers.push ver
            if options isnt undefined
              ver = options
            else
              ver = obj
        else
          newMembers.push ver, obj
          ver = options
        obj = undefined
        options = {}
      if options is undefined
        options = {}
      return {path, methodArgs: [startIndex, removeCount, newMembers...], ver, obj, options}
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
    normalizeArgs: (path, from, to, ver, obj, options = {}) ->
      return {path, methodArgs: [from, to], ver, obj, options}
    indexesInArgs: (args, newVals) ->
      if newVals
        args[0..1] = newVals[0..1]
        return args
      return args[0..1]
    splitArgs: splitArgsDefault

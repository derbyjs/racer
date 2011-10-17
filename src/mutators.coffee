module.exports =
  basic:
    set:
      splitArgs: splitArgsDefault = (args) -> [args, []]
    del:
      splitArgs: splitArgsDefault

  array:
    push:
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
      splitArgs: splitArgsDefault = (args) -> [args, []]

    insertAfter:
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
      indexesInArgs: indexInArgs
      splitArgs: splitArgsForInsert
      sliceFrom: 2
      argsToForeignKeys: argsToFKeys

    remove:
      indexesInArgs: indexInArgs
      splitArgs: splitArgsDefault

    splice:
      indexesInArgs: indexInArgs
      splitArgs: (args) -> [args[0..1], args.slice 2]
      sliceFrom: 3
      argsToForeignKeys: argsToFKeys

    unshift:
      splitArgs: splitArgsDefault
      sliceFrom: 1
      argsToForeignKeys: argsToFKeys

    shift:
      splitArgs: splitArgsDefault

    move:
      compound: true
      indexesInArgs: (args, newVals) ->
        if newVals
          args[0..1] = newVals[0..1]
          return args
        return args[0..1]
      splitArgs: splitArgsDefault

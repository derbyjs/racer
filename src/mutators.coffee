{merge} = require './util'

mutators = module.exports =

  basic:
    set:
      splitArgs: splitArgsDefault = (args) -> [args, []]
    del:
      splitArgs: splitArgsDefault
  
  ot:
    insertOT: {}
    delOT: {}

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
      splitArgs: splitArgsDefault

    insertAfter:
      # Extracts or sets the arguments in args that represent indexes
      indexArgs: [0]
      splitArgs: splitArgsForInsert = (args) -> [[args[0]], args.slice 1]
      sliceFrom: 2
      argsToForeignKeys: argsToFKeys

    insertBefore:
      indexArgs: [0]
      splitArgs: splitArgsForInsert
      sliceFrom: 2
      argsToForeignKeys: argsToFKeys

    remove:
      indexArgs: [0]
      splitArgs: splitArgsDefault

    splice:
      indexArgs: [0]
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
      indexArgs: [0, 1]
      splitArgs: splitArgsDefault

all = {}
for name, category of mutators
  all = merge all, category
mutators.all = all

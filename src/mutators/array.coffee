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
    sliceFrom: 1

  pop:
    normalizeArgs: normArgsPop = (path, ver, options = {}) ->
      return {path, methodArgs: [], ver, options}

  insertAfter:
    normalizeArgs: normArgsInsert = (path, pivotIndex, value, ver, options = {}) ->
      return {path, methodArgs: [pivotIndex, value], ver, options}

  insertBefore:
    normalizeArgs: normArgsInsert

  remove:
    normalizeArgs: (path, startIndex, howMany, ver, options = {}) ->
      return {path, methodArgs: [startIndex, howMany], ver, options}

  splice:
    normalizeArgs: (path, startIndex, removeCount, newMembers..., ver, options) ->
      if options is undefined
        options = {}
      if options.constructor != Object
        newMembers.push ver
        ver = options
        options = {}
      return {path, methodArgs: [startIndex, removeCount, newMembers...], ver, options}

  unshift:
    normalizeArgs: normArgsPush

  shift:
    normalizeArgs: normArgsPop
    sliceFrom: 1

  move:
    compound: true

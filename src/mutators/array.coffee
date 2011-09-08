# - Move argsNormalizer code here
# - 
module.exports =
  push:
    normalizeArgs: (path, values..., ver, options) ->
      if options is undefined
        options = {}
      if options.constructor != Object
        values.push ver
        ver = options
        options = {}
      return {path, methodArgs: values, ver, options}
    sliceFrom: 1

  pop:
    normalizeArgs: (path, ver, options = {}) ->
      return {path, methodArgs: [], ver, options}

  insertAfter:
    normalizeArgs: (path, afterIndex, value, ver, options = {}) ->
      return {path, methodArgs: [afterIndex, value], ver, options}

  insertBefore:
    normalizeArgs: (path, beforeIndex, value, ver, options = {}) ->
      return {path, methodArgs: [beforeIndex, value], ver, options}

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
    normalizeArgs: (path, newMembers..., ver, options) ->
      if options is undefined
        options = {}
      if options.constructor != Object
        newMembers.push ver
        ver = options
        options = {}
      return {path, methodArgs: newMembers, ver, options}

  shift:
    normalizeArgs: (path, ver, options = {}) ->
      return {path, methodArgs: [], ver, options}
    sliceFrom: 1

  move:
    compound: true

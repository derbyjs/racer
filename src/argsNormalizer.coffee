argsNormalizer = module.exports =
  adapter:
    push: (_arguments) ->
      [path, values..., ver, options] = Array.prototype.slice.call _arguments
      options = {} if options is undefined
      if options.constructor != Object
        values.push ver
        ver = options
        options = {}
      return [path, values, ver, options]
    
    splice: (_arguments) ->
      [path, startIndex, removeCount, newMembers..., ver, options] = Array.prototype.slice.call _arguments
      options = {} if options is undefined
      if options.constructor != Object
        newMembers.push ver
        ver = options
        options = {}
      return [path, startIndex, removeCount, newMembers, ver, options]

argsNormalizer.adapter.unshift = argsNormalizer.adapter.push

# Schema-Driven Properties

    props = exports

    props.isPlainObject = (val) ->
        typeof val is "object" and val isnt null and
            Object.getPrototypeOf(val) is Object.prototype

    props.assign = (dest={}) ->
        for src, i in arguments when i and src
            dest[k] = src[k] for k in Object.keys(src)
        return dest

    props.compose = (rest..., f) ->
        f = (f.converter ? f)
        return f unless rest.length
        g = props.compose(rest...)
        (v) -> f.call(this, g.call(this, v))

    props.type = (f) ->
        factory = ->
            [val, doc, meta, rest...] = args(arguments, [
             args.any, args.string(""), args.object({})
            ])
            return props.spec(val, doc, meta, f, rest...)
        factory.converter = props.compose(f)
        return factory

    props.check = (message, filter) -> props.type (val) ->
        throw new TypeError @name+" "+message unless filter?(val)
        return val

    ['number', 'string', 'function', 'boolean'].forEach (t) ->
        props[t] = props.check "must be a "+t, (v) -> typeof v is t







    args = require 'normalize-arguments'

    class props.spec
        identity = (v) -> v
        constructor: () ->
            return new spec(arguments...) unless this instanceof spec
            [@value, @doc, meta, rest...] = args(arguments, [
             args.any, args.string(""), args.object({})
            ])
            @meta = props.assign {}, meta
            @convert = if rest.length then props.compose(rest...) else identity































# Schema-Driven Properties

    module.exports = props = (cls, schema) ->
        [cls, schema] = args(arguments, [args.fn(), args.object({})])
        cls ?= class extends props.Base
        props.defineProperties(cls::, schema, undefined, cls::)
        cls

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







    props.defineProperties = (ob, schema, factory, proto) ->
        if proto
            Object.defineProperties(proto,
                __defaults__: value: props.assign {}, proto.__defaults__
                __specs__: value: props.assign {}, proto.__specs__
                __names__: value: []
            ) unless proto.hasOwnProperty('__defaults__')
            defaults = proto.__defaults__
            specs = proto.__specs__
            names = proto.__names__

        factory ?= ob.__prop_desc__ ? props.Base::__prop_desc__

        Object.keys(schema).forEach (name) ->
            spec = Object.create(schema[name], name: value: name, enumerable: yes)
            if proto
                defaults[name] = spec.value
                specs[name] = spec
            Object.defineProperty(ob, name, factory(name, spec))

        names?.splice(0, names.length, Object.keys(defaults)...)

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

    class props.Base
        __prop_desc__: (name, spec) ->
            get: -> @__props[name]
            set: (v) -> @__props[name] = spec.convert(v)
            configurable: yes
            enumerable: yes


# Schema-Driven Properties

    args = require 'normalize-arguments'

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
        throw new TypeError("not a function") unless typeof f is 'function'
        f = (f.converter ? f)
        return f unless rest.length
        g = props.compose(rest...)
        (v) -> f.call(this, g.call(this, v))

    props.type = (f) ->
        factory = ->
            [val, doc, meta, rest...] = args(arguments, [
             args.any, args.string(""), args.object({})
            ])
            return new props.spec(val, doc, meta, f, rest...)
        factory.converter = props.compose(f)
        factory.and = (g) -> props.type(f, g)
        factory.or = (g) ->
            g = props.compose(g)
            props.type (v) -> try f.call(this, v) catch e then g.call(this, v)
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

    class props.spec
        identity = (v) -> v
        constructor: () ->
            return new spec(arguments...) unless this instanceof spec
            [@value, @doc, meta, rest...] = args(arguments, [
             args.any, args.string(""), args.object({})
            ])
            @meta = props.assign {}, meta
            @required = @meta.required ? no
            @convert = if rest.length then props.compose(rest...) else identity



    class props.Base

        __prop_desc__: (name, spec) ->
            get: -> @__props[name]
            set: (v) -> @__props[name] = spec.convert(v)
            configurable: yes
            enumerable: yes

        __setup_storage__: ->
            Object.defineProperty(
                this, '__props', value: props.assign {}, @__defaults__
            )

        __validate_initializer__: (arg) ->
            if props.isPlainObject(arg)
                (@__validate_names__ ? Base::__validate_names__).call(this, arg)
            else throw new TypeError(
                "Arguments must be plain Objects or schema-compatible"
            ) unless arg instanceof @constructor

        has = Object::hasOwnProperty

        __validate_names__: (arg) ->
            schema = @__specs__
            for k in Object.keys(arg) when not has.call(schema, k)
                throw new TypeError "Unknown property: "+k

        __initialize_from__: ->
            for name in @__names__
                spec = @__specs__[name]
                for arg in arguments
                    if got = has.call(arg, name)
                        @[name] = arg[name]; break
                unless got
                    if spec.required then throw new TypeError(
                        "Missing required property: "+name
                    ) else @[name] = @__defaults__[name]





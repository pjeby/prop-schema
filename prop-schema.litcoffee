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

    props.type = ->
        factory = (val, rest...)->
            [doc, meta, rest...] = args(rest, [args.string(""), args.object({})])
            return new props.spec(val, doc, meta, factory.converter, rest...)
        factory.converter = f = props.compose(arguments...)
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

    props.empty = props.check("must be null or undefined", (v) -> not v?)

    props.object = props.type (val) ->
        return props.assign({}, val) if props.isPlainObject(val)
        throw new TypeError "#{@name} must be a plain Object"

    props.integer = props.number.and props.check "must be an integer",
        (v) -> v == ~~v

    props.positive = props.number.and props.check "must be > 0", (v) -> v > 0

    props.nonNegative = props.number.and props.check "must be >= 0",
        (v) -> v >= 0

    props.defineProperties = (ob, specs, factory, proto) ->
        if proto
            unless proto.hasOwnProperty('__schema__')
                schema = Object.create(proto.__schema__ ? {})
                schema.specs = props.assign {}, schema.specs
                schema.defaults = props.assign {}, schema.defaults
                Object.defineProperty(proto, '__schema__', value: schema)
            schema = proto.__schema__

        factory ?= ob.__prop_desc__ ? props.Base::__prop_desc__
        Object.keys(specs).forEach (name) ->
            spec = Object.create(specs[name], name: value: name, enumerable: yes)
            if schema
                schema.defaults[name] = spec.value
                schema.specs[name] = spec
            Object.defineProperty(ob, name, factory(name, spec))

        schema?.names = Object.keys(schema.specs)






    class props.spec
        identity = (v) -> v

        constructor: (val, rest...) ->
            return new spec(arguments...) unless this instanceof spec
            @value = val
            [@doc, meta, rest...] = args(rest, [args.string(""), args.object()])
            @meta = props.assign {}, meta
            @required = @meta.required ? no
            @convert = if rest.length then props.compose(rest...) else identity


    class props.Base

        getter = (name) ->
            -> (@[name] ? Base::[name]).apply(this, arguments)

        defaultThis = do -> this

        setupStorage = getter('__setup_storage__')
        validateNames = getter('__validate_names__')
        validateInitiaizer = getter('__validate_initializer__')
        initFrom = getter('__initialize_from__')

        constructor: ->
            throw new TypeError("Must create with new") if this is defaultThis
            setupStorage.call(this)
            validateInitiaizer.call(this, arg) for arg in arguments
            initFrom.apply(this, arguments)

        __prop_desc__: (name, spec) ->
            get: -> @__props[name]
            set: (v) -> @__props[name] = spec.convert(v)
            configurable: yes
            enumerable: yes

        __setup_storage__: ->
            Object.defineProperty(
                this, '__props', value: props.assign {}, @__schema__.defaults
            )

        __validate_initializer__: (arg) ->
            if props.isPlainObject(arg)
                validateNames.call(this, arg)
            else throw new TypeError(
                "Arguments must be plain Objects or schema-compatible"
            ) unless arg instanceof @constructor

        has = Object::hasOwnProperty

        __validate_names__: (arg) ->
            schema = @__schema__.specs
            for k in Object.keys(arg) when not has.call(schema, k)
                throw new TypeError "Unknown property: "+k

        __initialize_from__: ->
            schema = @__schema__
            for name in schema.names
                spec = schema.specs[name]
                for arg in arguments
                    if got = name of arg # XXX has.call(arg, name)
                        @[name] = arg[name]; break
                unless got
                    if spec.required then throw new TypeError(
                        "Missing required property: "+name
                    ) else @[name] = schema.defaults[name]

















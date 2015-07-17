# Schema-Driven Properties

    args = require 'normalize-arguments'
    has = Object::hasOwnProperty

    module.exports = props =  ->
        [cls,       specs,       extensions] = args(arguments, [
         args.fn(), args.object, args.object()
        ])
        cls ?= class extends props.Base
        props.defineSchema(cls::, specs, extensions)
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

    createSchema = (base=defaultSchema) ->
        schema = Object.create(base)
        schema.specs = props.assign {}, schema.specs
        schema.defaults = props.assign {}, schema.defaults
        return schema

    props.defineSchema = (proto, specs, extensions) ->
        unless proto.hasOwnProperty('__schema__')
            Object.defineProperty(
                proto, '__schema__', value: createSchema(proto.__schema__)
            )
        schema = props.assign(proto.__schema__, extensions).__update(specs)
        schema.defineProperties(proto)
        return schema






    defaultSchema =

        defineProperties: (ob, factory) ->
            factory ?= @descriptorFor
            for name in @names
                Object.defineProperty(ob, name, factory.call(this, name, @specs[name]))
            return ob

        descriptorFor: (name, spec) ->
            get: -> @__props[name]
            set: (v) -> @__props[name] = spec.convert(v)
            configurable: yes
            enumerable: yes

        setupStorage: (ob) -> Object.defineProperty(
            ob, '__props', value: props.assign {}, @defaults
        )

        toInitializer: (ob={}) ->
            if not (other = ob?.__schema__)?
                return @validateNames(ob) if props.isPlainObject(ob)
            specs = @specs
            data = {}
            names = for n in other?.names ? [] when has.call(specs,n)
                data[n] = ob[n]
                n
            return data if names.length
            throw new TypeError(
                "Arguments must be plain Objects or schema-compatible"
            )

        propertiesFrom: ->
            sources = (@toInitializer(arg) for arg in arguments).reverse()
            input = props.assign {}, sources...
            output = props.assign {}, @defaults, input
            for name in @names when not has.call(input, name)
                if @specs[name].required then throw new TypeError(
                    "Missing required property: "+name
                )
            return output

        validateNames: (ob) ->
            specs = @specs
            for k in Object.keys(ob) when not has.call(specs, k)
                throw new TypeError "Unknown property: "+k
            return ob

    Object.defineProperties defaultSchema, __update: value: (specs) ->
        for name in Object.keys(specs)
            @specs[name] = spec = Object.create(
                specs[name], name: value: name, enumerable: yes
            )
            @defaults[name] = spec.value
        @names = Object.keys(@specs)
        return this


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
        defaultThis = do -> this

        constructor: ->
            if not this? or this is defaultThis
                throw new TypeError("Must create with new")
            @__schema__.setupStorage(this)
            props.assign(this, @__schema__.propertiesFrom(arguments...))






{expect, should} = chai = require 'chai'
should = should()
chai.use require 'sinon-chai'

{spy} = sinon = require 'sinon'

spy.named = (name, args...) ->
    s = if this is spy then spy(args...) else this
    s.displayName = name
    return s

{
    Base, spec, assign, isPlainObject, type, compose, check, defineProperties
} = props = require './'

util = require 'util'

items = (val) -> Object.keys(val).map (k) -> [k, val[k]]

withSpy = (ob, name, fn) ->
    s = spy.named name, ob, name
    try fn(s) finally s.restore()



















describe "Type and Function Composition", ->

    describe "Compositional Algebra", ->

        it "compose(..., non-function) -> TypeError", ->
            expect(compose).to.throw TypeError, /not a function/

        it "compose(fn) == fn", ->
            expect(compose(f = ->)).to.equal f

        it "compose(type(fn)) == fn", ->
            expect(compose(type(f = ->))).to.equal f

        it "type(fn).converter == fn", ->
            expect(type(f = ->).converter).to.equal f

        it "type(type(fn)).converter == fn", ->
            expect(type(type(f = ->)).converter).to.equal f

    describe "compose(f, g)", ->
        f = (x) -> x + 1
        g = (x) -> x * 2
        h = (x) -> x - 3

        it "(v) -> g(f(v))", ->
            expect(compose(f,g)(3)).to.equal 8

        it "calls f and g with same context", ->
            f_ = spy.named 'f', f; g_ = spy.named 'g', g
            compose(f_, g_).call(t = {}, 42)
            f_.should.have.been.calledOn(t)
            g_.should.have.been.calledOn(t)

        it "unwraps types", ->
            expect(compose(type(f),type(g))(3)).to.equal 8

        it "handles many arguments", ->
            expect(compose(f,g,h)(3)).to.equal 5



    describe "type(a).and(b)", ->

        it "returns type(a, b)", -> withSpy props, 'type', (t) ->
            ret = type(a=->).and(b=->)
            t.should.have.been.calledOnce
            t.should.have.been.calledWithExactly(a, b)
            t.should.have.returned(ret)

    describe "type(a).or(b)(val)", ->

        it "calls a[.converter](val) first", ->
            a = spy.named 'a', -> 42
            b = spy.named 'b', (x) -> x * 2
            expect(type(a).or(b).converter.call(ob={}, 21)).to.equal 42
            a.should.have.been.calledOnce
            a.should.have.been.calledOn(ob)
            b.should.not.have.been.called

        it "calls b[.converter](val) if a(val) throws", ->
            a = spy.named 'a', -> throw new Error
            b = spy.named 'b', (x) -> x * 2
            expect(type(a).or(type b).converter.call(ob={}, 12)).to.equal 24
            a.should.have.been.calledOnce
            a.should.have.been.calledOn(ob)
            b.should.have.been.calledOnce
            b.should.have.been.calledOn(ob)















    describe "type(fn)(...,cvt..) -> spec(...,fn,cvt...)", ->

        it "with all arguments", ->
            s = type(f=->)(17, "blah", m={fiz:"buz"})
            expect(s).to.eql {value: 17, doc: "blah", meta:m, convert: f}

        it "with just a value", ->
            s = type(f=->)(42)
            expect(s.value).to.equal 42
            expect(s.convert).to.equal f

        it "with converter functions", ->
            t = type(f=->)
            withSpy props, 'compose', (c) ->
                t(42, g=->)
                c.should.have.been.calledWithExactly(f, g)

        it "with metadata only", ->
            s = type(f=->)(99, {x:1})
            expect(s.value).to.equal 99
            expect(s.meta).to.eql {x: 1}
            expect(s.convert).to.equal f



















    it "check(message).converter() always throws", ->
        expect(-> check("test message").converter.call(name:"foo"))
        .to.throw(TypeError, /foo test message/)

    describe "check(filter, message).converter(val)", ->

        cvt = check("must be plain", isPlainObject).converter

        it "returns val if filter(val)", ->
            expect(cvt.call(name:"foo", o={})).to.equal o

        it "throws unless filter(val)", ->
            expect(-> cvt.call(name:"bar", 99))
            .to.throw(TypeError, /bar must be plain/)


describe "Properrty Specifiers", ->

    describe "spec(value, doc?, meta?, converter...)", ->

        it ".value", ->
            expect(spec(99).value).to.equal 99

        it ".doc", ->
            expect(spec(42,"doc").doc).to.equal "doc"

        it ".meta (copy)", ->
            s = spec(42,"doc",m={})
            expect(s.meta).to.eql m
            expect(s.meta).to.not.equal m
            expect(spec(42, m).meta).to.eql m

        it ".convert() <- compose(converter...)", ->
            expect(spec(42,f=->).convert).to.equal f
            expect(spec(42,{},type(f)).convert).to.equal f

        it ".required == meta.required"




describe "Basic types", ->
    for own k, v of defaults = {string:"x", number:42, boolean:yes, function:->}
        do (k, v, t = props[k]) ->
            describe "."+k, ->
                it "accepts #{k}", ->
                    expect(t.converter(v)).to.equal v
                for own kk, vv of defaults when kk isnt k then do (kk, vv) ->
                    it "rejects #{kk}", ->
                        expect(-> t.converter.call(name: kk, vv))
                        .to.throw(TypeError, ///#{kk}\ must\ be\ a\ #{k}///)

describe "Composed types", ->

    describe ".empty", ->
        it "accepts null"
        it "accepts undefined"
        it "rejects anything else"

    describe ".object", ->
        it "rejects non-plain objects"
        it "clones its values"

    describe ".integer", ->
        it "rejects non-numbers and non-integer floating point"

    describe ".positive", ->
        it "rejects non-numbers"
        it "rejects numbers less than 1"

    describe "nonNegative", ->
        it "rejects non-numbers"
        it "rejects numbers less than 0"









describe "props(cls, schema)", ->

    it "-> defineProperties(cls.prototype, schema, undefined, cls.prototype)", ->
        withSpy props, 'defineProperties', (dp) ->
            props(class cls, schema={})
            dp.should.have.been.calledOnce
            dp.should.have.been.calledWithExactly(
                cls::, schema, undefined, cls::
            )


describe "props(schema)", ->

    it "returns a new subclass of props.Base", ->
        cls = props(schema={})
        expect(Object.getPrototypeOf(cls::)).to.equal Base::

    it "-> defineProperties(cls.prototype, schema, undefined, cls.prototype)", ->
        withSpy props, 'defineProperties', (dp) ->
            cls = props(schema={})
            dp.should.have.been.calledOnce
            dp.should.have.been.calledWithExactly(
                cls::, schema, undefined, cls::
            )

















describe "Instance Initialization", ->

    describe "Base.call()", ->
        it "throws if called without explicit `this`"
        describe "invokes __setup_storage__ before validation", ->
            it "using the current implementation"
            it "using the default implementation"

        describe "validates all its arguments w/__validate_intiializer__", ->
            it "using the current implementation"
            it "using the default implementation"

        describe "calls __initialize_from__ last", ->
            it "using the current implementation"
            it "using the default implementation"

    beforeEach -> @ob = Object.create(Base::)

    describe "__setup_storage__", ->

        it "sets .__props to a copy of .__defaults__", ->
            assign({}, @ob).should.eql {}
            expect(@ob.__props).to.not.exist
            @ob.__defaults__ = dflts = {x: 42}
            @ob.__setup_storage__()
            expect(@ob.__props).to.eql dflts
            expect(@ob.__props).to.not.equal dflts

        it "makes .__props non-enumerable", ->
            @ob.__setup_storage__()
            Object.keys(@ob).should.eql []










    describe "__validate_initializer__", ->

        it "accepts plain objects", -> withSpy props, 'isPlainObject', (ipo) =>
            @ob.__validate_initializer__(arg = {})
            ipo.should.have.been.calledOnce
            ipo.should.have.been.calledWithExactly(arg)

        it "accepts instances of the current class", ->
            @ob.constructor = class cls extends Base then constructor: ->
            @ob.__validate_initializer__(new cls)

        it "rejects unrelated classes", ->
            (=> @ob.__validate_initializer__(new class))
            .should.throw TypeError, /must be plain Objects or schema-compatible/

        describe "invokes __validate_names__ on plain objects", ->

            it "using the current implementation", ->

                withSpy @ob, '__validate_names__', (vn) =>
                    @ob.__validate_initializer__(@ob)
                    vn.should.not.have.been.called

                withSpy @ob, '__validate_names__', (vn) =>
                    @ob.__validate_initializer__(arg = {})
                    vn.should.have.been.calledOnce
                    vn.should.have.been.calledOn(@ob)
                    vn.should.have.been.calledWithExactly(arg)

            it "using the default implementation", ->
                @ob = new class
                withSpy Base::, '__validate_names__', (vn) =>
                    Base::__validate_initializer__.call(@ob, @ob)
                    vn.should.not.have.been.called

                withSpy Base::, '__validate_names__', (vn) =>
                    Base::.__validate_initializer__.call(@ob, arg = {})
                    vn.should.have.been.calledOnce
                    vn.should.have.been.calledOn(@ob)
                    vn.should.have.been.calledWithExactly(arg)

    describe "__validate_names__", ->

        it "rejects objects with enumerable-own properties not in schema", ->
            defineProperties @ob, x: spec(1), null, @ob
            @ob.__validate_names__(x:2)
            (=> @ob.__validate_names__(constructor: 99))
            .should.throw TypeError, "Unknown property: constructor"

    describe "__initialize_from__", ->
        it "accepts multiple sources"
        it "uses the first source with a property"
        it "initializes all properties, even if not specified"
        it "throws when a required property is missing"




























describe "Utilities", ->

    describe "assign(dest, sources...) copies properties", ->

        it "to the destination", ->
            expect(assign(x={a:1}, b:3)).to.eql {a:1, b:3}

        it "returning the destination", ->
            expect(assign(x={})).to.equal(x)

        it "with left-most precedence", ->
            expect(assign(x={a:1}, b:2, {a:3})).to.eql {a:3, b:2}

        it "ignoring null/undefineds", ->
            expect(assign(x={a:1}, b:2, undefined, {a:3})).to.eql {a:3, b:2}

        it "maintains iteration order", ->
            expect(items(assign({}, {b: 3, a:1, c:1}, c:5)))
            .to.eql [['b', 3], ['a', 1], ['c', 5]]


    describe "isPlainObject()", ->

        it "accepts object literals", ->
            expect(isPlainObject({})).to.be.true

        it "rejects non-objects", ->
            for k in [1, "two", null, undefined, yes, ->]
                expect(isPlainObject(k))
                .to.equal(no, "#{typeof k}: #{util.inspect(k)}")

        it "rejects class instances", ->
            expect(isPlainObject(new class X)).to.be.false








    describe "defineProperties(ob, schema)", ->

        schema = x: spec(42, parseInt)

        describe "creates descriptors that", ->

            beforeEach -> defineProperties(@ob={}, schema)

            it "are enumerable and configurable", ->
                desc = Object.getOwnPropertyDescriptor(@ob, 'x')
                expect(desc.enumerable).to.equal(true, 'enumerable')
                expect(desc.configurable).to.equal(true, 'configurable')

            it "delegate to .__props", ->
                @ob.__props = {x: 99}
                expect(@ob.x).to.equal 99

            it "set the value from spec.convert(value)", ->
                @ob.__props = {}
                @ob.x = "55 mph"
                expect(@ob.__props).to.eql {x:55}

        it "uses props.Base::__prop_desc__ as a default factory", ->
            withSpy Base.prototype, '__prop_desc__', (s) ->
                defineProperties(ob = {}, schema)
                s.should.have.been.calledOnce
                s.should.have.been.calledWith('x')

        it "uses ob.__prop_desc__ as a factory if available", ->
            ob = __prop_desc__: s = spy (name, ps) -> value: ps
            defineProperties(ob, schema)
            s.should.have.been.calledOnce
            s.should.have.been.calledWith('x')








    describe "defineProperties(ob, schema, factory)", ->

        describe "invokes factory(name, spec) for each schema item", ->

            beforeEach ->
                schema = b: spec("b"), c: spec("c"), a: spec("a")
                @results = []
                my = this
                defineProperties @ob={}, schema, @factory = (name, ps) ->
                    my.results.push name
                    value: ps

            it "in schema order", ->
                expect(@results).to.eql ['b', 'c', 'a']

            it "with a named spec", ->
                ['b', 'c', 'a'].forEach (name) =>
                    expect(@ob[name].name).to.equal name

            it "defining the named property", ->
                ['b', 'c', 'a'].forEach (name) =>
                    expect(@ob[name].value).to.equal name



















    describe "defineProperties(ob, schema, factory, proto)", ->

        expectNamedSpec = (spec, name, base, message) ->
            expect(spec.name).to.equal(name, message+": bad name")
            expect(Object.getPrototypeOf(spec)).to.equal(base, message+": bad prototype")
            expect(Object.getOwnPropertyNames(spec))
            .to.eql(['name'], message+": bad keys")

        schema1 = b: spec("b"), c: spec("c"), a: spec("a")
        schema2 = a: spec("A"), d: spec("D"), b: spec ("B")

        beforeEach ->
            defineProperties(@ob={}, schema1, null, @proto={})

        describe "initially configures", ->
            it "__specs__", ->
                specs = @proto.__specs__
                expect(Object.keys(specs)).to.eql ['b', 'c', 'a']
                ['b', 'c', 'a'].forEach (name) =>
                    expectNamedSpec(specs[name], name, schema1[name], name)

            it "__defaults__", ->
                expect(Object.getOwnPropertyDescriptor(@proto, '__defaults__'))
                .to.eql(
                    enumerable: no, configurable: no, writable: no,
                    value: {b:'b', c: 'c', a:'a'}
                )
                expect(items(@proto.__defaults__))
                .to.eql [['b', 'b'], ['c', 'c'], ['a', 'a']]

            it "__names__", ->
                expect(Object.getOwnPropertyDescriptor(@proto, '__names__'))
                .to.eql(
                    enumerable: no, configurable: no, writable: no,
                    value: ['b','c','a']
                )





        describe "updates", ->

            beforeEach -> defineProperties(@ob, schema2, null, @proto)

            it "__specs__", ->
                specs = @proto.__specs__
                expect(Object.keys(specs)).to.eql ['b', 'c', 'a', 'd']

                ['b', 'd', 'a'].forEach (name) =>
                    expectNamedSpec(specs[name], name, schema2[name], name)

                expectNamedSpec(specs.c, 'c', schema1.c, 'c')

            it "__defaults__", ->
                expect(items(@proto.__defaults__))
                .to.eql [['b', 'B'], ['c', 'c'], ['a', 'A'], ['d', 'D']]

            it "__names__", ->
                expect(@proto.__names__).to.eql ['b', 'c', 'a', 'd']

        describe "inherits", ->

            beforeEach ->
                @proto2=Object.create(@proto)
                defineProperties(@ob, schema2, null, @proto2)

            it "__specs__", ->
                specs = @proto2.__specs__
                expect(Object.keys(specs)).to.eql ['b', 'c', 'a', 'd']

                ['b', 'd', 'a'].forEach (name) =>
                    expectNamedSpec(specs[name], name, schema2[name], name)

                expectNamedSpec(specs.c, 'c', schema1.c, 'c')

                specs = @proto.__specs__
                expect(Object.keys(specs)).to.eql ['b', 'c', 'a']
                ['b', 'c', 'a'].forEach (name) =>
                    expectNamedSpec(specs[name], name, schema1[name], name+"(base)")


            it "__defaults__", ->
                expect(items(@proto.__defaults__))
                .to.eql [['b', 'b'], ['c', 'c'], ['a', 'a']]
                expect(items(@proto2.__defaults__))
                .to.eql [['b', 'B'], ['c', 'c'], ['a', 'A'], ['d', 'D']]

            it "__names__", ->
                expect(@proto.__names__).to.eql ['b', 'c', 'a']
                expect(@proto2.__names__).to.eql ['b', 'c', 'a', 'd']

































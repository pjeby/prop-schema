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

checkTE = (fn, msg) -> fn.should.throw TypeError, msg

{Environment} = require 'mock-globals'















describe "Examples", ->

    before ->

        @env = new Environment({props})
        @run = (code, output) ->
            res = @env.run(code)
            @env.getOutput().should.equal output if output?
            return res

    afterEach -> @env.getOutput()   # clear state

    describe "Report class", ->
        before -> @run """
        Report = props({
          sql: props.string(null, "sql to run", {required: true}),
          cols: props.integer.and(props.positive)(80, "Report width in columns"),
          title: props.string("", "Report title", function(value) {
            if (value.length < 4)
              throw new TypeError(this.name + " must be at least 4 chars");
            else return value;
          }),
        });
        schema = Report.prototype.__schema__;
        undefined"""

        it "Should have schema info", ->
            @run("schema.names", "[ 'sql', 'cols', 'title' ]\n")
            @run("schema.defaults",
               "{ sql: null, cols: 80, title: '' }\n")
            @run("schema.specs['title'].doc", "'Report title'\n")
            @run("schema.specs['sql'].meta", "{ required: true }\n")

        it "Should expect required properties", ->
            checkTE (=> @run "new Report()"), "Missing required property: sql"

        it "Should require Object arguments", ->
            checkTE (=> @run "new Report('foo')"),
                "Arguments must be plain Objects or schema-compatible"


        it "Should reject invalid property names", ->
            checkTE (=> @run 'new Report({sequel:"z"})'),
                "Unknown property: sequel"

        it "Even default values are subject to validation", ->
            checkTE (=> @run 'new Report({sql:"X"})'),
                "title must be at least 4 chars"

        it "Each combined type supplies its own error messages", ->
            checkTE (=> @run('new Report({sql: "Z", cols: 0.1})')),
                "cols must be an integer"
            checkTE (=> @run('new Report({sql: "Z", cols: 0})')),
                "cols must be > 0"
        it "Property enumeration follows schema order, not argument order", ->
            @run('r1 = new Report({title: "Hello", sql:"X"}); r1.__props',
                "{ sql: 'X', cols: 80, title: 'Hello' }\n")

        it "Multiple arguments can be passed to combine properties", ->
            @run('r2 = new Report({cols:20}, r1); r2.__props',
                "{ sql: 'X', cols: 20, title: 'Hello' }\n")

        it "Earlier arguments' values override later ones", ->
            @run("""var r3 = new Report(
                    {title: "Yo!!"}, {cols:5}, r2, {sql: "WHAT?"}
                  ); r3.__props""", "{ sql: 'X', cols: 5, title: 'Yo!!' }\n")

        it "JSON works when props are defined", ->
            @run("props.defineProperties(r1, r1.__schema__.specs); JSON.stringify(r1)"
            ).should.equal '{"sql":"X","cols":80,"title":"Hello"}'












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

        it "returns type(a, b)", ->
            withSpy props, 'type', (t) -> withSpy props, 'compose', (c) ->
                ret = type(a=->).and(b=->)
                t.should.have.been.calledOnce
                t.should.have.been.calledWithExactly(a, b)
                t.should.have.returned(ret)
                c.should.have.returned(ret.converter)
                c.should.have.been.calledWithExactly(a, b)


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
            expect(s).to.eql {
                value: 17, doc: "blah", meta:m, convert: f, required: no
            }

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

        it ".required == meta.required", ->
            expect(spec(0, required: yes).required).to.be.true
            expect(spec(0, required: no).required).to.be.false
            expect(spec(0).required).to.be.false

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

    beforeEach ->
        @shouldFail = (val, msg) -> checkTE (=> @ps.convert(val)), msg
        @shouldOK = (val, out) -> expect(@ps.convert(val)).to.equal(out)

    describe ".empty", ->
        beforeEach -> @ps = props.empty(21); @ps.name = 'x'
        it "accepts null",      -> @shouldOK null, null
        it "accepts undefined", -> @shouldOK undefined, undefined
        it "rejects anything else", ->
            @shouldFail 42, "x must be null or undefined"

    describe ".object", ->
        beforeEach -> @ps = props.object(null); @ps.name = 'x'

        it "rejects non-plain objects", ->
            @shouldFail 42, "x must be a plain Object"

        it "clones its values", ->
            res = @ps.convert(ob={x:1})
            res.should.not.equal(ob); res.should.eql ob

    describe ".integer", ->
        it "rejects non-numbers and non-integer floating point", ->
            ps = props.integer(null); ps.name = 'x'
            checkTE (-> ps.convert("42")), "x must be a number"
            checkTE (-> ps.convert(0.1)), "x must be an integer"

    describe ".positive", ->
        beforeEach -> @ps = props.positive(null); @ps.name = 'x'
        it "rejects non-numbers", -> @shouldFail "42", "x must be a number"
        it "rejects numbers <= 0", -> @shouldFail 0, "x must be > 0"
        it "accepts numbers > 0", -> @shouldOK(1, 1)

    describe "nonNegative", ->
        beforeEach -> @ps = props.nonNegative(null); @ps.name = 'x'
        it "rejects non-numbers", -> @shouldFail "42", "x must be a number"
        it "rejects numbers < 0", -> @shouldFail -1, "x must be >= 0"
        it "accepts numbers >= 0", -> @shouldOK(1, 1)


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

    beforeEach ->
        @ob = Object.create(Base::)
        @ob2 = {}
        defineProperties(@ob, {}, null, @ob)

    describe "Base.call()", ->

        beforeEach ->
            defineProperties @ob, y: spec(42), z: spec(99), null, @ob
            defineProperties @ob2, y: spec(42), z: spec(99), null, @ob2

        it "throws if called without explicit `this`", ->
            (-> Base() ).should.throw TypeError

        describe "invokes __setup_storage__ before validation", ->
            checkStorage = (ob, impl=ob) ->
                withSpy impl, '__setup_storage__', (ss) =>
                    withSpy impl, '__initialize_from__', (init) =>
                        Base.call(ob)
                        ss.should.have.been.calledOnce
                        ss.should.have.been.calledOn(ob)
                        ss.should.have.been.calledBefore(init)

            it "using the current implementation", ->
                checkStorage(@ob)

            it "using the default implementation", ->
                checkStorage(@ob2, Base::)











        describe "validates all its arguments w/__validate_intiializer__", ->

            checkVI = (ob, impl=ob) ->
                withSpy impl, '__setup_storage__', (ss) =>
                    withSpy impl, '__validate_initializer__', (v) =>
                        Base.call(ob, arg1={}, arg2={})
                        v.should.have.been.calledTwice
                        v.should.have.been.always.calledOn(ob)
                        v.should.have.been.calledWithExactly(arg1)
                        v.should.have.been.calledWithExactly(arg2)

            it "using the current implementation", -> checkVI(@ob)
            it "using the default implementation", -> checkVI(@ob2, Base::)


        describe "calls __initialize_from__ last", ->

            checkInit= (ob, impl=ob) ->
                withSpy impl, '__setup_storage__', (ss) =>
                    withSpy impl, '__validate_initializer__', (v) =>
                        withSpy impl, '__initialize_from__', (init) =>
                            Base.call(ob, arg={})
                            init.should.have.been.calledOnce
                            init.should.have.been.calledOn(ob)
                            init.should.have.been.calledWithExactly(arg)
                            init.should.have.been.calledAfter(ss)
                            init.should.have.been.calledAfter(v)

            it "using the current implementation", -> checkInit(@ob)
            it "using the default implementation", -> checkInit(@ob2, Base::)











    describe "__setup_storage__", ->

        it "sets .__props to a copy of .__schema__.defaults", ->
            assign({}, @ob).should.eql {}
            expect(@ob.__props).to.not.exist
            @ob.__schema__.defaults = dflts = {x: 42}
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

            checkValidate = (ob, impl=ob) ->
                withSpy impl, '__validate_names__', (vn) =>
                    impl.__validate_initializer__.call(ob, ob)
                    vn.should.not.have.been.called

                withSpy impl, '__validate_names__', (vn) =>
                    impl.__validate_initializer__.call(ob, arg = {})
                    vn.should.have.been.calledOnce
                    vn.should.have.been.calledOn(ob)
                    vn.should.have.been.calledWithExactly(arg)

            it "using the current implementation", ->
                checkValidate(@ob)

            it "using the default implementation", ->
                cls = class
                defineProperties(cls::, {}, null, cls::)
                checkValidate(new cls, Base::)





















    describe "__validate_names__", ->

        it "rejects objects with enumerable-own properties not in schema", ->
            defineProperties @ob, x: spec(1), null, @ob
            @ob.__validate_names__(x:2)
            (=> @ob.__validate_names__(constructor: 99))
            .should.throw TypeError, "Unknown property: constructor"


    describe "__initialize_from__", ->

        beforeEach ->
            defineProperties @ob, y: spec(42), z: spec(99), null, @ob
            @ob.__props = {}

        it "accepts multiple sources", ->
            @ob.__initialize_from__({y:1}, {z:2})
            @ob.__props.should.eql {y: 1, z: 2}

        it "uses the first source with a property", ->
            @ob.__initialize_from__({y:1}, {y:2})
            @ob.__props.should.eql {y: 1, z: 99}

        it "initializes all properties, even if not specified", ->
            @ob.__initialize_from__({q:1}, {r:2}, {z:15})
            @ob.__props.should.eql {y: 42, z: 15}

        it "throws when a required property is missing", ->
            defineProperties @ob, z: spec(0, required: yes), null, @ob
            (=> @ob.__initialize_from__({x:1}, {y:2}))
            .should.throw TypeError, "Missing required property: z"










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

        describe "initially configures __schema__ with", ->
            it ".specs", ->
                specs = @proto.__schema__.specs
                expect(Object.keys(specs)).to.eql ['b', 'c', 'a']
                ['b', 'c', 'a'].forEach (name) =>
                    expectNamedSpec(specs[name], name, schema1[name], name)

            it ".defaults", ->
                expect(items(@proto.__schema__.defaults))
                .to.eql [['b', 'b'], ['c', 'c'], ['a', 'a']]

            it ".names", ->
                expect(@proto.__schema__.names)
                .to.eql ['b','c','a']













        describe "updates __schema__ with", ->

            beforeEach -> defineProperties(@ob, schema2, null, @proto)

            it ".specs", ->
                specs = @proto.__schema__.specs
                expect(Object.keys(specs)).to.eql ['b', 'c', 'a', 'd']

                ['b', 'd', 'a'].forEach (name) =>
                    expectNamedSpec(specs[name], name, schema2[name], name)

                expectNamedSpec(specs.c, 'c', schema1.c, 'c')

            it ".defaults", ->
                expect(items(@proto.__schema__.defaults))
                .to.eql [['b', 'B'], ['c', 'c'], ['a', 'A'], ['d', 'D']]

            it ".names", ->
                expect(@proto.__schema__.names).to.eql ['b', 'c', 'a', 'd']

        describe "inherits from superclass __schema__", ->

            beforeEach ->
                @proto2=Object.create(@proto)
                defineProperties(@ob, schema2, null, @proto2)

            it ".specs", ->
                specs = @proto2.__schema__.specs
                expect(Object.keys(specs)).to.eql ['b', 'c', 'a', 'd']

                ['b', 'd', 'a'].forEach (name) =>
                    expectNamedSpec(specs[name], name, schema2[name], name)

                expectNamedSpec(specs.c, 'c', schema1.c, 'c')

                specs = @proto.__schema__.specs
                expect(Object.keys(specs)).to.eql ['b', 'c', 'a']
                ['b', 'c', 'a'].forEach (name) =>
                    expectNamedSpec(specs[name], name, schema1[name], name+"(base)")


            it ".defaults", ->
                expect(items(@proto.__schema__.defaults))
                .to.eql [['b', 'b'], ['c', 'c'], ['a', 'a']]
                expect(items(@proto2.__schema__.defaults))
                .to.eql [['b', 'B'], ['c', 'c'], ['a', 'A'], ['d', 'D']]

            it ".names", ->
                expect(@proto.__schema__.names).to.eql ['b', 'c', 'a']
                expect(@proto2.__schema__.names).to.eql ['b', 'c', 'a', 'd']

































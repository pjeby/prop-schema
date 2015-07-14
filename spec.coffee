{expect, should} = chai = require 'chai'
should = should()
chai.use require 'sinon-chai'

{spy} = sinon = require 'sinon'

spy.named = (name, args...) ->
    s = if this is spy then spy(args...) else this
    s.displayName = name
    return s

{Base, spec, assign, isPlainObject, type, compose} = props = require './'

util = require 'util'



























describe "Type and Function Composition", ->

    describe "Compositional Algebra", ->

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
            expect(f_).to.have.been.calledOn(t)
            expect(g_).to.have.been.calledOn(t)

        it "unwraps types", ->
            expect(compose(type(f),type(g))(3)).to.equal 8

        it "handles many arguments", ->
            expect(compose(f,g,h)(3)).to.equal 5






    describe "type(f1).and(x)", ->
        it "returns type(f1, x)"

    describe "type(f1).or(x)(val)", ->
        it "calls f1(val) first"
        it "calls compose(x)(val) if f1(val) throws"

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
            c = spy.named 'compose', props, 'compose'
            t(42, g=->)
            try expect(c).to.have.been.calledWithExactly(f, g)
            finally c.restore()

        it "with metadata only", ->
            s = type(f=->)(99, {x:1})
            expect(s.value).to.equal 99
            expect(s.meta).to.eql {x: 1}
            expect(s.convert).to.equal f

    it "check(message)() always throws"
    it "check(filter, message)(val) throws unless filter(val)"








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



describe "Basic types", ->
  for own k, v of defaults = {string:"x", number:42, boolean:yes, function:->}
    do (k, v, t = props[k]) ->
      describe "."+k, ->
        it "accepts #{k}"
        for own kk, vv of defaults when kk isnt k
          it "rejects #{kk}"

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
    it "-> defineProperties(cls.prototype, schema, undefined, cls.prototype)"

describe "props(schema)", ->
    it "returns a new subclass of props.Base"
    it "-> defineProperties(cls.prototype, schema, undefined, cls.prototype)"




describe "Instance Initialization", ->

    describe "__setup_storage__", ->
    describe "__validate_initializer__", ->
    describe "__validate_names__", ->
    describe "__initialize_from__", ->













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
            items = (val) -> Object.keys(val).map (k) -> [k, val[k]]

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






    describe "defineProperties(ob, schema, factory)", ->

        describe "invokes factory(name, spec) for each schema item", ->
            it "with a named spec"
            it "passing the result to Object.defineProperty(ob, name, ...)"
            it "using props.Base::__prop_desc__ as a default factory"
            it "using ob.__prop_desc__ as a factory if available"

    describe "defineProperties(ob, schema, factory, proto)", ->

        describe "initially configures", ->
            it "__specs__"
            it "__defaults__"
            it "__names__"

        describe "updates", ->
            it "__specs__"
            it "__defaults__"
            it "__names__"























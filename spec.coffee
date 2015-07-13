{expect, should} = chai = require 'chai'
should = should()
chai.use require 'sinon-chai'

{spy} = sinon = require 'sinon'

spy.named = (name, args...) ->
    s = if this is spy then spy(args...) else this
    s.displayName = name
    return s

{Base, spec, assign, isPlainObject, type, compose} = props = require './'





























describe "Type and Function Composition", ->

    describe "Compositional Algebra", ->
        it "compose(fn) == fn"
        it "compose(type(fn)) == fn"
        it "type(fn).converter == fn"
        it "type(type(fn)).converter == fn"

    describe "compose(f, g)", ->
        it "calls f(g(v)"
        it "calls f and g with same context"
          
    describe "type(f1).and(x)", ->
        it "returns type(f1, x)"

    describe "type(f1).or(x)(val)", ->
        it "calls f1(val) first"
        it "calls compose(x)(val) if f1(val) throws"

    describe "type(fn)(...,cvt..) -> spec(...,fn,cvt...)", ->
        it "with all arguments"
        it "with just a value"
        it "with converter functions"
        it "with metadata only"
        it "with a docstring"
   
    it "check(message)() always throws"
    it "check(filter, message)(val) throws unless filter(val)"


describe "Properrty Specifiers", ->

    describe "spec(value, doc?, meta?, converter...)", ->
        it ".doc"
        it ".meta"
        it ".value"
        it ".convert() <- compose(converter...)"




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
        it "to the destination"
        it "with left-most precedence"
        it "ignoring null/undefineds"

    describe "isPlainObject()", ->
        it "accepts object literals"
        it "rejects non-objects"
        it "rejects class instances"

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




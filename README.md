# prop-schema

`prop-schema` lets you define self-validating classes and properties using a lightweight but extensible schema DSL based on single-argument validator/converter functions.

Although it was originally designed for options processing, it is sufficiently general to support a wide variety of use cases, including schema-driven metaprogramming.  (To e.g. create database schemas, help listings, command-line argument parsers, etc. from your property definitions.)

It is implemented using ES5 property descriptors, and is compatible with any prototype-based class system (including ES6, CoffeeScript, `util.inherits()`, etc.), but does not require you to inherit from a specific base class.  (Although you *do* need to invoke an initialization function from your constructors, if you're not letting `prop-schema` create the constructor.)  

Features include:

* Chain an unlimited number of arbitrary validation or type conversion functions
* Combine types with `.and()` and `.or()`
* Properties can have default values or require explicit initialization
* Subclasses inherit base class schema, and only need to add their changes or additions
* Properties always enumerate in schema definition order, and instances are initialized monomorphically
* Property definitions can include arbitrary metadata that can be used for validation, conversion, storage management, help listings, command-line options, etc.
* Customizable backing store for property data
* Runs in any ES5+ environment, including Node, io.js, and most "modern" browsers

### Contents

<!-- toc -->

* [Usage Synopsis](#usage-synopsis)
* [Developer's Guide](#developers-guide)
  * [Defining Classes' Schema](#defining-classes-schema)
    * [Initializing properties](#initializing-properties)
    * [Subclassing and Schema Updates](#subclassing-and-schema-updates)
    * [JSON, util.inspect, hasOwnProperty, Object.keys(), etc.](#json-utilinspect-hasownproperty-objectkeys-etc)
  * [Specifying Properties](#specifying-properties)
    * [Using `props.spec()`](#using-propsspec)
    * [Using a Type Expression](#using-a-type-expression)
    * [Combining Types](#combining-types)
  * [Defining New Property Types](#defining-new-property-types)
    * [Using `props.type(typeOrFunction,...)`](#using-propstypetypeorfunction)
    * [Using `props.check(message, filter)`](#using-propscheckmessage-filter)
  * [Schema Objects and Customization](#schema-objects-and-customization)
    * [Constructor Behavior](#constructor-behavior)
    * [Customizing Storage](#customizing-storage)
  * [Misc. Utility functions](#misc-utility-functions)

<!-- toc stop -->

## Usage Synopsis

```javascript
var props = require('prop-schema');

// Create a class with a default constructor and specified schema
var Report = props({

  // Properties are specified by calling a type with a default value, an
  // optional help string, optional metadata, & an optional validator/converter
  // function
  sql: props.string(null, "sql to run", {required: true}),

  // Property types can be .and() and .or()-ed
  cols: props.integer.and(props.positive)(80, "Report width in columns"),

  // Properties can have any number of chained converter/validator functions
  title: props.string("", "Report title", function(value) {
    if (value.length < 4)
      throw new TypeError(this.name + " must be at least 4 chars");
    else return value;
  }),
})

// The class can be extended by adding methods or subclassing
Report.prototype.run = function () {
  console.log("Running "+this.title);
};

// The class prototype is automatically annotated with useful schema
// information you can use to generate help listings, db schemas, etc.

var schemaInfo = Report.prototype.__schema__;
schemaInfo.names // => [ 'sql', 'cols', 'title' ]
schemaInfo.defaults // => { sql: null, cols: 80, title: '' }
schemaInfo.specs['title'].doc // => 'Report title'
schemaInfo.specs['sql'].meta // => { required: true }

// Required properties must be listed somewhere in the arguments; the default
// value isn't used:
new Report()
// => TypeError: Missing required property: sql

// Instances are created with immediate validation
new Report("foo") 
// => TypeError: Arguments must be plain Objects or schema-compatible 

// Unrecognized property names get an error by default
new Report({sequel:"z"}) // => TypeError: Unknown property: sequel

// Even default values are subject to validation
new Report({sql:"X"}) // => TypeError: title must be at least 4 chars

// Each combined type supplies its own error messages
new Report({sql: "Z", cols: 0.1}) // => TypeError: cols must be an integer
new Report({sql: "Z", cols: 0}) // => TypeError: cols must be > 0

// Property enumeration follows schema order, not argument order
var r1 = new Report({title: "Hello", sql:"X"}) 
r1.__props // => { sql: "X", cols: 80, title: "Hello" }

// Multiple arguments can be passed in order to combine/inherit properties
var r2 = new Report({cols:20}, r1)
r2.__props // => { sql: "X", cols: 20, title: "Hello" }

// Earlier arguments' values override later ones
var r3 = new Report({title: "Yo!!"}, {cols:5}, r2, {sql: "WHAT?"})
r3.__props // => { sql: "X", cols: 5, title: "Yo!!" }


// Custom property types can be created, and can use custom metadata as part of
// their validation/conversion function(s)

var scriptFn = props.function.or(     // accept a function, or
  props.string.and(function(value){   // a string we'll compile to a function
    try {                             // using a property-specific language
      return languages[this.meta.lang].compileToFunction(value);
    } catch (e) {
      throw new TypeError(this.name+" must be valid "+this.meta.lang)
    }
  })
)

// You can add a schema to an existing class, as long as your constructor
// calls props.Base() to initialize property storage and set default values

props(Handler, {
  query: scriptFn("", "GraphQL to run", {lang: 'GraphQL', required: true}),
  handler: scriptFn("", "JS to run", {lang: 'Javascript', required: true})
})

function Handler() {
  var schema = this.__schema__;
  // Default initializes from all args, but you can pass whatever you want here
  props.Base.apply(this, arguments);
  // ...and now you can do stuff with initialized properties here
}
```

## Developer's Guide

### Defining Classes' Schema

As shown in the synopsis above, you can use `props-schema` with an existing class, or you can have it create a class for you.  If all you need from the constructor is to populate your schema-controlled properties, and you are using plain Javascript to set up your methods (or don't have any), then it's simplest to just call `props(specs)` to get a new class.

However, if you're using ES6, CoffeeScript, or some other language or framework to write your methods, or if you need a different constructor signature, use `props(MyClass, specs)` instead, to add a schema to your class after it has been created.

#### Initializing properties

Before you can read or write any schema-controlled properties on an object, they must be initialized.  If you let `prop-schema` create your class constructor, this is handled for you automatically.  But if you are creating your own constructor, it must invoke `props.Base.call(this, source, ...)` or `props.Base.apply(this, sources)`, with appropriate data sources for intializing the properties.  (Otherwise, you will receive an error when you try to read or write any schema-controlled properties.)

If you just want all properties to be initialized to default values, use `props.Base.call(this)`, without any data sources.  This will work as long as you have no `required` properties, and all your default values are considered valid by their conversion/validation functions.

If you want to explicitly initialize properties, you can pass a plain Object with the property names and values, or an instance of the same class to copy from.  That is, `props.Base.call(this, {name: val, ...})` or `prop.Base.call(this, instanceToCopyFrom)`.

`prop.Base` actually accepts multiple data sources, with earlier sources' properties overriding later ones, so you can do things like, `props.Base.call(this, {name: val, ...}, instanceToCopyFrom)` to copy another instance while overriding a few properties.  (You can also use `props.Base.apply(this, arguments)`, if you want to just pass through all of your constructor's arguments as data sources, which is how classes created by `props(specifiers)` work.)

Regardless of the way you obtain and supply these data sources, only properties defined in the current class's schema will be copied from them.  And if any plain Objects contain any extraneous properties that are not part of the schema, an error will be thrown.

These initialization behaviors should be compatible with most use cases, but occasionally you may need to support copying from other class instances or allow extraneous properties, etc.  In that event, you can define certain special methods on your class in order to change the default behaviors, as we will describe in a later section on customizing constructor behavior.


#### Subclassing and Schema Updates

Once a class has a schema, you can add additional properties (or override them), by calling `props()` on the class again, e.g.:

```javascript
props(MyClass, moreSpecs) // add moreSpecs to the MyClass schema
```

Once a class has schema, you can also subclass it, and it will inherit the schema from its base class.  If you want to extend the subclass schema, just call `props()` on the subclass, with the additional or overriding properties.  For example, in ES6:

```javascript
class Subclass extends MyClass {
  // methods, etc. here
}

props(Subclass, additionalProps)
```

or in CoffeeScript:

```coffeescript
class Subclass extends MyClass
  # methods, etc. here
  props(@, additionalProps)
```

or using `util.inherits()`:

```javascript
function Subclass () {
  MyClass.apply(this, arguments);
}

util.inherits(Subclass, MyClass);

props(Subclass, additionalProps);   // must be *after* the inherits() call!

Subclass.prototype.whatever = function() { ... } // etc.

```

As you can see, `prop-schema` is not dependent on any particular inheritance implementation: as long as your subclass's prototype is an instance of its base class, and the base class's schema is set up before creating the subclass schema, it will work.

(For example, if you're using Node's `util.inherits()`, just make sure you've called both `props(MyClass, baseSchema)` and `util.inherits(Subclass, MyClass)` before you call `props(Subclass, moreProps)`.)

> Note: there is currently not any way to *remove* a property in a subclass schema.  If you are trying to do that, you're violating the "subclass substitutability" principle, which probably means you're using inheritance for something it's not designed for.  The substitutability principle means a subclass schema should always include all of its base class properties, and any property value produced by the subclass should be usable in the same property in the base class.  `prop-schema` does not currently enforce this principle, but it may do so in the future.

#### JSON, util.inspect, hasOwnProperty, Object.keys(), etc.

By default, the actual property values of an instance of a schema-controlled class are stored in its `.__props` property, and the property descriptors themselves are inherited from the class's prototype.  This works fine for code that is accessing properties by name or looping over all enumerable properties, but it does not work for `JSON.stringify()`, `util.inspect()`, or other things that only enumerate over own-properties.

This can easily be worked around by calling `this.__schema__.defineProperties(this)` in your class's constructor, to forcibly add the descriptors to each instance.  The trade-off is a reduction in speed of property access, and increased storage space per instance, so it is not done by default.  There is also no way to undo it once it has been done to a given instance.  (Also, it's only a partial fix for `util.inspect()`, which will display all property values as `[Getter/Setter]` instead of their actual values.)

Of course, if you want to avoid the performance cost, and only need to support `JSON.stringify()` or `util.inspect()`, you can always define a `.toJSON()` method that returns `.__props`, and/or a similar method for `.inspect()`.  (Which then works around the `Getter/Setter]` limitation.)

For more information on how properties are stored (and how to customize that storage), see the section below on "Customizing Storage".


### Specifying Properties

The schema you pass to `props()` is a plain object mapping property names to **property specifiers**.  A property specifier is an object with the following properties and methods:

* `.value` -- the property's default value
* `.doc` -- a documentation string describing the property (may be empty)
* `.meta` -- a plain object containing arbitrary metadata.  If it contains `required: true`, then the property is required and must be explicitly given in a data source passed to `props.Base` in the class's constructor.
* `.convert(value)` -- a method that validates and/or converts an input value to the correct type, or throws an error if the value is invalid

When you create or update a class's schema using `props()`, it updates schema information in a `__schema__` property on the class's prototype.  The `__schema__` includes the following properties:

* `names` -- the names of the properties in the class's schema, as an array
* `defaults` -- an object mapping property names to default values
* `specs` -- an object mapping property names to their property specifiers

Using the property specifiers in `YourClass.prototype.__schema__.specs` (or `yourObject.__schema__.specs`), you can access their `.doc`, `.meta`, and other properties to help you generate help messages, command-line parsers, database schemas, etc.

But first, you need to actually create some property specifiers, using `props.spec()` or type expressions.

#### Using `props.spec()`

The most basic way to specify a property specifier is by calling `props.spec()` to create a `spec` instance.  (Using the `new` operator is optional.)  The call signature is:

* `props.spec(defaultVal, optionalDocString, optionalMetadata, converters...)`

That is, `props.spec()` accepts any value as a default, followed by an optional documentation/help string, an optional object containing arbitrary metadata (such as a `required` flag), and zero or more converter/validator functions or `prop-schema` type expressions.  Since all arguments after the first are of distinct types, you can leave any of them out and your intent will still be understood as long as the order is correct.  That is, the following are all valid ways to invoke it:

* `props.spec(42, "Ultimate answer", {}, parseInt)`
* `props.spec(42, parseInt, props.positive)`
* `props.spec(42, "Answer")`
* `props.spec(42, {required: yes})`
* `props.spec(42)`

The created `spec` instance will have `.value`, `.doc`, and `.meta` properties corresponding to the appropriate arguments, or to empty defaults (`""` and `{}`) if omitted.  It will also have a `.convert()` method created by composing the supplied converter/validator functions or type expressions into a single function.

Currently, `prop-schema` doesn't use the `.doc` property for anything itself; it's mainly intended for use by higher-level frameworks.  Likewise, the only metadata key `prop-schema` uses is `required`: if it's true, then the property must be specified by one of the initialization arguments when creating an instance of a class that uses this property.

**Converter/validator functions** are functions that take a value as a single argument and either return the value (or a converted form of it), or throw a TypeError to indicate that the value is invalid.  If you specify more than one converter/validator, they are chained, with later converter/validators being passed the output of earlier ones.  If no converter/validators are supplied, the property will accept any value, with no checking or conversion.

When invoked, converter/validator functions will have a `this` corresponding to the `spec` object, with an addtional `.name` property that can be used to construct error messages.  Converter/validator functions can also access the specifier's `.doc` string and `.meta` data, as well as the default `.value`.

#### Using a Type Expression

Type expressions (such as `props.boolean`, etc.) are essentially just functions that call `props.spec()` with an extra converter/validator function inserted at the beginning of the list, making that converter/validator a prerequisite for any explicitly-added ones.  That is, this:

* `someType(defaultVal, optionalDocString, optionalMetadata, extraConverters...)`

is short for:

* `props.spec(defaultVal, optionalDocString, optionalMetadata, someType.converter, extraConverters...)`


You can easily define your own types (as described in the next section), or you can use any of the following predefined types:

* `props.string`, `props.number`, `props.boolean`, `props.function` -- these types just verify that the value has a `typeof` matching the specified type name
* `props.empty` -- throws an error unless the value is null or undefined.  (Normally, you would only ever use this to `.or` with another type, e.g. `props.empty.or(props.string)`)
* `props.object` -- throws unless the value is a *plain* `Object`, i.e. an object whose prototype is `Object.prototype`.  If the value is a plain object, a **new copy** of the object will be stored, so that mutating the passed-in value won't change the property.
* `props.integer` -- throws unless the value is a number with nothing after the decimal point.  If the value is a floating point representation of an integer value (e.g. `12.0`), it'll be converted to a 32-bit integer if possible.
* `props.nonNegative`, `props.positive` -- throw unless the value is a number >=0 or >0, respectively


#### Combining Types

Type expressions have `.and()` and `.or()` methods which can be used to construct new types.  For example, `props.integer.and(props.positive)` will returns a type expression that first checks the value is an integer, and then whether it's positive.  Similarly, `props.empty.or(props.string)` will check for a null/undefined value, and if that fails, check for a string.

`.and()` and `.or()` work like the Javascript `&&` and `||` operators, in that they are short-circuiting.  The target of an `.and()` will only be called if the preceding validation/conversion *succeeded*, while the target of an `.or()` will only be called if the preceding validation/conversion *failed* with an error.

When an error occurs, the error thrown will depend on the order and operators involved.  When combining types with `.and()`, the error will be the *first* error thrown, but when combining with `.or()`, it will be the *last* error thrown.  So, if you pass a string to `props.integer.and(props.positive)`, you'll get a complaint that it's not a number.  But if you pass a number to `props.empty.or(props.string)`, you'll get an error message that it's not a string.  (Conversely, passing a number to `props.string.or(props.empty)` will complain that it's not null or undefined.)

Since `.or()` only tells you about the last failure, it's often uninformative when there are multiple alternatives.  So you may want to add a more useful error message on an `.or()`-ed type, by adding *another* `.or()` clause to supply the error message, like this:

* `props.string.or(props.empty).or(props.check("must be string or undefined"))`

This way, if the value is neither empty nor a string, you'll get a more helpful error message (i.e. `"someProp must be string or undefined"`).

In addition to using the `.and()` and `.or()` operators, types can also be composed by adding them to the `converters...` portion of a `props.spec()` call, or by using `props.type()`.  So, all of the following are valid ways to create a property accepting positive integers with a default of 42:

* `props.spec(42, props.integer, props.positive)`
* `props.spec(42, props.integer.and(props.positive))`
* `props.spec(42, props.type(props.integer, props.positive))`
* `props.integer(42, props.positive)`
* `props.integer.and(props.positive)(42)`
* `props.type(props.integer, props.positive)(42)`

Regardless of how you combine type expressions, they are chained in left-to-right order, with later types' converter/validators being called after the earlier ones have been called.  The target of an `.or()` receives the *input* that was passed to the failed converter/validator before it, while all other converter/validators receive the *result* of the converter before them.  (Allowing you to stack an arbitrary series of type conversions and validations of converted results.)

In general, type expressions can be composed with essentially arbitrary complexity, by saving them in intermediate variables or using parentheses to group operations.  For example:

```javascript
var posInt = props.integer.and(props.positive);
var shortString = props.string.and(
  props.check("must be less than 4 characters", function(val){
    return val.length<4;
  });
)
var posIntOrShortStringOrEmpty = posInt.or(shortString)
```

### Defining New Property Types

#### Using `props.type(typeOrFunction,...)`

To create a new basic type expression, simply call `props.type()` with one or more type expressions or converter/validator functions.  The return value will be a new type expression: a function that can be called with the same argument signature as `props.spec()` to create a `spec` with the appropriate type.  It will also have `.or()` and `.and()` methods, and can thus be used to compose more complex types.

For example, you could create a parsed positive integer type like this:

```javascript
var parsedInt = props.type(parseInt, props.positive)
```

Then any `parsedInt()` properties will accept strings and convert them to integers before checking whether they're positive.  And if you wanted to fall back to a string if the value wasn't valid, you could then do this:

```javascript
var parsedIntOrString = parsedInt.or(props.string)
```

to create properties that store a string *unless* the string starts with a positive integer. (In which case, it'll store the integer and drop the rest of the string.  Why you'd *want* to do that, I don't know; this is just a made-up example to show the full generality of property type specifiers!)

#### Using `props.check(message, filter)`

In many cases, you may already have a function that validates an argument and returns a boolean.  In that event, you can create a type using `props.check()`.

If the supplied `filter` function returns a truthy value, the property value is accepted and passed on unchanged to the next converter/validator in the chain.  Otherwise, a new TypeError will be thrown, using `message`.  (The property name and a space are prepended to the message, so use a string like `"must be an integer > 0"` for best results.)

Essentially, `props.check(message, filter)` is shorthand for:

```javascript
props.type(function(value){
  if (!filter || !filter.call(this, value)) 
    throw new TypeError(this.name+" "+message);
  else return value;
})
```

So if you already have a validation function, it's simplest to use `props.check()` to turn it into a type.  (The resulting type expression, of course, can still be combined with other types or supplied as a converter/validator as part of a property specification.)

By the way, the `filter` function is actualy *optional*: if you omit it, the check will always fail, and so the error will always be thrown!  This is useful to add at the end of an `.or()` chain, to provide a more-informative error message.  It will only be invoked if all other attempts to validate the property have failed, so you can use it to list out all the possible kinds of values the property type accepts.

### Schema Objects and Customization

While `props-schema` offers sensible default behaviors, some use cases may require customizing or extending how construction works, properties are stored, descriptors are generated, etc.

So, to support these use cases, the `props()` function allows you to provide an extra argument that contains various "extension methods", to override various aspects of property storage and instance initialization.  Specifically, you can call `props(specifiers, extensions)` to create a class with the given extensions, or `props(ExistingClass, specifiers, extensions)` to add the extensions to an existing class.

Currently, there are five special methods you can override to customize constructor behavior and property storage.  These methods already exist by default on newly-created schemas, so you only need to supply the ones you want to customize.


#### Constructor Behavior

The default constructor for `props.Base` accepts any number of arguments, as long as they are all either plain objects or instances of the current class.  Plain object arguments are checked for invalid names (i.e. ones not listed in the schema), and all properties are initialized using the first match found in the arguments.  Argument precedence is left-to-right, such that the right-most arguments supply defaults for arguments to the left.

These behaviors are all controlled by the following `__schema__` methods, which you can customize by adding them to your schema's `extensions`:

* `.propertiesFrom(source,...)` -- returns an object with one own-property for each property in the schema, initialized to the default value or the first value supplied by any of the given sources.  If none of the sources has a value for a `required` property, an error is thrown.  It's called by `props.Base()` in order to get an object's initial properties, and can be overridden to change argument precedence or the handling of `required` properties.

* `.toInitializer(arg)` -- throws an error if `arg` isn't a plain `Object` or an object with a compatible schema.  (That is, a schema with at least one property in common with the current schema.)  If a plain object, it also calls `.validateNames(arg)` to check for unrecognized properties.  If it's an object with a compatible schema, the compatible properties will be extracted and returned in a plain object.  It's called by `.propertiesFrom()` to convert each of its arguments to a usable data source.  Can be overridden to support extracting data from other sorts of objects.

* `.validateNames(arg)` -- throws an error if arg has any own-properties that aren't listed in this class's schema.  Returns `arg` otherwise.  (Called by `.toInitializer()` when an argument is a plain object.)  You can override this to e.g. ignore unrecognized properties.


#### Customizing Storage

By default, the values of schema-based properties are stored in a non-enumerable `__props` property on an object, but you can change this by supplying *both* of the following extensions when creating your schema:

* `.setupStorage(ob)` -- Set up property storage for `ob`.  The default creates a non-enumerable `__props` property on `ob` for storing property values, containing a copy of the schema `.defaults`.  (This method is called by the `props.Base` constructor, before it initializes property values from `.propertiesFrom(arguments...)`.)

* `.descriptorFor(name, spec)` -- Return an ES5 property descriptor for the given property name and specifier.  The default returns something like:

```javascript
{
  get: function() { return this.__props[name]; },
  set: function(value) { this.__props[name] = spec.convert(value); },
  enumerable: true,
  configurable: true
}
```

Since you have access to the `spec` in `descriptorFor()`, you can use its `.meta` data to customize the descriptor, e.g. if you want to create lazy-loading database properties or some such.

In addition to the above methods, there is also a third storage-related method that you probably don't need to override, but which you may find convenient for certain use cases:

* `.defineProperties(ob, factory?)` -- define an ES5 property on `ob` for every property in the schema, calling `factory(name, spec)` to obtain the descriptor.  If `factory` isn't supplied, the schema's `.descriptorFor()` method is used.

This method is automatically called for you on the relevant prototype when calling `props()` or `props.defineSchema()`, to set up inheritable descriptors.   But if you need to attach descriptors directly to an object without inheriting them from a prototype, or are creating some type of proxy objects, you may find it useful.


### Misc. Utility functions

For your convenience, `prop-schema` exposes a few of its internally-used utility functions.  `isPlainObject()` and `assign()` are used by the `props.object` type to detect plain objects and clone them.  They are exposed so that you can build similar types, such as a recursively-cloning object type.  `compose()` may occasionally be useful for advanced metaprogramming, and is included for API completeness.  Finally, `defineSchema()` exposes the core functionality of the `props()` function in a reusable way.

* `props.isPlainObject(ob)` -- returns true if `ob` is a plain `Object` (i.e., has a prototype of exactly `Object.prototype`)

* `props.assign(target, others...)` -- a rough approximation of the ES6 `Object.assign()` method: enumerable own-properties of each of the `others` are assigned to `target`, with later entries taking precedence over earlier ones.

* `props.compose(typeOrFunction, ...)` -- similar to `props.type()`, except that it returns a converter/validator function instead of a property type.  That is, the returned function takes a value and returns a converted value or throws an error.  It does *not* have `.or()` or `.and()` methods, nor can it be used as shorthand to specify properties.  You will probably never need this function unless you are creating your own type composition functions, or wish to turn a type back into a converter/validator function.  (i.e. `props.compose(aType)` converts `aType` back to a plain converter/validator function.)

* `props.defineSchema(prototype, specs, options?)` -- create and/or update `prototype.__schema__` with the specifiers in `specs`, the options in `options` (if supplied), and add/update the appropriate property descriptors on `prototype`.  (This is basically the internal implementation of the `props()` function, minus the syntax sugar.)

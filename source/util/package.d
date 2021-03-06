module util;

import std.conv;
import std.range;
import std.algorithm;
import std.functional;
import std.traits;
import std.stdio;

public import util.LookaheadRange;
public import util.ResetRange;
public import util.visit;
public import util.meta;

/* Utility Functions */

public auto ariaticMap(alias fn, R)(auto ref R range)
    if(isCallable!fn)
{
    return range.chunk!(arity!fn).map!(x => fn(x.expand));
}

public auto chunk(size_t n, R)(auto ref R range)
{
    import std.typecons;
    import std.meta : Repeat;
    alias TupleType = Tuple!(Repeat!(n, ElementType!R));
    /* string mixins, amirite? */
    mixin("return range.chunks(n).map!(x => TupleType(" ~ expandArray!("x", n) ~ "));");
}

unittest
{
    auto testRange = [1, 2, 3, 4];
    int plus(int a, int b)
    {
        return a + b;
    }
    import std.stdio;
    assert(testRange.ariaticMap!plus.array == [3, 7]);
}

/* evaluate pred with the front of range and the value as arguments,
 * throwing an instance of E on failure, and popping and returning the
 * front of the range on success */
public auto matchOn(
        alias pred = (x, y) => x == y,
        Err = Exception,
        R,
        E)(auto ref R range, auto ref E elem)
    if(isInputRange!R)
{
    import std.string;
    enforce(!range.empty, "empty range, could not match");
    if(!pred(range.front, elem)){
        throw new Err("mismatch: expected %s, got %s".format(elem, range.front));
    }
    return range.popNext;
}


/* pops a value and returns it */
auto ref popNext(R)(auto ref R range)
    if(isInputRange!R)
{
    import std.exception;
    import std.stdio;
    enforce(!range.empty, "unable to popNext from emtpy range");
    auto ret = range.front;
    range.popFront;
    return ret;
}

auto fastCast(T, F)(auto ref F f)
//    if(is(F == class) && is(T == class))
{
    return *cast(T*)&f;
}

/* Creates Json-like strings */
mixin template fancyToString(alias conv = to!string)
{
    import std.string;
    import std.range;
    import std.algorithm;
    import std.traits;
    
    alias thisType = Unqual!(typeof(this));

    enum toStringBody = `
        {
            auto s = Unqual!(typeof(this)).stringof ~ " { ";
            alias fields = FieldNameTuple!(typeof(this));
            foreach(field; fields){
                alias valueType = Unqual!(typeof(mixin("this." ~ field)));
                auto fieldVal = mixin(field);

                static if(is(valueType == string)){
                    s ~= "%s: \"%s\"".format(field, conv(fieldVal));
                }else{
                    s ~= "%s: %s".format(field, conv(fieldVal));
                }
                s ~= " ";
            }
            s ~= "}";
            return s;
        }
    `;

    static if(is(thisType == class)){
        mixin("override string toString() const" ~ toStringBody);
    }else{
        mixin("string toString() const" ~ toStringBody);
    }
};

/* Create a struct-like class 
 * this entails a static constructor
 * (not requiring new), as well as 
 * a constructor that initializes
 * all members */
mixin template classStruct()
{
    import std.meta;
    import std.traits;

    alias ThisType = typeof(this);

    alias FieldTypes = Fields!ThisType;
    alias FieldNames = FieldNameTuple!ThisType;

    this(inout(FieldTypes) args)
    {
        foreach(i, x; FieldNames){
            mixin("this." ~ x ~ " = args[i];");
        }
    }

    mixin fancyToString;
    mixin simpleConstructor;
}

/* Dont need a 'new' to create a class 
 * e.g struct allocation, but for classes */
mixin template simpleConstructor()
{
    import std.algorithm;

    alias ThisType = typeof(this);
    static auto opCall(Args...)(in inout(Args) args)
    {
        return new ThisType(args);
    }
};

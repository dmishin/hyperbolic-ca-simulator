assert = require "assert"
M = require "../src/core/matrix3"
{VonDyck} = require "../src/core/vondyck.coffee"

# Knuth-Bendix solver for vonDyck groups, cleaned up API
#

describe "New API", ->

  it "Must work", ->
    group = new VonDyck 3, 4
    # aaa = bbbb = abab = 1

    assert.equal group.n, 3
    assert.equal group.m, 4
    assert.equal group.k, 2

    u = group.unity

    #Parsing and stringification
    x1 = u.a(1).b(-2).a(3)
    assert.equal x1.toString(), "aB^2a^3"

    x11 = group.parse "aB^2a^3"
    assert.ok x1.equals x11

    x12 = group.parse "A^3b2^A"
    assert.ok not x1.equals x12

    assert.ok u.equals(group.parse '')
    assert.ok u.equals(group.parse 'e')

    #Array conversion
    arr = u.a(2).b(-2).a(3).asStack()
    assert.deepEqual arr, [['a',3],['b',-2],['a',2]]
    
    #Normalization
    group.solve()

    x  = group.appendRewrite group.unity, [['a',2],['b',3]]
    x1 = group.appendRewrite group.unity, [['a',2],['b',3]]
    x2 = group.appendRewrite group.unity, [['a',2],['a',1],['b',1],['a',1],['b',1],['b',-1]]

    x3 = group.rewrite u.b(3).a(2)
    
    assert.ok x.equals x1
    assert.ok x.equals x2
    assert.ok x.equals x3
    
    #last A elimination
    x = group.parse "bab" #eliminated to 1 by adding a: bab+a = baba = e
    assert.ok group.trimA(x).equals(u)


    checkTrimmingIsUnique = (chain) ->
      trimmedChain = group.trimA chain
      for aPower in [-group.n .. group.n]
        if aPower is 0 then continue
        chain1 = chain.a(aPower)
        if not group.trimA(chain1).equals(trimmedChain)
          throw new Error "Chain #{chain1} trimmed returns #{group.trimA chain1} != #{trimmedChain}"
      
      
    checkTrimmingIsUnique group.parse "e"
    checkTrimmingIsUnique group.parse "a"
    checkTrimmingIsUnique group.parse "A"
    checkTrimmingIsUnique group.parse "b"
    checkTrimmingIsUnique group.parse "B"
    checkTrimmingIsUnique group.parse "ba^2ba^2B"
    checkTrimmingIsUnique group.parse "Ba^3bab^2"

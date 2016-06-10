assert = require "assert"
M = require "../src/core/matrix3"
{VonDyck} = require "../src/core/vondyck.coffee"
{RegularTiling} = require "../src/core/regular_tiling.coffee"

# Knuth-Bendix solver for vonDyck groups, cleaned up API
#

describe "New API", ->

  it "Must work", ->
    group = new VonDyck 3, 4
    # aaa = bbbb = abab = 1

    assert.equal group.n, 3
    assert.equal group.m, 4
    assert.equal group.k, 2

    assert.equal group.type(), "spheric" #octahedron

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
    

describe "New VonDyck", ->
  it "must detect group type", ->
    assert.equal (new VonDyck 3,3).type(), "spheric" 
    assert.equal (new VonDyck 3,4).type(), "spheric"
    assert.equal (new VonDyck 3,5).type(), "spheric"
    assert.equal (new VonDyck 3,6).type(), "euclidean" #triangualr tiling
    assert.equal (new VonDyck 3,7).type(), "hyperbolic" #triangualr tiling

    assert.equal (new VonDyck 4,3).type(), "spheric" 
    assert.equal (new VonDyck 4,4).type(), "euclidean"
    assert.equal (new VonDyck 4,5).type(), "hyperbolic"


    assert.equal (new VonDyck 5,3).type(), "spheric" 
    assert.equal (new VonDyck 5,4).type(), "hyperbolic"
                        

describe "RegularTiling", ->
  it "must support cell coordinate normalization", ->
    tiling = new RegularTiling 3, 4
    #last A elimination
    x = tiling.parse "bab" #eliminated to 1 by adding a: bab+a = baba = e
    assert.ok tiling.trimA(x).equals(tiling.unity)


    checkTrimmingIsUnique = (chain) ->
      trimmedChain = tiling.trimA chain
      for aPower in [-tiling.n .. tiling.n]
        if aPower is 0 then continue
        chain1 = chain.a(aPower)
        if not tiling.trimA(chain1).equals(trimmedChain)
          throw new Error "Chain #{chain1} trimmed returns #{tiling.trimA chain1} != #{trimmedChain}"
      
      
    checkTrimmingIsUnique tiling.parse "e"
    checkTrimmingIsUnique tiling.parse "a"
    checkTrimmingIsUnique tiling.parse "A"
    checkTrimmingIsUnique tiling.parse "b"
    checkTrimmingIsUnique tiling.parse "B"
    checkTrimmingIsUnique tiling.parse "ba^2ba^2B"
    checkTrimmingIsUnique tiling.parse "Ba^3bab^2"
    
describe "RegularTiling.moore", ->
  #prepare data: rewriting ruleset for group 5;4
  #
  [N, M] = [5, 4]
  tiling = new RegularTiling N, M
  unity = tiling.unity
  cells = []
  
  cells.push  unity
  cells.push  tiling.trimA tiling.rewrite tiling.parse "b"
  cells.push  tiling.trimA tiling.rewrite tiling.parse "b^2"
  cells.push  tiling.trimA tiling.rewrite tiling.parse "ab^2"
  
  it "must return expected number of cells different from origin", ->
    for cell in cells
      neighbors = tiling.moore cell
      assert.equal neighbors.length, N*(M-2)

      for nei, i in neighbors
        assert not cell.equals nei

        for nei1, j in neighbors
          if i isnt j
            assert not nei.equals(nei1), "neighbors #{i}=#{nei1} and #{j}=#{nei1} must be not equal"
    return
    
  it "must be true that one of neighbor's neighbor is self", ->
    for cell in cells
      for nei in tiling.moore cell
        foundCell = 0
        for nei1 in tiling.moore nei
          if nei1.equals cell
            foundCell += 1
        assert.equal foundCell, 1, "Exactly 1 of the #{nei}'s neighbors must be original chain: #{cell}, but #{foundCell} found"
    return

    
describe "RegularTiling.moore", ->
  

assert = require "assert"
{nodeMatrixRepr, chainEquals, NodeA, NodeB, nodeHash, newNode, showNode, NodeHashMap} = require "./vondyck_chain.coffee"
M = require "./matrix3.coffee"
{CenteredVonDyck} = require "./triangle_group_representation.coffee"

describe "chainEquals", ->
  it "should return true for empty chains", ->
    assert chainEquals null, null
  it "should return false for comparing non-empty with empty", ->
    a1 = new NodeA(1,null)
    b1 = new NodeB(1,null)
    assert not chainEquals null, a1
    assert not chainEquals a1, null
    assert not chainEquals null, b1
    assert not chainEquals b1, null

  it "should correctly compare chains of length 1", ->
    a1 = new NodeA(1,null)
    a1_ = new NodeA(1,null)
    
    b1 = new NodeB(1,null)
    
    a2 = new NodeA(2,null)


    assert chainEquals a1, a1
    assert chainEquals a1, a1_
    assert chainEquals a1_, a1

    
    assert not chainEquals a1, a2
    assert not chainEquals a2, a1
    assert not chainEquals a1, b1
    assert not chainEquals b1, a1
  
  it "should compare chains of length 2 and more", ->

    a1b1 = new NodeA(1, new NodeB(1, null))
    a1b2 = new NodeA(1, new NodeB(2, null))
    a1b1a3 = new NodeA(1, new NodeB(1, new NodeA(3, null)))
    
    assert chainEquals a1b1, a1b1
    assert not chainEquals a1b1, a1b2
    assert not chainEquals a1b1, a1b1a3
    assert not chainEquals a1b1, null
  
describe "nodeHash", ->
  isNumber = (x) -> parseInt(''+x, 10) is x
  it "must return different values for empty node, nodes of lenght 1", ->
    e = null
    a1 = newNode('a', 1, null)
    a1b1 = newNode('a', 1, newNode('b', 1, null))
    a2 = newNode('a', 2, null)
    b1 = newNode('b', 1, null)
    b2 = newNode('b', 2, null)

    chains = [e, a1, a2, b1, b2, a1b1]

    for c in chains
      assert isNumber nodeHash c

    for c1, i in chains
      for c2, j in chains
        if i isnt j
          assert.notEqual nodeHash(c1), nodeHash(c2), "H #{showNode c1} != H #{showNode c2}"

  

    

describe "NodeHashMap", ->
  it "should support putting and removing empty chain", ->
    m = new NodeHashMap
    m.put null, "empty"
    assert.equal m.get(null), "empty"
    assert.equal m.count, 1
  
    m.put null, "empty1"
    assert.equal m.get(null), "empty1"
    assert.equal m.count, 1

    assert m.remove null
    assert.equal m.get(null), null
    assert.equal m.count, 0

  it "should support putting and removing non - empty chains", ->
    m = new NodeHashMap
    e = null
    a1 = newNode("a", 1, null)
    b2 = newNode("b", 2, null)
    a1b1 = newNode("a", 1, newNode("b", 1, null))
    
    m.put e, "e"
    m.put a1, "a1"
    m.put a1b1, "a1b1"
    m.put b2, "b2"

    assert.equal m.count, 4

    assert.equal m.get(e), "e"
    assert.equal m.get(a1), "a1"
    assert.equal m.get(b2), "b2"
    assert.equal m.get(a1b1), "a1b1"
  

  it "should support growing the table", ->

    m = new NodeHashMap
    initialTableSize = m.table.length
    
    for i1 in [-5..5]
      a1 = newNode 'a', i1, null
      for i2 in [-5..5]
        a2 = newNode 'b', i2, a1
        for i3 in [-5..5]
          a3 = newNode 'a', i3, a2
          for i4 in [-5..5]
            a4 = newNode 'b', i4, a3
            for i5 in [-5..5]
              a5 = newNode 'a', i5, a4
              m.put a5, true

    assert.equal m.count, 11**5

    for i1 in [-5..5]
      a1 = newNode 'a', i1, null
      for i2 in [-5..5]
        a2 = newNode 'b', i2, a1
        for i3 in [-5..5]
          a3 = newNode 'a', i3, a2
          for i4 in [-5..5]
            a4 = newNode 'b', i4, a3
            for i5 in [-5..5]
              a5 = newNode 'a', i5, a4
              assert m.get a5
    assert (m.table.length > initialTableSize)

    #check that collision count is sane
    it "must have sane collision count", ->
      cellSizes = (cell.length for cell in m.table)
      cellSizes.sort()
      assert cellSizes[cellSizes.length-1] < 100


describe "nodeMatrixRepr", ->
  group = new CenteredVonDyck 4, 4
  
  it "should return unity matrix for empty node", ->
    assert M.approxEq nodeMatrixRepr(null, group), M.eye()

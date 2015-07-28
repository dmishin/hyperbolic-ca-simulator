assert = require "assert"
{reverseShortlexLess, nodeMatrixRepr, chainEquals, NodeA, NodeB, nodeHash, newNode, showNode, NodeHashMap, reverseShortlexLess} = require "./vondyck_chain.coffee"
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
    
  it "should support copy", ->
    m = new NodeHashMap
    c1 = null
    c2 = newNode 'a', 2, null
    c3 = newNode 'b', 3, null
    c4 = newNode 'a', -1, c3
    cells = [c1,c2,c3,c4]

    for cell, index in cells
      m.put cell, index

    m1 = m.copy()
    #ensure that copy is right
    for cell, index in cells
      assert.equal m1.get(cell), index

    assert.equal m1.count, m.count

    #ensure that copy is independednt
    for cell, index in cells
      m.put cell, index+100

    for cell, index in cells
      assert.equal m1.get(cell), index

    #ensure that copy is functional
    c5 = newNode 'b', 3, c4
    m1.put c5, 100
    assert.equal m1.get(c5), 100
    assert.equal m.get(c5), null
    for cell, index in cells
      assert.equal m1.get(cell), index
    

  it "should remove cells without corrupting data", ->
    m = new NodeHashMap
    c1 = null
    c2 = newNode 'a', 2, null
    c3 = newNode 'b', 3, null
    c4 = newNode 'a', -1, c3
    cells = [c1,c2,c3,c4]

    for cell, index in cells
      m.put cell, index

    #check that data works fine
    for cell, index in cells
      assert.equal m.get(cell), index

    #now delete something

    m.remove c2
    expected = [0, null, 2,3]
    for cell, index in cells
      assert.equal m.get(cell), expected[index]

    m.remove c3
    expected = [0, null, null,3]
    for cell, index in cells
      assert.equal m.get(cell), expected[index]

    m.remove c4
    expected = [0, null, null,null]
    for cell, index in cells
      assert.equal m.get(cell), expected[index]
                
    m.remove c1
    expected = [null, null, null,null]
    for cell, index in cells
      assert.equal m.get(cell), expected[index]

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

describe "reverseShortlexLess", ->
  chain_a = newNode('a',1,null)
  chain_B = newNode('b',-1,null)
  chain_Baa = newNode('b',-1,newNode('a',2,null))
  it "should return false for equal chains", ->
    assert not reverseShortlexLess null, null
    assert not reverseShortlexLess chain_a, chain_a
    assert not reverseShortlexLess chain_B, chain_B
    assert not reverseShortlexLess chain_Baa, chain_Baa
    
  it "should compare chains of different len", ->
    assert reverseShortlexLess null, chain_a
    assert reverseShortlexLess null, chain_B
    assert reverseShortlexLess null, chain_Baa

    assert not reverseShortlexLess chain_a, null
    assert not reverseShortlexLess chain_B, null
    assert not reverseShortlexLess chain_Baa, null

    assert reverseShortlexLess chain_a, chain_Baa
    assert not reverseShortlexLess chain_Baa, chain_a
                

  it "should compare chains of same len", ->
    assert reverseShortlexLess chain_a, chain_B
    assert not reverseShortlexLess chain_B, chain_a

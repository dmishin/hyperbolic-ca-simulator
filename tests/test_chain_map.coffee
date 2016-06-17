assert = require "assert"
{unity, newNode} = require "../src/core/vondyck_chain.coffee"
{ChainMap} = require "../src/core/chain_map.coffee"

describe "ChainMap", ->
  it "should support putting and removing empty chain", ->
    m = new ChainMap
    m.put unity, "empty"
    assert.equal m.get(unity), "empty"
    assert.equal m.count, 1
  
    m.put unity, "empty1"
    assert.equal m.get(unity), "empty1"
    assert.equal m.count, 1

    assert m.remove unity
    assert.equal m.get(unity), null
    assert.equal m.count, 0

  it "should support putting values wtih accumulation", ->
    m = new ChainMap
    e = unity
    a1 = newNode("a", 1, unity)
    b2 = newNode("b", 2, unity)
    a1b1 = newNode("a", 1, newNode("b", 1, unity))

    #testing initial value for accumulation
    m.putAccumulate( a1b1, 1, ((x,y)->x+y), 10 )
    assert.equal m.get(a1b1), 11 #(initial is 10) + 1
    #for second value, existing is used.
    m.putAccumulate( a1b1, 1, ((x,y)->x+y), 10 )
    assert.equal m.get(a1b1), 12 #(previous is 11) + 1
    
        
  it "should support putting and removing non - empty chains", ->
    m = new ChainMap
    e = unity
    a1 = newNode("a", 1, unity)
    b2 = newNode("b", 2, unity)
    a1b1 = newNode("a", 1, newNode("b", 1, unity))
    
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
    m = new ChainMap
    c1 = unity
    c2 = newNode 'a', 2, unity
    c3 = newNode 'b', 3, unity
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
    m = new ChainMap
    c1 = unity
    c2 = newNode 'a', 2, unity
    c3 = newNode 'b', 3, unity
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

    m = new ChainMap
    initialTableSize = m.table.length
    
    for i1 in [-5..5]
      a1 = newNode 'a', i1, unity
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
      a1 = newNode 'a', i1, unity
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

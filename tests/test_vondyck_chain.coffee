assert = require "assert"
{unity, reverseShortlexLess, NodeA, NodeB, newNode, parseChain} = require "../src/core/vondyck_chain.coffee"

describe "chain.equals", ->
  it "should return true for empty chains", ->
    assert unity.equals unity
  it "should return false for comparing non-empty with empty", ->
    a1 = new NodeA(1,unity)
    b1 = new NodeB(1,unity)
    assert not unity.equals a1
    assert not a1.equals unity
    assert not unity.equals b1
    assert not b1.equals unity

  it "should correctly compare chains of length 1", ->
    a1 = new NodeA(1,unity)
    a1_ = new NodeA(1,unity)
    
    b1 = new NodeB(1,unity)
    
    a2 = new NodeA(2,unity)


    assert a1.equals a1
    assert a1.equals a1_
    assert a1_.equals a1

    
    assert not a1.equals a2
    assert not a2.equals a1
    assert not a1.equals b1
    assert not b1.equals a1
  
  it "should compare chains of length 2 and more", ->

    a1b1 = new NodeA(1, new NodeB(1, unity))
    a1b2 = new NodeA(1, new NodeB(2, unity))
    a1b1a3 = new NodeA(1, new NodeB(1, new NodeA(3, unity)))
    
    assert a1b1.equals a1b1
    assert not a1b1.equals a1b2
    assert not a1b1.equals a1b1a3
    assert not a1b1.equals unity
  
describe "Node.hash", ->
  isNumber = (x) -> parseInt(''+x, 10) is x
  it "must return different values for empty node, nodes of lenght 1", ->
    e = unity
    a1 = newNode('a', 1, unity)
    a1b1 = newNode('a', 1, newNode('b', 1, unity))
    a2 = newNode('a', 2, unity)
    b1 = newNode('b', 1, unity)
    b2 = newNode('b', 2, unity)

    chains = [e, a1, a2, b1, b2, a1b1]

    for c in chains
      assert isNumber c.hash()

    for c1, i in chains
      for c2, j in chains
        if i isnt j
          assert.notEqual c1.hash(), c2.hash(), "H #{c1} != H #{c2}"

  
describe "Chain.toStr", ->
  it "should convert node to text", ->
    assert.equal 'e', ""+unity
    assert.equal 'a', "" + (newNode 'a', 1, unity)
    assert.equal 'A', "" + (newNode 'a', -1, unity)
    assert.equal 'b', "" + (newNode 'b', 1, unity)
    assert.equal 'B', "" + (newNode 'b', -1, unity)
    assert.equal 'a^3', "" + (newNode 'a', 3, unity)
    assert.equal 'Aba^3', "" + (newNode 'a', 3, newNode 'b',1, newNode 'a', -1, unity)
    
describe "parseChain", ->
  it "should convert node to text", ->
    assert.ok parseChain('e').equals unity
    assert.ok parseChain('a').equals newNode 'a', 1, unity
    assert.ok parseChain('A').equals newNode 'a', -1, unity
    assert.ok parseChain('b').equals newNode 'b', 1, unity
    assert.ok parseChain('B').equals newNode 'b', -1, unity
    assert.ok parseChain('a^3').equals newNode 'a', 3, unity
    assert.ok parseChain('Aba^3').equals newNode 'a', 3, newNode 'b',1, newNode 'a', -1, unity
    


describe "reverseShortlexLess", ->
  chain_a = newNode('a',1,unity)
  chain_B = newNode('b',-1,unity)
  chain_Baa = newNode('b',-1,newNode('a',2,unity))
  it "should return false for equal chains", ->
    assert not reverseShortlexLess unity, unity
    assert not reverseShortlexLess chain_a, chain_a
    assert not reverseShortlexLess chain_B, chain_B
    assert not reverseShortlexLess chain_Baa, chain_Baa
    
  it "should compare chains of different len", ->
    assert reverseShortlexLess unity, chain_a
    assert reverseShortlexLess unity, chain_B
    assert reverseShortlexLess unity, chain_Baa

    assert not reverseShortlexLess chain_a, unity
    assert not reverseShortlexLess chain_B, unity
    assert not reverseShortlexLess chain_Baa, unity

    assert reverseShortlexLess chain_a, chain_Baa
    assert not reverseShortlexLess chain_Baa, chain_a
                

  it "should compare chains of same len", ->
    assert reverseShortlexLess chain_a, chain_B
    assert not reverseShortlexLess chain_B, chain_a




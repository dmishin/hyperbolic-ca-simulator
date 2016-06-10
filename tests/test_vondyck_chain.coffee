assert = require "assert"
{unity, reverseShortlexLess, nodeMatrixRepr, chainEquals, NodeA, NodeB, nodeHash, newNode, showNode, parseNode, inverseChain, appendChain, appendInverseChain} = require "../src/core/vondyck_chain.coffee"

M = require "../src/core/matrix3.coffee"
{CenteredVonDyck} = require "../src/core/triangle_group_representation.coffee"

#for testing algebra
{makeAppendRewrite, vdRule} = require "../src/core/vondyck_rewriter.coffee"
{RewriteRuleset, knuthBendix} = require "../src/core/knuth_bendix.coffee"

describe "chainEquals", ->
  it "should return true for empty chains", ->
    assert chainEquals unity, unity
  it "should return false for comparing non-empty with empty", ->
    a1 = new NodeA(1,unity)
    b1 = new NodeB(1,unity)
    assert not chainEquals unity, a1
    assert not chainEquals a1, unity
    assert not chainEquals unity, b1
    assert not chainEquals b1, unity

  it "should correctly compare chains of length 1", ->
    a1 = new NodeA(1,unity)
    a1_ = new NodeA(1,unity)
    
    b1 = new NodeB(1,unity)
    
    a2 = new NodeA(2,unity)


    assert chainEquals a1, a1
    assert chainEquals a1, a1_
    assert chainEquals a1_, a1

    
    assert not chainEquals a1, a2
    assert not chainEquals a2, a1
    assert not chainEquals a1, b1
    assert not chainEquals b1, a1
  
  it "should compare chains of length 2 and more", ->

    a1b1 = new NodeA(1, new NodeB(1, unity))
    a1b2 = new NodeA(1, new NodeB(2, unity))
    a1b1a3 = new NodeA(1, new NodeB(1, new NodeA(3, unity)))
    
    assert chainEquals a1b1, a1b1
    assert not chainEquals a1b1, a1b2
    assert not chainEquals a1b1, a1b1a3
    assert not chainEquals a1b1, unity
  
describe "nodeHash", ->
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
      assert isNumber nodeHash c

    for c1, i in chains
      for c2, j in chains
        if i isnt j
          assert.notEqual nodeHash(c1), nodeHash(c2), "H #{showNode c1} != H #{showNode c2}"

  
describe "showNode", ->
  it "should convert node to text", ->
    assert.equal 'e', showNode unity
    assert.equal 'a', showNode newNode 'a', 1, unity
    assert.equal 'A', showNode newNode 'a', -1, unity
    assert.equal 'b', showNode newNode 'b', 1, unity
    assert.equal 'B', showNode newNode 'b', -1, unity
    assert.equal 'a^3', showNode newNode 'a', 3, unity
    assert.equal 'Aba^3', showNode newNode 'a', 3, newNode 'b',1, newNode 'a', -1, unity
    
describe "parseNode", ->
  it "should convert node to text", ->
    assert.ok chainEquals parseNode('e'), unity
    assert.ok chainEquals parseNode('a'), newNode 'a', 1, unity
    assert.ok chainEquals parseNode('A'), newNode 'a', -1, unity
    assert.ok chainEquals parseNode('b'), newNode 'b', 1, unity
    assert.ok chainEquals parseNode('B'), newNode 'b', -1, unity
    assert.ok chainEquals parseNode('a^3'), newNode 'a', 3, unity
    assert.ok chainEquals parseNode('Aba^3'), newNode 'a', 3, newNode 'b',1, newNode 'a', -1, unity
    


describe "nodeMatrixRepr", ->
  group = new CenteredVonDyck 4, 5
  
  it "should return unity matrix for empty node", ->
    assert M.approxEq nodeMatrixRepr(unity, group), M.eye()

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

describe "inverseChain", ->
  n = 5
  m = 4
  rewriteRuleset = knuthBendix vdRule n, m
  appendRewrite = makeAppendRewrite rewriteRuleset
  
  it "should inverse unity", ->
    assert chainEquals unity, inverseChain(unity, appendRewrite)
  it "should inverse simple 1-element values", ->
    c = newNode 'a', 1, unity
    ic = newNode 'a', -1, unity
    assert chainEquals inverseChain(c, appendRewrite), ic


  it "should return same chain after double rewrite", ->

    c = appendRewrite unity, [['b',1],['a',2],['b',-2],['a',3],['b',1]]
    ic = inverseChain c, appendRewrite
    iic = inverseChain ic, appendRewrite

    assert chainEquals c, iic

describe "appendInverseChain", ->
  n = 5
  m = 4
  rewriteRuleset = knuthBendix vdRule n, m
  appendRewrite = makeAppendRewrite rewriteRuleset
  
  it "unity * unity^-1 = unity", ->
    assert chainEquals unity, appendInverseChain(unity, unity, appendRewrite)
    
  it "For simple 1-element values, x * (x^-1) = unity", ->
    c = newNode 'a', 1, unity
    assert chainEquals appendInverseChain(c, c, appendRewrite), unity


  it "For non-simple chain, x*(x^-1) = unitu", ->
    c = appendRewrite unity, [['b',1],['a',2],['b',-2],['a',3],['b',1]]
    assert appendInverseChain(c, c, appendRewrite), unity


describe "appendChain", ->
  n = 5
  m = 4
  rewriteRuleset = knuthBendix vdRule n, m
  appendRewrite = makeAppendRewrite rewriteRuleset
  

  it "choud append unity", ->
    assert chainEquals unity, appendChain(unity, unity, appendRewrite)

    c = newNode 'a', 1, unity
    assert chainEquals c, appendChain(c, unity, appendRewrite)
    assert chainEquals c, appendChain(unity, c, appendRewrite)

  it "shouls append inverse and return unity", ->

    c = appendRewrite unity, [['b',1],['a',2],['b',-2],['a',3],['b',1]]

    ic = inverseChain c, appendRewrite

    assert chainEquals unity, appendChain c, ic, appendRewrite
    assert chainEquals unity, appendChain ic, c, appendRewrite    

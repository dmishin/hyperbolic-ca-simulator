assert = require "assert"
{RewriteRuleset} = require  "./knuth_bendix.coffee"
{string2chain, chain2string, makeAppendRewriteRef, makeAppendRewrite, extendLastPowerRewriteTable} = require "./vondyck_rewriter.coffee"
{unity, chainEquals, newNode, showNode} = require "./vondyck_chain.coffee"

describe "string2chain", ->
  it "must convert empty string", ->
    assert.equal unity, string2chain ""

  it "must convert  nonempty strings", ->
    assert chainEquals string2chain("a"), newNode('a', 1, unity) 
    assert chainEquals string2chain("A"), newNode('a', -1, unity) 
    assert chainEquals string2chain("aa"), newNode('a', 2, unity) 
    assert chainEquals string2chain("AA"), newNode('a', -2, unity) 

  it "must convert complex chains", ->
    assert chainEquals 



describe "chain2string", ->
  it "must convert empty chain", ->
    assert.equal chain2string(unity), ""
  it "must convert simple nonempty chain", ->
    assert.equal chain2string(newNode('a', 2, unity)), "aa"
    assert.equal chain2string(newNode('a', -3, unity)), "AAA"
    assert.equal chain2string(newNode('b', 1, unity)), "b"

  it "must convert complex nonempty chain", ->
    c = newNode('a', -1, newNode('b', -3, newNode('a', 2, unity)))
    assert.equal chain2string(c), "aaBBBA"


describe "Compiled rewriter", ->
  rewriteTable = new RewriteRuleset {
     aaBaa: 'AAbAA'
     ABaBA: 'bAAb'
     bb: 'BB'
     bAB: 'BBa'
     aaa: 'AA'
     AAA: 'aa'
     ab: 'BA'
     aBB: 'BAb'
     ba: 'AB'
     Bb: ''
     bB: ''
     Aa: ''
     aA: ''
     BBB: 'b'
     BAB: 'a'
     ABA: 'b'
     aaBA: 'AAb'
     ABaa: 'bAA'
     aaBaBA: 'AAbAAb'
     bAAbAA: 'ABaBaa' }
  n=5
  m=4


  refRewriter = makeAppendRewriteRef rewriteTable
  compiledRewriter = makeAppendRewrite rewriteTable

  doTest = ( stack, chain0=unity ) ->
    #console.log "should stringify #{JSON.stringify stack}"
    #console.log "#{showNode chainRef} != #{showNode chain}"
    chainRef = refRewriter chain0, stack[..]
    chain = compiledRewriter chain0, stack[..]
    assert chainEquals(chainRef, chain), "#{showNode chain0} ++ #{JSON.stringify stack} -> #{showNode chainRef} (ref) != #{showNode chain}"
    return

  walkChains = (stack, depth, callback) ->
    callback stack
    for a in [1...n]
      stack.push ['a',a]
      callback stack
      
      for b in [1...m]
        stack.push ['b', b]
        callback stack
        if depth > 0
          walkChains stack, depth-1, callback
        stack.pop()
      stack.pop()
    return
    
  #it "must produce same result as reference rewriter", ->
  #  walkChains [], 3, doTest
  #chain = ba^-2b, stack: [["a",1]], refValue: a^-1b^-1ab^-1, value: ba^2b^-1
  doTest [["a",1]], newNode('b',1, newNode('a',-2, newNode('b',1,unity)))

describe "extendLastPowerRewriteTable", ->    
  it "must extend positive powers", ->
    r = new RewriteRuleset { 'ab': 'Ba', 'ba': 'B' }
    r1 = extendLastPowerRewriteTable r.copy(), 'a', -3, 3
    
    r1_expected = new RewriteRuleset
      'ab': 'Ba',
      'ba': 'B',
      #new ruels:
      'baa': 'Ba',
      'baaa': 'Baa'

    assert not r.equals(r1), "Extended ruleset is not equal to original, #{JSON.stringify r1} != #{JSON.stringify r}"
    assert r1.equals(r1_expected), "Extended ruleset is equal to expected, #{JSON.stringify r1} != #{JSON.stringify r1_expected}"

  it "must extend negative powers", ->
    r = new RewriteRuleset { 'ab': 'Ba', 'bA': 'B' }
    r1 = extendLastPowerRewriteTable r.copy(), 'a', -3, 3
    
    r1_expected = new RewriteRuleset
      'ab': 'Ba',
      'bA': 'B',
      #new ruels:
      'bAA': 'BA',
      'bAAA': 'BAA'

    assert not r.equals(r1), "Extended ruleset is not equal to original, #{JSON.stringify r1} != #{JSON.stringify r}"
    assert r1.equals(r1_expected), "Extended ruleset is equal to expected, #{JSON.stringify r1} != #{JSON.stringify r1_expected}"

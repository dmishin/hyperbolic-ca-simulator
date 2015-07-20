assert = require "assert"
{RewriteRuleset} = require  "./knuth_bendix.coffee"
{string2chain, chain2string, makeAppendRewriteRef, makeAppendRewrite} = require "./vondyck_rewriter.coffee"
{chainEquals, newNode, showNode} = require "./vondyck_chain.coffee"

describe "string2chain", ->
  it "must convert empty string", ->
    assert.equal null, string2chain ""

  it "must convert  nonempty strings", ->
    assert chainEquals string2chain("a"), newNode('a', 1, null) 
    assert chainEquals string2chain("A"), newNode('a', -1, null) 
    assert chainEquals string2chain("aa"), newNode('a', 2, null) 
    assert chainEquals string2chain("AA"), newNode('a', -2, null) 

  it "must convert complex chains", ->
    assert chainEquals 



describe "chain2string", ->
  it "must convert empty chain", ->
    assert.equal chain2string(null), ""
  it "must convert simple nonempty chain", ->
    assert.equal chain2string(newNode('a', 2, null)), "aa"
    assert.equal chain2string(newNode('a', -3, null)), "AAA"
    assert.equal chain2string(newNode('b', 1, null)), "b"

  it "must convert complex nonempty chain", ->
    c = newNode('a', -1, newNode('b', -3, newNode('a', 2, null)))
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

  doTest = ( stack ) ->
    #console.log "should stringify #{JSON.stringify stack}"
    #console.log "#{showNode chainRef} != #{showNode chain}"
    chainRef = refRewriter null, stack[..]
    chain = compiledRewriter null, stack[..]
    assert chainEquals(chainRef, chain), "AR('', #{JSON.stringify stack}) -> #{showNode chainRef} (ref) != #{showNode chain}"
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
    
  it "must produce same result as reference rewriter", ->
    walkChains [], 3, doTest
    
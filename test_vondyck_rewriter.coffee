assert = require "assert"

{string2chain, chain2string} = require "./vondyck_rewriter.coffee"
{chainEquals, newNode} = require "./vondyck_chain.coffee"

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


    
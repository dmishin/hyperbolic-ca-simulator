
assert = require "assert"
{allClusters} = require "./field"
{makeAppendRewrite, vdRule, eliminateFinalA} = require "./vondyck_rewriter.coffee"
{NodeHashMap, nodeMatrixRepr, newNode, showNode, chainEquals, nodeHash, node2array} = require "./vondyck_chain.coffee"
{RewriteRuleset, knuthBendix} = require "./knuth_bendix.coffee"

describe "allClusters", ->

  #prepare data: rewriting ruleset for group 5;4
  #
  [N, M] = [5, 4]
  rewriteRuleset = knuthBendix vdRule N, M
  appendRewrite = makeAppendRewrite rewriteRuleset

  
  it "should give one cell, if only one central cell present", ->
    cells = new NodeHashMap
    cells.put null, 1
    clusters = allClusters cells, N, M, appendRewrite
    assert.equal clusters.length, 1
    assert.deepEqual clusters, [[null]] #one cluster of 1 cell

  it "should give one cell, if only one central cell present", ->
    cells = new NodeHashMap
    c = newNode 'a', 2, newNode 'b', 2, newNode 'a', -1, null
    c = eliminateFinalA c, appendRewrite, N
    
    cells.put c, 1
    clusters = allClusters cells, N, M, appendRewrite
    assert.equal clusters.length, 1
    assert.deepEqual clusters[0].length, 1

    assert chainEquals(clusters[0][0], c)


assert = require "assert"
{allClusters, mooreNeighborhood, exportField, importField} = require "./field"
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

describe "mooreNeighborhood", ->
  #prepare data: rewriting ruleset for group 5;4
  #
  [N, M] = [5, 4]
  rewriteRuleset = knuthBendix vdRule N, M
  appendRewrite = makeAppendRewrite rewriteRuleset


  getNeighbors = mooreNeighborhood N, M, appendRewrite
  eliminate = (chain)-> eliminateFinalA chain, appendRewrite, N
  rewriteChain = (arr) -> appendRewrite null, arr[..]
  
  cells = []
  cells.push  null
  cells.push  eliminate rewriteChain [['b',1]]
  cells.push  eliminate rewriteChain [['b', 2]]
  cells.push  eliminate rewriteChain [['b', 2],['a', 1]]
  
  it "must return expected number of cells different from origin", ->
    for cell in cells
      neighbors = getNeighbors cell
      assert.equal neighbors.length, N*(M-2)

      for nei, i in neighbors
        assert not chainEquals(cell, nei)

        for nei1, j in neighbors
          if i isnt j
            assert not chainEquals(nei, nei1), "neighbors #{i}=#{showNode nei1} and #{j}=#{showNode nei1} must be not equal"
    return
    
  it "must be true that one of neighbor's neighbor is self", ->
    for cell in cells
      for nei in getNeighbors cell
        foundCell = 0
        for nei1 in getNeighbors nei
          if chainEquals nei1, cell
            foundCell += 1
        assert.equal foundCell, 1, "Exactly 1 of the #{showNode nei}'s neighbors must be original chain: #{showNode cell}, but #{foundCell} found"
    return

describe "exportField", ->
  it "must export empty field", ->
    f = new NodeHashMap
    tree = exportField f
    assert.deepEqual tree, {}
    
  it "must export field with only root cell", ->
    f = new NodeHashMap
    f.put null, 1
    tree = exportField f
    assert.deepEqual tree, {v: 1}
    
  it "must export field with 1 non-root cell", ->
    f = new NodeHashMap
    #ab^3a^2
    chain = newNode 'a', 2, newNode 'b', 3, newNode 'a',1, null
    f.put chain, "value"
    tree = exportField f
    assert.deepEqual tree, {
      cs:[{
        a: 1
        cs: [{
          b: 3
          cs: [{
            a: 2
            v: "value"
    }]}]}]}
    
describe "importField", ->
  it "must import empty field correctly", ->
    f = importField {}
    assert.equal f.count, 0
  it "must import root cell correctly", ->
    f = importField {v: 1}
    assert.equal f.count, 1
    assert.equal f.get(null), 1
  it "must import 1 non-root cell correctly", ->
    tree = {
      cs:[{
        a: 1
        cs: [{
          b: 3
          cs: [{
            a: 2
            v: "value"
    }]}]}]}
    #ab^3a^2
    chain = newNode 'a', 2, newNode 'b', 3, newNode 'a',1, null
    f = importField tree
    assert.equal f.count, 1
    assert.equal f.get(chain), 'value'
    
  
  it "must import some nontrivial exported field", ->
    f = new NodeHashMap
    #ab^3a^2
    chain1 = newNode 'a', 2, newNode 'b', 3, newNode 'a',1, null
    #a^-1b^3a^2
    chain2 = newNode 'a', -1, newNode 'b', 3, newNode 'a',1, null
    f.put null, "value0"
    f.put chain1, "value1"
    f.put chain2, "value2"
      

    f1 = importField exportField f

    assert.equal f.count, 3
    assert.equal f.get(null), 'value0'
    assert.equal f.get(chain1), 'value1'
    assert.equal f.get(chain2), 'value2'
    
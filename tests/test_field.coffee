
assert = require "assert"
{allClusters, exportField, importField, mooreNeighborhood, neighborsSum, parseFieldData, randomStateGenerator, stringifyFieldData, forFarNeighborhood, randomFillFixedNum} = require "../src/core/field"
{makeAppendRewrite, vdRule, eliminateFinalA} = require "../src/core/vondyck_rewriter.coffee"
{unity, nodeMatrixRepr, newNode, showNode, nodeHash, node2array} = require "../src/core/vondyck_chain.coffee"
{NodeHashMap} = require "../src/core/chain_map.coffee"
{RewriteRuleset, knuthBendix} = require "../src/core/knuth_bendix.coffee"

describe "allClusters", ->

  #prepare data: rewriting ruleset for group 5;4
  #
  [N, M] = [5, 4]
  rewriteRuleset = knuthBendix vdRule N, M
  appendRewrite = makeAppendRewrite rewriteRuleset

  
  it "should give one cell, if only one central cell present", ->
    cells = new NodeHashMap
    cells.put unity, 1
    clusters = allClusters cells, N, M, appendRewrite
    assert.equal clusters.length, 1
    assert.deepEqual clusters, [[unity]] #one cluster of 1 cell

  it "should give one cell, if only one central cell present", ->
    cells = new NodeHashMap
    c = newNode 'a', 2, newNode 'b', 2, newNode 'a', -1, unity
    c = eliminateFinalA c, appendRewrite, N
    
    cells.put c, 1
    clusters = allClusters cells, N, M, appendRewrite
    assert.equal clusters.length, 1
    assert.deepEqual clusters[0].length, 1

    assert clusters[0][0].equals c


describe "exportField", ->
  it "must export empty field", ->
    f = new NodeHashMap
    tree = exportField f
    assert.deepEqual tree, {}
    
  it "must export field with only root cell", ->
    f = new NodeHashMap
    f.put unity, 1
    tree = exportField f
    assert.deepEqual tree, {v: 1}
    
  it "must export field with 1 non-root cell", ->
    f = new NodeHashMap
    #ab^3a^2
    chain = newNode 'a', 2, newNode 'b', 3, newNode 'a',1, unity
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

describe "randomStateGenerator", ->
  makeStates = (nStates, nValues) ->
    gen = randomStateGenerator nStates
    (gen() for _ in [0...nValues])
    
  it "must produce random values in required range", ->
    states = makeStates 5, 1000
    assert.equal states.length, 1000
    #should for sure contain at least one of values 1,2,3,4
    #should not contain 0
    #should not contain >=5
    counts = [0,0,0,0,0]
    for x in states
      counts[x] += 1
    assert.equal counts[0],  0      
    assert(counts[1] > 0)
    assert(counts[2] > 0)
    assert(counts[3] > 0)
    assert(counts[4] > 0)
    assert.equal counts[1]+counts[2]+counts[3]+counts[4], 1000
    
describe "stringifyFieldData", ->
  it "must stringify empty", ->
    f = {}
    assert.equal stringifyFieldData(f), ""
  it "must cell at origin", ->
    f = {v:1}
    assert.equal stringifyFieldData(f), "|1"
  it "must other cells", ->
    f ={
      v:1
      cs: [
        {
          a:1
          v:2
        },{
          a:-2
          v:3
    }]}
    assert.equal stringifyFieldData(f), "|1(a|2)(A2|3)"

describe "parseFieldData", ->
  it "must parse empty string", ->
    f = parseFieldData ""
    assert.deepEqual f, {}
  it "must parse cell at origin", ->
    f = parseFieldData "|1"
    assert.deepEqual f, {v:1}
  it "must parse non-trivial", ->
    tree = {
      cs:[{
        a: 1
        cs: [{
          b: -3
          cs: [{
            a: 2
            v: 1
    }]}]}]}
    f = parseFieldData "(a(B3(a2|1)))"
    assert.deepEqual f, tree
    

describe "importField", ->
  it "must import empty field correctly", ->
    f = importField {}
    assert.equal f.count, 0
  it "must import root cell correctly", ->
    f = importField {v: 1}
    assert.equal f.count, 1
    assert.equal f.get(unity), 1
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
    chain = newNode 'a', 2, newNode 'b', 3, newNode 'a',1, unity
    f = importField tree
    assert.equal f.count, 1
    assert.equal f.get(chain), 'value'
    
  
  it "must import some nontrivial exported field", ->
    f = new NodeHashMap
    #ab^3a^2
    chain1 = newNode 'a', 2, newNode 'b', 3, newNode 'a',1, unity
    #a^-1b^3a^2
    chain2 = newNode 'a', -1, newNode 'b', 3, newNode 'a',1, unity
    f.put unity, "value0"
    f.put chain1, "value1"
    f.put chain2, "value2"
      

    f1 = importField exportField f

    assert.equal f1.count, 3
    assert.equal f1.get(unity), 'value0'
    assert.equal f1.get(chain1), 'value1'
    assert.equal f1.get(chain2), 'value2'
    
  it "must support preprocessing imported data", ->
    f = new NodeHashMap
    #ab^3a^2
    chain1 = newNode 'a', 2, newNode 'b', 3, newNode 'a',1, unity
    #a^-1b^3a^2
    chain2 = newNode 'a', -1, newNode 'b', 3, newNode 'a',1, unity
    f.put unity, "value0"
    f.put chain1, "value1"
    f.put chain2, "value2"

    #Preprocessor simply appends b^2 to the chain
    preprocessor = (chain) -> newNode 'b', 2, chain

    f1 = importField exportField(f), null, preprocessor
    
    assert.equal f1.count, 3
    assert.equal 'value0', f1.get(newNode 'b', 2, unity), 
    assert.equal 'value1', f1.get(newNode 'b', 2, newNode 'a', 2, newNode 'b', 3, newNode 'a',1, unity) 
    assert.equal 'value2', f1.get(newNode 'b', 2, newNode 'a', -1, newNode 'b', 3, newNode 'a',1, unity)
    


describe "randomFillFixedNum", ->
  it "must fill some reasonable number of cells", ->
    [N, M] = [5, 4]
    rewriteRuleset = knuthBendix vdRule N, M
    appendRewrite = makeAppendRewrite rewriteRuleset

    field = new NodeHashMap

    nCells = 10000
    randomFillFixedNum field, 0.4, unity, 10000, appendRewrite, N, M

    #not guaranteed, but chances of failure are small.
    assert.ok field.count > 0.4*nCells*0.7
    assert.ok field.count < 0.4*nCells*1.3

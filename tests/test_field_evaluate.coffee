assert = require "assert"
{allClusters, exportField, importField, mooreNeighborhood, neighborsSum, parseFieldData, randomStateGenerator, stringifyFieldData, evaluateTotalisticAutomaton} = require "../field.coffee"
{makeAppendRewrite, vdRule, eliminateFinalA} = require "../vondyck_rewriter.coffee"
{unity, NodeHashMap, nodeMatrixRepr, newNode, showNode, chainEquals, nodeHash, node2array} = require "../vondyck_chain.coffee"
{RewriteRuleset, knuthBendix} = require "../knuth_bendix.coffee"


describe "evaluateTotalisticAutomaton", ->

  it "must persist single cell in rule B 3 S 0 2 3", ->
    
    ruleNext = (x,s) ->
      if x is 0
        if s is 3 then 1 else 0
      else if x is 1
        if s in [0,2,3] then 1 else 0

    [N, M] = [7, 3]
    rewriteRuleset = knuthBendix vdRule N, M
    appendRewrite = makeAppendRewrite rewriteRuleset
    getNeighbors = mooreNeighborhood N, M, appendRewrite
    
    #prepare field with only one cell
    field = new NodeHashMap
    field.put unity, 1

    field1 = evaluateTotalisticAutomaton field, getNeighbors, ruleNext

    #now check the field
    assert.equal field1.count, 1
    assert.equal field1.get(unity), 1

  it "must NOT persist single cell in rule B 3 S 2 3", ->
    
    ruleNext = (x,s) ->
      if x is 0
        if s is 3 then 1 else 0
      else if x is 1
        if s in [2,3] then 1 else 0
      else throw new Error("bad state #{x}")

    [N, M] = [7, 3]
    rewriteRuleset = knuthBendix vdRule N, M
    appendRewrite = makeAppendRewrite rewriteRuleset
    getNeighbors = mooreNeighborhood N, M, appendRewrite
    
    #prepare field with only one cell
    field = new NodeHashMap
    field.put unity, 1

    field1 = evaluateTotalisticAutomaton field, getNeighbors, ruleNext

    #now check the field
    assert.equal field1.count, 0
    assert.equal field1.get(unity), null

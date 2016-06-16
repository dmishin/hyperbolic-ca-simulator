assert = require "assert"
{allClusters, exportField, importField, parseFieldData, randomStateGenerator, stringifyFieldData} = require "../src/core/field.coffee"
{NodeHashMap} = require "../src/core/chain_map.coffee"
{RegularTiling} = require "../src/core/regular_tiling.coffee"

{neighborsSum, evaluateTotalisticAutomaton}  = require "../src/core/cellular_automata.coffee"

describe "evaluateTotalisticAutomaton", ->

  it "must persist single cell in rule B 3 S 0 2 3", ->
    
    ruleNext = (x,s) ->
      if x is 0
        if s is 3 then 1 else 0
      else if x is 1
        if s in [0,2,3] then 1 else 0

    [N, M] = [7, 3]
    tiling = new RegularTiling N, M
    unity = tiling.unity
    
    #prepare field with only one cell
    field = new NodeHashMap
    field.put unity, 1

    field1 = evaluateTotalisticAutomaton field, tiling, ruleNext

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
    tiling = new RegularTiling N, M
    
    #prepare field with only one cell
    field = new NodeHashMap
    field.put tiling.unity, 1

    field1 = evaluateTotalisticAutomaton field, tiling, ruleNext

    #now check the field
    assert.equal field1.count, 0
    assert.equal field1.get(tiling.unity), null

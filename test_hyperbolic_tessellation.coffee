assert = require "assert"

{Tessellation} = require "./hyperbolic_tessellation.coffee"
{nodeMatrixRepr, newNode} = require "./vondyck_chain.coffee"

describe "Tessellation.visiblePolygonSize", ->

  T = new Tessellation 5, 4

  pathSize = (chain) -> T.visiblePolygonSize nodeMatrixRepr(chain, T.group)
  
  it "must be positive, nonzero", ->
    assert 0 < pathSize null
    assert 0 < pathSize newNode 'a', 1, null
    assert 0 < pathSize newNode 'b', 1, null

  it "must decrease when distance is increasing", ->
    
    size_0 = pathSize null
    size_b1 = pathSize newNode 'b', 1, null

    assert size_b1 < size_0
        
    
  it "must not change only from rotation of the polygon", ->
    
    size_0 = pathSize null
    size_a1 =  pathSize newNode 'a', 1, null

    assert Math.abs(size_a1 - size_0) < 1e-3
        
    

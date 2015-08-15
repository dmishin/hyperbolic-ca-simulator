assert = require "assert"

{Tessellation} = require "./hyperbolic_tessellation.coffee"
{unity, nodeMatrixRepr, newNode} = require "./vondyck_chain.coffee"

describe "Tessellation.visiblePolygonSize", ->

  T = new Tessellation 5, 4

  pathSize = (chain) -> T.visiblePolygonSize nodeMatrixRepr(chain, T.group)
  
  it "must be positive, nonzero", ->
    assert 0 < pathSize unity
    assert 0 < pathSize newNode 'a', 1, unity
    assert 0 < pathSize newNode 'b', 1, unity

  it "must decrease when distance is increasing", ->
    
    size_0 = pathSize unity
    size_b1 = pathSize newNode 'b', 1, unity

    assert size_b1 < size_0
        
    
  it "must not change only from rotation of the polygon", ->
    
    size_0 = pathSize unity
    size_a1 =  pathSize newNode 'a', 1, unity

    assert Math.abs(size_a1 - size_0) < 1e-3
        
    

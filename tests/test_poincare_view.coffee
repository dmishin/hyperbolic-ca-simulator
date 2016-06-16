assert = require "assert"

{RegularTiling} = require "../src/core/regular_tiling.coffee"
#{unity} = require "../src/core/vondyck_chain.coffee"
{visiblePolygonSize} = require "../src/core/poincare_view.coffee"

describe "visiblePolygonSize", ->

  tiling = new RegularTiling 5, 4
  
  cellPolygonSize = (chain) ->
    visiblePolygonSize tiling, tiling.repr(chain)
  
  it "must be positive, nonzero", ->
    assert 0 < cellPolygonSize tiling.unity
    assert 0 < cellPolygonSize tiling.parse "a"
    assert 0 < cellPolygonSize tiling.parse "b"

  it "must decrease when distance is increasing", ->
    
    size_0 = cellPolygonSize tiling.unity
    size_b1 = cellPolygonSize tiling.parse "b"

    assert size_b1 < size_0
        
    
  it "must not change only from rotation of the polygon", ->
    
    size_0 = cellPolygonSize tiling.unity
    size_a1 =  cellPolygonSize tiling.parse "a"

    assert Math.abs(size_a1 - size_0) < 1e-3
        
    

assert = require "assert"

{fminsearch} = require "../src/fminsearch"


near = (x, y, eps=1e-5) -> Math.abs(x-y)<eps

describe "fminsearch", ->
  it "should find minimum of function of one argument (x-1)^2", ->
    f = ([x]) -> (x-1)**2

    res = fminsearch f, [0,0], 0.1
    assert.ok res.reached
    assert.ok near res.x[0], 1.0
    
  it "should find minimum of (x-1)^2 + (y-1)^2", ->

    f = ([x,y]) -> (x-1)**2 + (y-2)**2

    res = fminsearch f, [0,0], 0.1
    #console.log "solved:"
    #console.dir res
    assert.ok res.reached
    assert.ok near res.x[0], 1.0
    assert.ok near res.x[1], 2.0
    
  it "should find minimum of function of 4 arguments: (x-1)^2 + (y-1)^2 + (z-3)^2 + (t-4)^4", ->
    f = ([x,y,z,t]) -> (x-1)**2 + (y-2)**2 + (z-3)**2 + (t-4)**4

    res = fminsearch f, [0,0,0,0], 0.1
    #console.log "solved:"
    #console.dir res
    assert.ok res.reached
    assert.ok near res.x[0], 1.0
    assert.ok near res.x[1], 2.0
    assert.ok near res.x[2], 3.0
    assert.ok near res.x[3], 4.0
    
  it "should find minimum of the rozenbrock function, (1-x)**2 + 100*(y-x**2)**2", ->
    f = ([x,y]) -> (1-x)**2 + 100*(y-x**2)**2

    res = fminsearch f, [0,0], 0.1
    #console.log "solved:"
    #console.dir res
    assert.ok res.reached
    assert.ok near res.x[0], 1.0
    assert.ok near res.x[1], 1.0

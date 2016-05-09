assert = require "assert"
M = require "../src/matrix3"
{realeig} = require "../src/realjordan"

near = (x,y,eps=1e-5) -> Math.abs(x-y)<eps

describe "realeig", ->
  it "msut find eigenvalues of identity matrix", ->
    eigs = realeig M.eye()
    assert.ok near eigs[0], 1.0
    assert.ok near eigs[1], 1.0
    assert.ok near eigs[2], 1.0
    

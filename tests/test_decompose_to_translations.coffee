assert = require "assert"
M = require "../src/matrix3"
{decomposeToTranslations} = require "../src/decompose_to_translations"

describe "decomposeToTranslations", ->
  it "must decompose unity matrix to itself", ->
    [t1,t2] = decomposeToTranslations M.eye()
    #console.log "Found:"
    #console.dir t1
    #console.dir t2
    
    assert.ok t1?
    assert.ok M.approxEq t1, M.eye()
    assert.ok t2?
    assert.ok M.approxEq t2, M.eye()

  it "must decompose translation matrix to itself and unity", ->
    t = M.translationMatrix 2, 3
    
    [t1,t2] = decomposeToTranslations t
    #console.log "Found:"
    #console.dir t1
    #console.dir t2
    
    assert.ok t1?
    assert.ok M.approxEq t1, M.eye()
    assert.ok t2?
    assert.ok M.approxEq t2, t

  it "must not decompose pure rotation matrix", ->
    t = M.rotationMatrix 0.4
    
    [t1,t2] = decomposeToTranslations t
    #console.log "Found:"
    #console.dir t1
    #console.dir t2
    
    assert.ok t1 is null
    assert.ok t2 is null

  it "must decompose some matrix", ->
    t = M.mul M.rotationMatrix(0.3), M.translationMatrix 2, 3
    
    [t1,t2] = decomposeToTranslations t
    #console.log "Found:"
    #console.dir t1
    #console.dir t2
    
    assert.ok t1?
    assert.ok t2?

    tRestored = M.mul M.hyperbolicInv(t1), M.mul t2, t1
    #console.log "restored"
    #console.dir tRestored
    #console.log "original"
    #console.dir t

    assert.ok M.approxEq tRestored, t, 1e-5

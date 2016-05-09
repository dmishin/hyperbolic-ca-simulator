assert = require "assert"
M = require "../src/matrix3"
{decomposeToTranslations, decomposeToTranslationsAggresively} = require "../src/decompose_to_translations"

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
    
    assert.ok t1?
    assert.ok t2?

    tRestored = M.mul M.hyperbolicInv(t1), M.mul t2, t1
    assert.ok M.approxEq tRestored, t, 1e-5
    
  it "must decompose some hard matrix", ->
    t = [5.58512230547673, -4.886985710846093, 7.3536535480771485,
         12.220681374785933, -7.783877858381329, 14.454542807651823,
         13.399203126722638, -9.136267501130483, 16.248385405429882]
    
    [t1,t2] = decomposeToTranslations t
    
    assert.ok t1?
    assert.ok t2?

    tRestored = M.mul M.hyperbolicInv(t1), M.mul t2, t1
    assert.ok M.approxEq tRestored, t, 1e-4

# describe "decomposeToTranslationsAggresively", ->
#   it "must decompose high-amplitude matrix", ->

#     #Obtained from practice. decmposition possible, but hard
#     m = [5.58512230547673, -4.886985710846093, 7.3536535480771485,
#          12.220681374785933, -7.783877858381329, 14.454542807651823,
#          13.399203126722638, -9.136267501130483, 16.248385405429882]
  
    
#     [t1,t2] = decomposeToTranslationsAggresively m
#     assert.ok t1?
#     assert.ok t2?
    
#     tRestored = M.mul M.hyperbolicInv(t1), M.mul t2, t1
#     console.log "restored"
#     console.dir tRestored
#     console.log "original"
#     console.dir t

#     assert.ok M.approxEq tRestored, t, 1e-5
    

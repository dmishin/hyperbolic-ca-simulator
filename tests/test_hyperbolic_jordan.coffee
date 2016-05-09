assert = require "assert"
M = require "../src/matrix3"
{hyperbolicRealEig, hyperbolicRealJordan} = require "../src/hyperbolic_jordan"

near = (x,y,eps=1e-5) -> Math.abs(x-y)<eps


describe "hyperbolicRealEig", ->
  it "msut find eigenvalues of identity matrix", ->
    eigs = hyperbolicRealEig M.eye()
    assert.ok near eigs[0], 1.0
    assert.ok near eigs[1], 1.0
    assert.ok near eigs[2], 1.0
    
  it "msut find eigenvalues of pure translation matrix", ->
    eigs = hyperbolicRealEig M.translationMatrix 2, 3

    #console.log "Eigens:"
    #console.dir eigs
    #console.dir "Expect: #{Math.exp(Math.sqrt(2**2+3**2))}"


    d = Math.acosh(Math.sqrt(2**2+3**2 + 1))
    assert.ok near eigs[0], 1.0
    assert.ok near eigs[1], Math.exp( d)
    assert.ok near eigs[2], Math.exp(-d)    


  it "must detect rptation matrix as non-decomposable", ->
    eigs = hyperbolicRealEig M.rotationMatrix 0.7
    assert.ok eigs is null




describe "hyperbolicRealJordan", ->
  it "must decompose identity matrix", ->
    [V,D] = hyperbolicRealJordan M.eye()
    assert.ok M.approxEq V, M.eye()
    assert.ok M.approxEq D, M.eye()

  it "must decompose translation matrix", ->
    m = M.translationMatrix 2, 0
    d = Math.acosh( Math.sqrt(2**2 + 1))
    
    [V,D] = hyperbolicRealJordan m


    Vexp = [0,1,1,
            1,0,0,
            0,1,-1]
            
    Dexp = [1,0,0,
            0,Math.exp(d),0,
            0,0,Math.exp(-d)]

    # console.log "===========\nV matrix, actual then expected"
    # console.dir V
    # console.dir Vexp
    # console.log "===========\nD matrix, actual then expected"
    # console.dir D
    # console.dir Dexp
          
    assert.ok M.approxEq V, Vexp
    assert.ok M.approxEq D, Dexp
        
  
  it "must decompose directioned translation matrix", ->
    m = M.translationMatrix 2, 3
    d = Math.acosh( Math.sqrt(2**2 + 3**2 + 1))
    
    [V,D] = hyperbolicRealJordan m


    restored = M.mul V, M.mul(D, M.inv V)


    Dexp = [1,0,0,
            0,Math.exp(d),0,
            0,0,Math.exp(-d)]

    # console.log "===========\nV matrix, actual then expected"
    # console.dir V
    # console.dir Vexp
    # console.log "===========\nD matrix, actual then expected"
    # console.dir D
    # console.dir Dexp
          
    assert.ok M.approxEq m, restored
    assert.ok M.approxEq D, Dexp
        
  

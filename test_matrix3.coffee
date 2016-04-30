assert = require "assert"

M = require "./matrix3"

describe "approxEq", ->
  it "must return true for equal matrices", ->
    assert.ok M.approxEq [0,0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0,0]

  it "must return false for significantly in equal matrices", ->
    m1 = [0,0,0,0,0,0,0,0,0]
    for i in [0...9]
      m2 = [0,0,0,0,0,0,0,0,0]
      m2[i] = 1.0
      assert.ok not M.approxEq m1, m2
      

describe "eye", ->
  it "msut equal unit matrix", ->
    m = (0.0 for i in [0...9])
    
    for i in [0...3]
      M.set m, i, i, 1.0

    assert.ok M.approxEq(m, M.eye())

describe "mul", ->
  it "must multiply eye to itself", ->
    assert.ok M.approxEq M.eye(), M.mul(M.eye(), M.eye())

  it "must return same non-eye matrix, if multiplied with eye", ->
    m = (i for i in [0...9])

    assert.ok M.approxEq m, M.mul(m, M.eye())
    assert.ok M.approxEq m, M.mul(M.eye(), m)

  it "must change non-eye matrix if squared", ->
    m = (i for i in [0...9])
    assert.ok not M.approxEq m, M.mul(m, m)


describe "rot", ->
  it "must return eye if rotation angle is 0", ->
    assert.ok M.approxEq M.eye(), M.rot(0,1,0.0)
    assert.ok M.approxEq M.eye(), M.rot(0,2,0.0)
    assert.ok M.approxEq M.eye(), M.rot(1,2,0.0)
  it "must return non-eye if rotation angle is not 0", ->
    assert.ok not M.approxEq M.eye(), M.rot(0,1,1.0)


describe "smul", ->
  it "must return 0 if multiplied by 0", ->
    assert.ok M.approxEq M.zero(), M.smul( 0.0, M.eye())

  it "must return same if multiplied by 1", ->
    assert.ok M.approxEq M.eye(), M.smul( 1.0, M.eye())

describe "translationMatrix", ->
  it "must return unity for zero translation", ->
    assert.ok M.approxEq M.eye(), M.translationMatrix(0,0)
  it "must return almost unity for very small translation", ->
    assert.ok M.approxEq M.eye(), M.translationMatrix(1e-5,1e-5), 1e-4

  it "must return matrix that correctly translates zero", ->
    T = M.translationMatrix 5,6
    zero = [0,0,1]
    expect = [5, 6, Math.sqrt(5**2+6**2+1)]
    assert.ok M.approxEqv expect, M.mulv(T,zero)

describe "addScaledInplace", ->
  it "must modify matrix inplace", ->
    m = M.eye()
    m1 = [1,1,1, 1,1,1, 1,1,1]

    M.addScaledInplace m, m1, 1
    expect = [2,1,1, 1,2,1, 1,1,2]
    assert.ok M.approxEqv expect, m

  it "must add with coefficient", ->
    m = M.eye()
    m1 = [1,1,1, 1,1,1, 1,1,1]

    M.addScaledInplace m, m1, -2
    expect = [-1,-2,-2, -2,-1,-2, -2,-2,-1]
    assert.ok M.approxEqv expect, m
        

describe "powerPade", ->
  it "must calculate powers of rotation matrices", ->
    m = M.rotationMatrix 0.6
    mpow = M.powerPade m, 1.3
    expect = M.rotationMatrix(0.6*1.3)
    assert.ok M.approxEqv mpow, expect, 1e-4
    
  it "must calculate zeroth power of rotation matrix", ->
    m = M.rotationMatrix 0.6
    mpow = M.powerPade m, 0.0
    assert.ok M.approxEqv mpow, M.eye(), 1e-4

  it "must calculate powers of identity matrix", ->
    e = M.eye()

    assert.ok M.approxEqv e, M.powerPade(e, 1.0)
    assert.ok M.approxEqv e, M.powerPade(e, 0.5)
    assert.ok M.approxEqv e, M.powerPade(e, 1.5)        
    assert.ok M.approxEqv e, M.powerPade(e, 0.0)
    
  it "must calculate powers of zero matrix", ->
    z = M.smul 0, M.eye()
    assert.equal M.amplitude(z), 0

    assert.ok M.approxEqv z, M.powerPade(z, 1.0)
    assert.ok M.approxEqv z, M.powerPade(z, 0.5)
    assert.ok M.approxEqv z, M.powerPade(z, 0.0)

describe "amplitude", ->
  it "must return maximal absolute value of matrix element", ->
    m = [1,2,3,4,5,6,7,8,9]
    assert.equal M.amplitude(m), 9

    m = [1,-2,3,-4,5,-6,7,8,-9]
    assert.equal M.amplitude(m), 9

    m = [-9,2,3,4,5,6,7,8,1]
    assert.equal M.amplitude(m), 9

    m = [9,-2,3,-4,5,-6,7,8,1]
    assert.equal M.amplitude(m), 9

    m = [-3,2,3,9,5,6,7,8,1]
    assert.equal M.amplitude(m), 9

    m = [3,-2,3,-9,5,-6,7,8,1]
    assert.equal M.amplitude(m), 9
                                

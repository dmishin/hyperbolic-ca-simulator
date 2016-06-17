{TriangleGroup, CenteredVonDyck} = require "../src/core/triangle_group_representation"
M = require "../src/core/matrix3"
assert = require "assert"


powm = (m, n) ->
  mp = M.eye()
  for i in [0...n]
    mp = M.mul( mp, m)
  return mp


# describe "TriangleGroup", ->

#   g = new TriangleGroup 2,3,5
  
#   it "must return non-identity matrices", ->
#     assert.ok not M.approxEq g.m_pqr[0], M.eye()
#     assert.ok not M.approxEq g.m_pqr[1], M.eye()
#     assert.ok not M.approxEq g.m_pqr[2], M.eye()

#   it "must have idempotent generators", ->
#     assert.ok M.approxEq M.eye(), M.mul(g.m_pqr[0], g.m_pqr[0])
#     assert.ok M.approxEq M.eye(), M.mul(g.m_pqr[1], g.m_pqr[1])
#     assert.ok M.approxEq M.eye(), M.mul(g.m_pqr[2], g.m_pqr[2])

#   it "must give rotations for pairs fo different generators", ->
#     [p,q,r]= g.m_pqr
#     pq = M.mul p, q
#     pr = M.mul p, r
#     qr = M.mul q, r

#     assert.ok M.approxEq powm(pq,2), M.eye()
#     assert.ok M.approxEq powm(qr,3), M.eye()
#     assert.ok M.approxEq powm(pr,5), M.eye()

#     assert.ok not M.approxEq powm(pq,1), M.eye()
#     assert.ok not M.approxEq powm(qr,2), M.eye()
#     assert.ok not M.approxEq powm(pr,4), M.eye()




describe "CenteredVonDyck(5,4)", ->
  g = new CenteredVonDyck(5,4)
  it "must produce generators with expected properties", ->
    assert.ok not M.approxEq g.a, M.eye()
    assert.ok not M.approxEq g.b, M.eye()
    
    assert.ok M.approxEq powm(g.a, 5), M.eye()
    assert.ok M.approxEq powm(g.b, 4), M.eye()

    ab = M.mul(g.a, g.b)
    
    assert.ok not M.approxEq ab, M.eye()
    assert.ok M.approxEq powm(ab,2), M.eye()

  it "must have stable point of A at (0,0,1)", ->
    v0 = [0.0, 0.0, 1.0]
    assert.ok M.approxEqv v0, v0
    assert.ok M.approxEqv v0, M.mulv(g.a, v0)
    assert.ok not M.approxEqv v0, M.mulv(g.b, v0)
    
  it "must provide coordinates of stable point of B", ->
    v1 = [g.sinh_r, 0, g.cosh_r]
    assert.ok M.approxEqv v1, v1
    assert.ok M.approxEqv v1, M.mulv(g.b, v1)
    assert.ok not M.approxEqv v1, M.mulv(g.a, v1)
            

describe "CenteredVonDyck(5,4,3)", ->
  g = new CenteredVonDyck(5,4,3)
  it "must produce generators with expected properties", ->
    assert.ok not M.approxEq g.a, M.eye()
    assert.ok not M.approxEq g.b, M.eye()
    
    assert.ok M.approxEq powm(g.a, 5), M.eye()
    assert.ok M.approxEq powm(g.b, 4), M.eye()
    
    ab = M.mul(g.a, g.b)
    
    assert.ok not M.approxEq ab, M.eye()
    assert.ok M.approxEq powm(ab,3), M.eye()

  it "must have stable point of A at (0,0,1)", ->
    v0 = [0.0, 0.0, 1.0]
    assert.ok M.approxEqv v0, v0
    assert.ok M.approxEqv v0, M.mulv(g.a, v0)
    assert.ok not M.approxEqv v0, M.mulv(g.b, v0)
    
  it "must provide coordinates of stable point of B", ->
    v1 = [g.sinh_r, 0, g.cosh_r]
    assert.ok M.approxEqv v1, v1
    assert.ok M.approxEqv v1, M.mulv(g.b, v1)
    assert.ok not M.approxEqv v1, M.mulv(g.a, v1)
            


describe "CenteredVonDyck.centerA/B/C", ->
  isNormalVector = ([x,y,t])->Math.abs(t**2-x**2-y**2-1) < 1e-5


  groups = [ [5,4,3], [5,4,2], [3,7,2], [7,3,2] ]

  for [n,m,k] in groups
    g = new CenteredVonDyck n,m,k
    
    it "must be located on the hyperboloid for group #{g}", ->
      assert isNormalVector g.centerA
      assert isNormalVector g.centerB
      assert isNormalVector g.centerAB

    it "must not be changed by the corresponding transforms for group #{g}",->

      assert M.approxEqv g.centerA, M.mulv(g.a,g.centerA)
      assert M.approxEqv g.centerB, M.mulv(g.b,g.centerB)

      ab = M.mul(g.a, g.b)
      assert M.approxEqv g.centerAB, M.mulv(ab,g.centerAB)
    
    
    

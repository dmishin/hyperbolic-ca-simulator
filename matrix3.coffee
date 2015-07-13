#Operations on 3x3 matrices
# Matrices stored as arrays, row by row

exports.eye = eye = -> [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]

exports.zero = zero = -> [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
exports.set = set = (m,i,j,v) ->
  m[i*3+j]=v
  return m

exports.rot = rot = (i,j,angle) ->
  m = eye()
  s = Math.sin angle
  c = Math.cos angle
  set m, i, i, c
  set m, i, j, -s
  set m, j, i, s
  set m, j, j, c
  return m

exports.hrot = hrot = (i, j, sinhD) ->
  m = eye()
  s = sinhD
  c = Math.sqrt( sinhD*sinhD + 1 )
  set m, i, i, c
  set m, i, j, s
  set m, j, i, s
  set m, j, j, c
  return m

exports.mul = mul = (m1, m2) ->
  m = zero()
  for i in [0...3]
    for j in [0...3]
      s = 0.0
      for k in [0...3]
        s += m1[i*3+k] * m2[k*3+j]
      m[i*3+j] = s
  return m

exports.approxEq = approxEq = (m1, m2, eps=1e-6)->
  d = 0.0
  for i in [0...9]
    d += Math.abs(m1[i] - m2[i])
  return d < eps

exports.copy = copy = (m) -> m[..]
exports.mulv = mulv = (m, v) ->
  [m[0]*v[0] + m[1]*v[1] + m[2]*v[2],
   m[3]*v[0] + m[4]*v[1] + m[5]*v[2],
   m[6]*v[0] + m[7]*v[1] + m[8]*v[2]]

exports.approxEqv = approxEqv = (v1, v2, eps = 1e-6) ->
  d = 0.0
  for i in [0...3]
    d += Math.abs(v1[i] - v2[i])
  return d < eps

###
# m: matrix( [m0, m1, m2], [m3,m4,m5], [m6,m7,m8] );
# ratsimp(invert(m)*determinant(m));
# determinant(m);
###
exports.inv = inv = (m) ->
  #Calculated with maxima
  iD = 1.0 / (m[0]*(m[4]*m[8]-m[5]*m[7])-m[1]*(m[3]*m[8]-m[5]*m[6])+m[2]*(m[3]*m[7]-m[4]*m[6]))

  [(m[4]*m[8]-m[5]*m[7])*iD,(m[2]*m[7]-m[1]*m[8])*iD,(m[1]*m[5]-m[2]*m[4])*iD,(m[5]*m[6]-m[3]*m[8])*iD,(m[0]*m[8]-m[2]*m[6])*iD,(m[2]*m[3]-m[0]*m[5])*iD,(m[3]*m[7]-m[4]*m[6])*iD,(m[1]*m[6]-m[0]*m[7])*iD,(m[0]*m[4]-m[1]*m[3])*iD]

exports.smul = smul = (k, m) -> (mi*k for mi in m)
exports.add = add = (m1, m2) -> (m1[i]+m2[i] for i in [0...9])
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
# determinant(
###
exports.inv = inv = (m) ->
  #Calculated with maxima
  iD = 1.0 / (m[0]*(m[4]*m[8]-m[5]*m[7])-m[1]*(m[3]*m[8]-m[5]*m[6])+m[2]*(m[3]*m[7]-m[4]*m[6]))

  [(m[4]*m[8]-m[5]*m[7])*iD,(m[2]*m[7]-m[1]*m[8])*iD,(m[1]*m[5]-m[2]*m[4])*iD,(m[5]*m[6]-m[3]*m[8])*iD,(m[0]*m[8]-m[2]*m[6])*iD,(m[2]*m[3]-m[0]*m[5])*iD,(m[3]*m[7]-m[4]*m[6])*iD,(m[1]*m[6]-m[0]*m[7])*iD,(m[0]*m[4]-m[1]*m[3])*iD]

exports.smul = smul = (k, m) -> (mi*k for mi in m)
exports.add = add = (m1, m2) -> (m1[i]+m2[i] for i in [0...9])
exports.addScaledInplace = addScaledInplace = (m, m1, k) ->
  for i in [0...m.length]
    m[i] += m1[i]*k
  return m
exports.transpose = transpose = (m)->
  [m[0], m[3], m[6],
   m[1], m[4], m[7],
   m[2], m[5], m[8]]
exports.hyperbolicInv = hyperbolicInv = (m) ->
  #x' S x = 1, S = diag (-1, -1, 1)
  #x' M' S M x = 1
  #M' S M = S
  #M^-1 = SM'S
  [ m[0],  m[3], -m[6],
    m[1],  m[4], -m[7],
   -m[2], -m[5],  m[8]]

exports.cleanupHyperbolicMoveMatrix = cleanupHyperbolicMoveMatrix = (m)->
  smul 0.5, add(m, inv hyperbolicInv m)

exports.translationMatrix = translationMatrix = (dx, dy) ->
  #Formulae obtained with Maxima,
  # as combination of (inverse rotate) * (shift by x) * (rotate)
  # distance is acosh( dx^2 + dy^2 + 1 )
  r2 = dx*dx+dy*dy
  dt = Math.sqrt(r2+1)
  k = if r2 < 1e-6 then 0.5 else (dt-1)/r2

  xxk = dx*dx*k
  xyk = dx*dy*k
  yyk = dy*dy*k
  
  [xxk+1, xyk,   dx,
   xyk,   yyk+1, dy,
   dx,    dy,    dt]
  
exports.rotationMatrix = rotationMatrix = (angle) ->
  s = Math.sin angle
  c = Math.cos angle
  [c,   s,   0.0,
   -s,  c,   0.0,
   0.0, 0.0, 1.0]

exports.amplitude = amplitude = (m) -> Math.max (Math.abs(mi) for mi in m) ...

    
#Decompose hyperbolic matrix to translation and rotation
# returns 3 values: rotation angle, dx, dy
# dx and dy are parameters of the translationMatrix
exports.hyperbolicDecompose = (m)->
  #first, detect translation, look, how far it translates origin
  [dx, dy, t] = mulv m, [0,0,1]

  #multiply out the translation
  T = translationMatrix -dx, -dy
  R = mul T, m

  #now R shoulw be purely rotation matrix
  #TODO validate this?

  cos = (R[0]+R[4])*0.5
  sin = (R[1]-R[3])*0.5

  [Math.atan2(sin, cos), dx, dy]

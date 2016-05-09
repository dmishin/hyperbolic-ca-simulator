M = require "./matrix3.coffee"

charpoly = (m) ->
  [ m[0]*m[4]*m[8]-m[1]*m[3]*m[8]-m[0]*m[5]*m[7]+m[2]*m[3]*m[7]+m[1]*m[5]*m[6]-m[2]*m[4]*m[6],
   -m[4]*m[8]-m[0]*m[8]+m[5]*m[7]+m[2]*m[6]-m[0]*m[4]+m[1]*m[3],
    m[8]+m[4]+m[0],
   -1]

#divide polynomial p by (x-r). return new polynomial and remainder
polydiv = (p, r) ->
  p = p[..]
  d = []
  while p.length > 1
    pHigh = p.pop()
    d.push pHigh
    # p -= pHigh * (x-r) * x^powerHigh
    p[p.length-1] += r*pHigh
    
  return [d.reverse(), p[0]]
  
exports.hyperbolicRealEig = hyperbolicRealEig = (m) ->
  #m must be a hyperbolic transformation matrix m'JM = J, J=diag [1 1 -1]
  # such matrix has 3 eigenvlues, if it represents pure translation relative to some pivot point.
  # 
  # 1, exp(d), exp(-d)
  #
  # subtract E, to fid eigenvector 1
  m0 = M.copy(m)

  #eigenvector for 1 must have form [sin(a), cos(a), 0]
  charp = charpoly m

  [charp1, rem] = polydiv charp, 1.0

  if Math.abs(rem) > 1e-6
    throw new Error "Matrix is not hyperbolic translation, 1 is not eigenvalue"

  #now charp1 is order 2, roots can be found directly

  [c,b,a] = charp1
  D = b*b-4*a*c
  if D < 0
    #Roots not real, matrix is not translation.
    return null
  if a is 0
    #infinite translation
    return null
  qD = Math.sqrt D
  
  lam1 = (-b+qD)/(2*a)
  lam2 = (-b-qD)/(2*a)
  
  if lam1 > lam2  
    return [1.0, lam1, lam2]
  else
    return [1.0, lam2, lam1]


#Transposed adjoint matrix.
exports.star = star = (m) ->
  #Calculated with maxima
  [m[4]*m[8]-m[5]*m[7], m[2]*m[7]-m[1]*m[8], m[1]*m[5]-m[2]*m[4],
   m[5]*m[6]-m[3]*m[8], m[0]*m[8]-m[2]*m[6], m[2]*m[3]-m[0]*m[5],
   m[3]*m[7]-m[4]*m[6], m[1]*m[6]-m[0]*m[7], m[0]*m[4]-m[1]*m[3]]
   

norm = ([c1,c2,c3]) -> Math.sqrt(c1**2 + c2**2 + c3**2)

eivec = (m, lam) ->
  ##console.log "m="
  ##console.dir m
  m = M.copy m
  M.addScaledInplace m, M.eye(), -lam
  
  mstar = star m
  ##console.log "Mstar="
  ##console.dir mstar
  
  #rank of mstar should be at most 1
  # every solumn is a vector

  col = (i) -> [mstar[i], mstar[i+3], mstar[i+6]]
  
  vbest = col(0)
  nbest = norm vbest
  for i in [1..2]
    c = col i
    nc = norm c
    if nc > nbest
      nbest = nc
      vbest = c
  #console.log("For lam=#{lam}, best vector is")
  #console.dir vbest
  return vbest
  

eps = 1e-12

vscaleInplace = (v,k)->
  for i in [0...v.length] by 1
    v[i]*=k
  return v

exports.hyperbolicRealJordan = (m) ->
  lam123 = hyperbolicRealEig m
  if lam123 is null
     return null
     
  [lam1, lam2, lam3] = lam123
  #diagonal matrix
  if Math.abs(lam2-lam3) < eps
     return [M.eye(), m]

  #lam 1 should be equal to 1

  v1 = eivec m, lam1
  v2 = eivec m, lam2
  v3 = eivec m, lam3

  #v1 should have form [cos, sin, 0]
  n1 = norm v1
  if n1 < eps
    throw new Error("Eigenvector for lam=1 is undefined")

  #make cosine part positive
  if v1[1] < 0
     n1 = -n1

  vscaleInplace v1, 1.0/n1
  #console.log("=========")
  #console.log "After normalization, v1 is"
  #console.dir v1

  #v2 and v3 should have form [cos sin 1], [cos, sin, -1]

  vscaleInplace v2,  1.0/v2[2]
  vscaleInplace v3, -1.0/v3[2]

  #console.log("=========")
  #console.log "After normalization, v2 is"
  #console.dir v2
  
  V = [v1[0], v2[0], v3[0],
       v1[1], v2[1], v3[1],
       v1[2], v2[2], v3[2]]
  #console.log "========collected V matrix:"
  #console.dir V[0...3]
  #console.dir V[3...6]
  #console.dir V[6...9]
       
  D = [lam1,0,0,
       0,lam2,0,
       0,0,lam3]
  return [V,D]

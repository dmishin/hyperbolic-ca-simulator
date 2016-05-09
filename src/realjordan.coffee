M = require "./matrix3"

charpoly = (m) ->
  [ m[0]*m[4]*m[8]-m[1]*m[3]*m[8]-m[0]*m[5]*m[7]+m[2]*m[3]*m[7]+m[1]*m[5]*m[6]-m[2]*m[4]*m[6],
   -m[4]*m[8]-m[0]*m[8]+m[5]*m[7]+m[2]*m[6]-m[0]*m[4]+m[1]*m[3],
    m[8]+m[4]+m[0],
   -1]


polyroot = (p) ->
  if p.length <= 1
    return null
  if p.length is 2
    return -p[0]/p[1]

  return newtonRoot p

polyDiff = (p)->
  (i*p[i] for pi, i in [1...p.length] by 1)

polyval = (p, x) ->
  s = p[0]
  xi = x
  for i in [1...p.length] by 1
    xi *= x
    s += p[i]*xi
  return s

  
newtonRoot = (p, x0=1.0, eps=1e-12, maxiter = 100)->
  dp = polyDiff p

  x = x0
  iter = 0
  while iter < maxiter
    iter += 1
    df = polyval dp, x
    f = polyval 
    if df is 0
      if f is 0
        dx = 0
      else
        dx = Math.random() * 2 - 1
    else
      dx = - f / df
      if Math.abs(dx) < eps
        return x + dx
  #failed
  return null

exports.realeig = realeig = (m) ->
  poly = charpoly m
  

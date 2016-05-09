M = require "./matrix3.coffee"
{fminsearch} = require "./fminsearch.coffee"

exports.decomposeToTranslations = (m, eps=1e-5) ->
#Decompose hyperbolic matrix to 3 translations: M = T1^-1 T2 T1
#not always possible.
  fitness = ([dx1,dy1,dx2,dy2]) ->
    t1 = M.translationMatrix dx1, dy1
    t2 = M.translationMatrix dx2, dy2

    #calculate difference
    d = M.mul M.hyperbolicInv(t1), M.mul t2, t1
    M.addScaledInplace d, m, -1
     
    M.amplitude d

  #detect transllation
  x = M.mulv m, [0,0,1]
  
  res = fminsearch fitness, [0.0, 0.0, x[0], x[1]], 0.1, eps
  if res.reached and res.f < eps*10
    [dx1,dy1,dx2,dy2] = res.x
    t1 = M.translationMatrix dx1, dy1
    t2 = M.translationMatrix dx2, dy2
    [t1,t2]
  else
    [null, null]
  

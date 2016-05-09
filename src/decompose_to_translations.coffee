M = require "./matrix3.coffee"
{fminsearch} = require "./fminsearch.coffee"
#{hyperbolicRealJordan}= require "./hyperbolic_jordan"



exports.decomposeToTranslations2 = decomposeToTranslations2 = (m) ->

  # M = V D V^-1
  #
  #   D is diag [1, exp(d), exp(-d)]
  # In the same time
  # 
  # M = T^-1 Tau T  
  #   where T, Tau are pure translations
  # Therefore,
  #   Tau = R Tau0 R^-1
  #   where R is pure rotation, Tau0 - translation along x.
  #
  # Therefore
  #   Tau0 = V0 D V0^-1
  #
  # where V0 [ 0,1,1; 1,0,0; 0,1,-1]
  #
  # Combining this
  #
  # V D V^-1 =  T^-1 R V0 S D S^-1 V0^-1 R^-1 T  
  #
  # V = T^-1 R V0 S
  #
  # where S - arbitrary nonzero diagonal matrix
  # T^-1 R = V S^-1 V0^-1

exports.decomposeToTranslations = decomposeToTranslations = (m, eps=1e-5) ->

  #Another idea, reducing number of parameters
  #
  # Approximate paramters of matrix T1, fitness is rotation amount of the T2

  shiftAndDecompose = ([t1x, t1y]) ->
    T1 = M.translationMatrix t1x, t1y
    iT1 = M.hyperbolicInv T1
    Tau = M.mul T1, M.mul m, iT1

    #decompose Tau to rotation and translation part
    return M.hyperbolicDecompose Tau

  #fitness is absolute value of angle
  fitness = (t1xy) ->
    Math.abs(shiftAndDecompose(t1xy)[0])

  res = fminsearch fitness, [0.0, 0.0], 0.1, eps
  
  if res.reached and res.f < eps*10
    [t1x, t1y] = res.x
    [angle, t2x, t2y] = shiftAndDecompose [t1x, t1y]
    [M.translationMatrix(t1x, t1y), M.translationMatrix(t2x, t2y)]    
  else
    [null, null]
  
exports.decomposeToTranslationsFmin = decomposeToTranslationsFmin = (m, eps=1e-5) ->
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
  

exports.decomposeToTranslationsAggresively = (m, eps=1e-5, attempts = 1000) ->
  
  #detect range
  x = M.mulv m, [0,0,1]
  d = Math.sqrt(x[0]**2+x[1]**2)

  decomposeTranslated = (t0, eps) ->
    mPrime = M.mul M.hyperbolicInv(t0), M.mul m, t0
    [t1,t2] = decomposeToTranslationsFmin mPrime, eps
    #t0^-1 m t0 = t1^-1 t2 t1
    # m = t0 t1^-1 t2 t1 t0^-1
    # 
    if t1 isnt null
      return [M.mul(t1, M.hyperbolicInv t0), t2]
    else
      return [null, null]

  #attempts with radom pre-translation
  for attempt in [0... attempts]
    d = Math.random()*d*3
    angle = Math.random()*Math.PI*2
    t0 = M.translationMatrix(d*Math.cos(angle),d*Math.sin(angle))
    [t1,t2] = decomposeTranslated t0, 1e-2
    if t1 isnt null
      #fine optiomization
      console.log "fine optimization"
      return decomposeTranslated t1

  console.log "All attempts failed"
  return [null, null]

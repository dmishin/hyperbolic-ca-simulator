
combine2= (v1, k1, v2, k2) ->
  (v1[i]*k1+v2[i]*k2 for i in [0...v1.length] by 1)
  
scaleInplace= (v,k)->
  for i in [0...v.length] by 1
    v[i]*=k
  return v
    
addInplace= (v1,v2)->
  for v2i, i in v2
    v1[i] += v2[i]
  return v1

amplitude = (x)-> Math.max (Math.abs(xi) for xi in x)...

#optimal parameters for Rozenbrock optimiation
exports.alpha = 2.05
exports.beta = 0.46
exports.gamma = 0.49

exports.fminsearch = (func, x0, step, tol=1e-6, maxiter=10000)->
  alpha = exports.alpha
  beta = exports.beta
  gamma = exports.gamma
  
  n = x0.length

  #generate initial polygon
  poly = (x0[..] for i in [0..n] by 1)
  for i in [1..n] by 1
    poly[i][i-1] += step

  evaluations = n+1

  findCenter = ->
    xc = withValue[0][0][..]
    for i in [1..(n-1)] by 1
      addInplace xc, withValue[i][0]
    scaleInplace xc, 1.0/n
    return xc

  polySize = ->
    minima = withValue[0][0][..]
    maxima = withValue[0][0][..]
    for i in [1...withValue.length] by 1
      xi = withValue[i][0]
      for xij, j in xi
        if xij < minima[j]
          minima[j] = xij
        if xij > maxima[j]
          maxima[j] = xij
    Math.max (maxima[i]-minima[i] for i in [0...n] by 1)...
          
      
  makeAnswerOK = ->
    rval =
            reached:true
            x: withValue[0][0]
            f: withValue[0][1]
            steps: iter
            evaluations: evaluations
      
  withValue = ( [x, func(x)] for x in poly )

  #sort by function value
  sortPoints = -> withValue.sort (a,b) -> a[1] - b[1]
  
  iter = 0
  while iter < maxiter
    iter += 1

    sortPoints()  
    #worst is last

    #find center of all points except the last (worst) one.
    xc = findCenter()

    #Best, worst and first-before-worst values.
    f0 = withValue[0][1]
    fg = withValue[n-1][1]
    
    [xh, fh] = withValue[n]
    #console.log "I=#{iter}\tf0=#{f0}\tfg=#{fg}\tfh=#{fh}"

    #reflect
    #xr = xc-(xh-xc) = 2xc - xh
    xr = combine2 xc, 2.0, xh, -1.0
    fr = func xr
    evaluations += 1
    
    if fr < f0
      #extend
      # xe = xc+ (xr-xc)*alpha = xr*alpha + xc*(1-alpha)
      xe = combine2 xr, alpha, xc, (1-alpha)
      fe = func xe
      evaluations += 1
      if fe < fr
        #use fe
        withValue[n] = [xe, fe]
      else
        #use fr
        withValue[n] = [xr, fr]
    else if fr < fg
      #use xr
      withValue[n] = [xr, fr]
    else
      # This is present in the original decription of the method, but it makes result even slightly worser!
      #if fr < fh
      #  #swap xr, xg
      #  [[xr, fr], withValue[n-1]] = [withValue[n-1], [xr, fr]]
      #  # my own invertion - makes worser.
      #  #xc = findCenter()

      #now fr >= fh
      #shrink
      #xs = xc+ (xr-xc)*beta
      xs = combine2 xh, beta, xc, (1-beta)
      fs = func xs
      evaluations += 1

      if fs < fh
        #use shrink
        withValue[n] = [xs, fs]
        if polySize() < tol then return makeAnswerOK()
      else
        #global shrink
        x0 = withValue[0][0]
        #check exit
        if polySize() < tol then return makeAnswerOK()
        #global shrink
        for i in [1..n]
          xi = combine2 withValue[i][0], gamma, x0, 1-gamma
          fi = func xi
          withValue[i] = [xi,fi]
        evaluations += n

  sortPoints()  
  rval =
    reached: false
    x: withValue[0][0]
    f: withValue[0][1]
    steps: iter
    evaluations: evaluations

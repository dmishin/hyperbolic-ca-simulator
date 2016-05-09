
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

alpha = 2.0
beta = 0.5
gamma = 0.5

exports.fminsearch = (func, x0, step, eps=1e-6, maxiter=10000)->
  n = x0.length

  #generate initial polygon
  poly = (x0[..] for i in [0..n] by 1)
  for i in [1..n] by 1
    poly[i][i-1] += step


  withValue = ( [x, func(x)] for x in poly )

  iter = 0
  while iter < maxiter
    iter += 1
    #sort by function value
    withValue.sort (a,b) -> a[1] - b[1]
    #worst is last


    #find center
    xc = withValue[0][0][..]
    for i in [1..(n-1)] by 1
      addInplace xc, withValue[i][0]

    scaleInplace xc, 1.0/n    

    f0 = withValue[0][1]
    fh = withValue[n][1]
    fg = withValue[n-1][1]
    
    xh = withValue[n][0]
    #console.log "I=#{iter}\tf0=#{f0}\tfg=#{fg}\tfh=#{fh}"

    #reflect
    #xr = xc-(xh-xc) = 2xc - xh
    xr = combine2 xc, 2.0, xh, -1.0
    fr = func xr

    if fr < f0
      #extend
      # xe = xc+ (xr-xc)*alpha = xr*alpha + xc*(1-alpha)
      xe = combine2 xr, alpha, xc, (1-alpha)
      fe = func xe
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
      if fr < fh
        #swap xr, xg
        [[xr, fr], withValue[n-1]] = [withValue[n-1], [xr, fr]]

      #now fr >= fh
      #shrink
      #xs = xc+ (xr-xc)*beta
      xs = combine2 xr, beta, xc, (1-beta)
      fs = func xs
      if fs < fh
        #use shrink
        withValue[n] = [xs, fs]
      else
        #global shrink
        x0 = withValue[0][0]

        #calculate size of the polygon
        dmax = 0.0
        for i in [1..n]
          xi = withValue[i][0]
          d = amplitude combine2 xi, 1.0, x0, -1.0
          dmax = Math.max d, dmax
        #check exit
        if dmax < eps
          rval =
            reached:true
            x: withValue[0][0]
            f: withValue[0][1]
            steps: iter
          return rval
        #global shrink
        for i in [1..n]
          xi = combine2 withValue[i][0], gamma, x0, 1-gamma
          fi = func xi
          withValue[i] = [xi,fi]

  rval =
    reached: false
    x: withValue[0][0]
    f: withValue[0][1]
    steps: iter

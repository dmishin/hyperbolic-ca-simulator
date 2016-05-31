
fminsearch = require "./fminsearch.coffee"
fminsearch1 = require "./Fminsearch.coffee"

near = (x, y, eps=1e-5) -> Math.abs(x-y)<eps
  
runtest = ->

  sampleSize = 10000

  #use rozenbrock for test
  func = ([x,y]) -> (1-x)**2 + 100*(y-x**2)**2
  #func = ([x,y]) -> (1-x)**2 + 2*(1-y)**2


  randRange = (a,b) -> Math.random()*(b-a)+a
    
  makeInitialPoint = -> [randRange(-5,5), randRange(-5,5)]

  initialSamples = (makeInitialPoint() for _ in [0...sampleSize] by 1)


  penalty = 10000
  step = 1.0
  eps = 1e-5
  maxiter = 1000
  
  measurePerformance = ([alpha, beta,gamma])->

    fminsearch.alpha = alpha
    fminsearch.beta = beta
    fminsearch.gamma = gamma

    price = 0
    success = 0
    for x0 in initialSamples
      res = fminsearch.fminsearch func, x0, step, eps, maxiter
      price += res.evaluations
      
      unless  res.reached
        price += penalty
        continue
      unless near(res.x[0], 1.0, eps*10) and near(res.x[1], 1.0, eps*10)
        price += penalty
        continue
      success += 1
    price /= sampleSize
    console.log "ABG: #{JSON.stringify [alpha, beta,gamma]} price: #{price} success ratio: #{success / initialSamples.length}"
    return price

  #for abg in [[2.0,0.5,0.5], [30.0,0.5,0.5], [2.0,0.3,0.5], [2.0,0.5,0.2]]
  #  console.log "===testing ABG:"
  #  console.dir abg
  #  console.log "price: #{measurePerformance abg}"

  fminsearch.alpha = 1000
  if fminsearch1.alpha is 1000
    throw new Error "modules not separate"
  console.log "Trying to find an optimal performace"
  res = fminsearch1.fminsearch measurePerformance, [2.0,0.5,0.5], 0.1, 0.01
  console.log "Found best parameters:"
  console.dir(res)

runtest()  

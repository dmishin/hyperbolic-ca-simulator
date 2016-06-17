#Performance testing
#
#

{randomFillFixedNum} = require "../src/core/field.coffee"
{ChainMap} = require "../src/core/chain_map.coffee"
{RegularTiling} = require "../src/core/regular_tiling.coffee"
{parseTransitionFunction} = require "../src/core/rule.coffee"
{evaluateTotalisticAutomaton} = require "../src/core/cellular_automata.coffee"
{unity} = require "../src/core/vondyck_chain.coffee"
class RandomGenerator
  #From here: http://stackoverflow.com/questions/424292/seedable-javascript-random-number-generator
  constructor: (seed)->
    @m = 0x80000000 # 2**31
    @a = 1103515245
    @c = 12345
    @state = seed ? (Math.floor(Math.random() * (@m-1)))
    
  nextInt: ->
    this.state = (this.a * this.state + this.c) % this.m

  # returns in range [0,1]
  nextFloat: -> @nextInt() / (@m - 1)

  # returns in range [start, end): including start, excluding end
  # can't modulu nextInt because of weak randomness in lower bits
  nextRange: (start, end) ->
    rangeSize = end - start
    randomUnder1 = @nextInt() / @m
    start + Math.floor(randomUnder1 * rangeSize)

  choice: (array) -> array[@nextRange(0, array.length)]

#Fill randomly, visiting numCells cells around the origin
randomFillBlob = (field, tiling, numCells, randomState ) ->
  visited = 0
  tiling.forFarNeighborhood unity, (cell, _)->
    #Time to stop iteration?
    return false if visited >= numCells
    if (state = randomState()) isnt 0
      field.put cell, state
    visited+=1
    #Continue
    return true
  return
      


runTestMildGrowing = (seed) ->
  rng = new RandomGenerator seed

  tiling = new RegularTiling 3, 8
  rule = parseTransitionFunction "B 3 S 2 6", tiling.n, tiling.m
  density = 0.4
  newState = -> if rng.nextFloat() < density then 1 else 0
  maxCells = 4000
  steps = 1000
  maxPop = 20000
  field = new ChainMap()
  randomFillBlob field, tiling, maxCells, newState

  console.log "Rule is: #{rule}"
  generation = 0

  console.time "eval"
  while (field.count < maxPop) and ((generation+=1) < steps)
    field = evaluateTotalisticAutomaton field, tiling, rule.evaluate.bind(rule), rule.plus, rule.plusInitial
    #console.log "g: #{generation}, pop: #{field.count}"
  console.timeEnd "eval"
    
  

runTestMildGrowing 100
runTestMildGrowing 101
runTestMildGrowing 102

{NodeHashMap} = require "./chain_map.coffee"

exports.neighborsSum = neighborsSum = (cells, tiling, plus=((x,y)->x+y), plusInitial=0)->
  sums = new NodeHashMap
  cells.forItems (cell, value)->
    for neighbor in tiling.moore cell
      sums.putAccumulate neighbor, value, plus, plusInitial
    #don't forget the cell itself! It must also present, with zero (initial) neighbor sum
    if sums.get(cell) is null
      sums.put(cell, plusInitial)
  return sums

exports.evaluateTotalisticAutomaton = evaluateTotalisticAutomaton = (cells, tiling, nextStateFunc, plus, plusInitial)->
  newCells = new NodeHashMap
  sums = neighborsSum cells, tiling, plus, plusInitial
  sums.forItems (cell, neighSum)->
    cellState = cells.get(cell) ? 0
    nextState = nextStateFunc cellState, neighSum
    if nextState isnt 0
      newCells.put cell, nextState
  return newCells



#{Tessellation} = require "./hyperbolic_tessellation.coffee"
{NodeHashMap, newNode, showNode, node2array} = require "./vondyck_chain.coffee"
{makeAppendRewrite, eliminateFinalA} = require "./vondyck_rewriter.coffee"
#{RewriteRuleset, knuthBendix} = require "./knuth_bendix.coffee"

#High-level utils for working with hyperbolic cellular fields



exports.mooreNeighborhood = mooreNeighborhood = (n, m, appendRewrite)->(chain)->
  #reutrns Moore (vertex) neighborhood of the cell.
  # it contains N cells of von Neumann neighborhood
  #    and N*(M-3) cells, sharing single vertex.
  # In total, N*(M-2) cells.
  neighbors = []
  for powerA in [0...n] by 1
    for powerB in [1...m-1] by 1
      #adding truncateA to eliminate final rotation of the chain.
      nStep = if powerA
            [['b', powerB], ['a', powerA]]
        else
            [['b', powerB]]
      neigh = eliminateFinalA appendRewrite(chain, nStep), appendRewrite, n
      neighbors.push neigh
  return neighbors


exports.neighborsSum = neighborsSum = (cells, getNeighbors)->
  sums = new NodeHashMap
  plus = (x,y)->x+y
  cells.forItems (cell, value)->
    for neighbor in getNeighbors cell
      sums.putAccumulate neighbor, value, plus
  return sums

exports.evaluateTotalisticAutomaton = evaluateTotalisticAutomaton = (cells, getNeighborhood, nextStateFunc)->
  newCells = new NodeHashMap
  sums = neighborsSum cells, getNeighborhood
  
  sums.forItems (cell, neighSum)->
    #console.log "#{showNode cell}, sum=#{neighSum}"
    cellState = cells.get(cell) ? 0
    nextState = nextStateFunc cellState, neighSum
    if nextState isnt 0
      newCells.put cell, nextState
  return newCells


# r - radius
# appendRewrite: rewriter for chains.
# n,m - parameters of the tessellation
# Return value:
#  list of chains to append
exports.farNeighborhood = farNeighborhood = (center, r, appendRewrite, n, m) ->
  cells = new NodeHashMap
  getNeighbors = mooreNeighborhood n, m, appendRewrite


  walk = ( cell, level ) ->
    return if cells.get cell
    cells.put cell, true
    if level < r
      for nei in getNeighbors cell
        walk(nei, level+1)
    return

  walk null, 0
  
  cellList = []
  cells.forItems (cell, state) ->
    cellList.push cell
    
  return cellList


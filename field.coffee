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
  neighbors = new Array(n*(m-2))
  i = 0
  for powerA in [0...n] by 1
    for powerB in [1...m-1] by 1
      #adding truncateA to eliminate final rotation of the chain.
      nStep = if powerA
            [['b', powerB], ['a', powerA]]
        else
            [['b', powerB]]
      neigh = eliminateFinalA appendRewrite(chain, nStep), appendRewrite, n
      neighbors[i] = neigh
      i += 1
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
  cells.put center, true
  getNeighbors = mooreNeighborhood n, m, appendRewrite
  getCellList = (cells) ->
    cellList = []
    cells.forItems (cell, state) ->
      cellList.push cell
    return cellList

  for i in [0...r] by 1
    for cell in getCellList cells
      for nei in getNeighbors cell
        cells.put nei, true

  getCellList cells  


exports.extractClusterAt = extractClusterAt = (cells, getNeighbors, chain) ->
  #use cycle instead of recursion in order to avoid possible stack overflow.
  #Clusters may be big.
  stack = [chain]
  cluster = []
  while stack.length > 0
    c = stack.pop()
    continue if cells.get(c) is null
    
    cells.remove c
    cluster.push c
    
    for neighbor in getNeighbors c
      if cells.get(neighbor) isnt null
        stack.push neighbor
  return cluster
  
exports.allClusters = (cells, n, m, appendRewrite) ->
  cellsCopy = cells.copy()
  clusters = []
  getNeighbors = mooreNeighborhood n, m, appendRewrite
    
  cells.forItems (chain, value) ->
    if cellsCopy.get(chain) isnt null
      clusters.push extractClusterAt(cellsCopy, getNeighbors, chain)

  return clusters      
  

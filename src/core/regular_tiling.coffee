"use strict"
{VonDyck} = require "./vondyck.coffee"
{ChainMap} = require "./chain_map.coffee"
{unity, reverseShortlexLess} = require "./vondyck_chain.coffee"
M = require "./matrix3.coffee"

exports.RegularTiling = class RegularTiling extends VonDyck
  constructor: (n,m) ->
    super(n,m,2)
    @solve()
    if @representation?
      @cellShape = @_generateNGon()
    
  toString: -> "VonDyck(#{@n}, #{@m}, #{@k})"

  #Convert path to an unique cell identifier by taking a shortest version of all rotated variants
  toCell: (chain)->
    eliminateFinalA chain, @appendRewrite, @n

  #Return moore neighbors of a cell  
  moore: (chain)->
    #reutrns Moore (vertex) neighborhood of the cell.
    # it contains N cells of von Neumann neighborhood
    #    and N*(M-3) cells, sharing single vertex.
    # In total, N*(M-2) cells.
    neighbors = new Array(@n*(@m-2))
    i = 0
    for powerA in [0...@n] by 1
      for powerB in [1...@m-1] by 1
        #adding truncateA to eliminate final rotation of the chain.
        nStep = if powerA
              [['b', powerB], ['a', powerA]]
          else
              [['b', powerB]]
        neighbors[i] = @toCell @appendRewrite chain, nStep
        i += 1
    return neighbors

  #calls a callback fucntion for each cell in the far neighborhood of the original.
  # starts from the original cell, and then calls the callback for more and more far cells, encircling it.
  # stops when callback returns false.
  forFarNeighborhood: (center, callback) ->
    cells = new ChainMap
    cells.put center, true
    #list of cells of the latest complete layer
    thisLayer = [center]
    #list of cells in the previous complete layer
    prevLayer = []
    #Radius of the latest complete layer
    radius = 0
    
    return if not callback center, radius

    while true
      #now for each cell in the latest layer, find neighbors, that are not marked yet.
      # They would form a new layer.
      radius += 1
      newLayer = []
      for cell in thisLayer
        for neighCell in @moore cell
          if not cells.get neighCell
            #Detected new unvisited cell - register it and call a callback
            newLayer.push neighCell
            cells.put neighCell, true
            return if not callback neighCell, radius
      #new layer complete at this point.
      # Now move to the next layer.
      # memory optimization: remove from the visited map cells of the prevLayer, since they are not neeed anymore.
      # actually, this is quite minor optimization, since cell counts grow exponentially, but I would like to do it.
      for cell in prevLayer
        if not cells.remove cell
          throw new Error("Assertion failed: cell not present")
      #rename layers
      prevLayer = thisLayer
      thisLayer = newLayer
      #And loop!
    #The loop is only finished by 'return'.


  # r - radius
  # appendRewrite: rewriter for chains.
  # n,m - parameters of the tessellation
  # Return value:
  #  list of chains to append
  farNeighborhood:(center, r) ->
    #map of visited cells
    cells = new ChainMap
    cells.put center, true
    getCellList = (cells) ->
      cellList = []
      cells.forItems (cell, state) ->
        cellList.push cell
      return cellList

    for i in [0...r] by 1
      for cell in getCellList cells
        for nei in @moore cell
          cells.put nei, true

    getCellList cells
  
  #produces shape (array of 3-vectors)
  _generateNGon:  ->
    #Take center of generator B and rotate it by action of A

    if @k is 2
      for i in [0...@n]
        M.mulv @representation.aPower(i), @representation.centerB
    else
      #dead code actually, but interesting for experiments
      for i2 in [0...@n*2]
        i = (i2/2) | 0
        if (i2 % 2) is 0
          M.mulv @representation.aPower(i), @representation.centerB
        else
          M.mulv @representation.aPower(i), @representation.centerAB


#Remove last element of a chain, if it is A.
takeLastA = (chain) ->
  if (chain is unity) or (chain.letter isnt 'a')
    chain
  else
    chain.t

# Add all possible rotations powers of A generator) to the end of the chain,
# and choose minimal of all chains (by some ordering).
eliminateFinalA = (chain, appendRewrite, orderA) ->
  chain = takeLastA chain
  #zero chain is always shortest, return it.
  if chain is unity
    return chain
  #now chain ends with B power, for sure.
  #if chain.letter isnt 'b' then throw new Error "two A's in the chain!"
    
  #bPower = chain.p

  #TODO: only try to append A powers that cause rewriting.
      
  bestChain = chain
  for i in [1...orderA]
    chain_i = appendRewrite chain, [['a', i]]
    if reverseShortlexLess chain_i, bestChain
      bestChain = chain_i
  #console.log "EliminateA: got #{chain}, produced #{bestChain}"
  return bestChain

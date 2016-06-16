{eliminateFinalA} = require "./vondyck_rewriter.coffee"
{VonDyck} = require "./vondyck.coffee"
{mooreNeighborhood, forFarNeighborhood} = require "./field.coffee"

#???
{unity} = require "./vondyck_chain.coffee"
{NodeHashMap} = require "./chain_map.coffee"


exports.RegularTiling = class RegularTiling extends VonDyck
  constructor: (n,m) ->
    super(n,m,2)
    @solve()
    
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
    cells = new NodeHashMap
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


  

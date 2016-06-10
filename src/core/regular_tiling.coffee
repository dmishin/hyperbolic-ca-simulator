{eliminateFinalA} = require "./vondyck_rewriter.coffee"
{VonDyck} = require "./vondyck.coffee"
{mooreNeighborhood, forFarNeighborhood} = require "./field.coffee"

exports.RegularTiling = class RegularTiling extends VonDyck
  constructor: (n,m) ->
    super(n,m,2)
    @solve()
    
  toString: -> "VonDyck(#{@n}, #{@m}, #{@k})"

  #Convert path to an unique cell identifier by taking a shortest version of all rotated variants
  trimA: (chain)->
    eliminateFinalA chain, @appendRewrite, @n

  #Return moore neighbors of a cell  
  moore: (chain)->
    mooreNeighborhood(@n,@m,@appendRewrite)(chain)


  #calls a callback fucntion for each cell in the far neighborhood of the original.
  # starts from the original cell, and then calls the callback for more and more far cells, encircling it.
  # stops when callback returns false.
  forFarNeighborhood: (center, callback) -> forFarNeighborhood center, @appendRewrite, @n, @m, callback

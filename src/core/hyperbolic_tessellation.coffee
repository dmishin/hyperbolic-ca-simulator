{CenteredVonDyck} = require "./triangle_group_representation.coffee"
M = require "./matrix3.coffee"

len2 = (x,y) -> x*x + y*y

exports.Tessellation = class Tessellation
  constructor: (n,m) ->
    @group = new CenteredVonDyck n, m
    @cellShape = @_generateNGon n, @group.sinh_r, @group.cosh_r


  #produces shape (array of 3-vectors)
  _generateNGon: (n, sinh_r, cosh_r) ->
    alpha = Math.PI*2/n
    for i in [0...n]
      angle = alpha*i
      [sinh_r*Math.cos(angle), sinh_r*Math.sin(angle), cosh_r]

  
                  

M = require "./matrix3.coffee"
{} = M


exports.TriangleGroup = class TriangleGroup
  constructor: (p,q,r) ->
    [sp,sq,sr] = (Math.cos(Math.PI/n) for n in [p,q,r])
    @pqr = [p,q,r]
    
    m = [-1.0,sp,sr, \
         sp,-1.0,sq, \
         sr,sq,-1.0]
    @m = m
    
    im = M.add M.smul(2, m), M.eye()
    
    sigma = (k) ->
      s = M.zero()
      e = M.eye()
      for i in [0...3]
        for j in [0...3]
          M.set s, i, j, (if i is k then im else e)[i*3+j]
      return s
            
    @m_pqr = (sigma(i) for i in [0...3])
        
        
    toString = ->
      "Trg(#{@pqr[0]},#{@pqr[1]},#{@pqr[2]})"%self.pqr


###  array of matrix powers
###
powers = (matrix, n) ->
  #current power
  m_n= M.eye()
  
  pows = [m_n]
  for i in [1...n]
    m_n = M.mul matrix, m_n
    pows.push m_n
  return pows

###
# Impoementation of VD groups of order (n, m, 2)
# with 2 generators: a, b
#  and rules: a^n = b^m = abab = e
#
#  such that `a` has fixed point (0,0,1)
###
exports.CenteredVonDyck = class CenteredVonDyck
  constructor: (n, m) ->
    #a^n = b^m = (abab) = e

    @a = M.rot 0, 1, (Math.PI*2/n)
    @n = n
    @m = m

    @cosh_r = 1.0 / (Math.tan(Math.PI/n) * Math.tan(Math.PI/m))
    if @cosh_r <= 1.0
      throw new Error("von Dyck group is not hyperbolic!")
    @sinh_r = Math.sqrt( @cosh_r**2 - 1 )

    @b = M.mul( M.mul(M.hrot(0, 2, @sinh_r), M.rot(0, 1, Math.PI*2/m)), M.hrot(0, 2, -@sinh_r) )

    @aPowers = powers @a, n
    @bPowers = powers @b, m
    

  aPower: (i) -> @aPowers[ ((i%@n)+@n)%@n ]
  bPower: (i) -> @bPowers[ ((i%@m)+@m)%@m ]
  generatorPower: (g, i)->
    if g is 'a'
      @aPower i
    else if g is 'b'
      @bPower i
    else throw new Error("Unknown generator: #{g}")

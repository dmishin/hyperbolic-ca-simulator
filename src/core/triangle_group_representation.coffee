M = require "./matrix3.coffee"
{mod} = require "./utils.coffee"

# exports.TriangleGroup = class TriangleGroup
#   constructor: (p,q,r) ->
#     [sp,sq,sr] = (Math.cos(Math.PI/n) for n in [p,q,r])
#     @pqr = [p,q,r]
    
#     m = [-1.0,sp,sr, \
#          sp,-1.0,sq, \
#          sr,sq,-1.0]
#     @m = m
    
#     im = M.add M.smul(2, m), M.eye()
    
#     sigma = (k) ->
#       s = M.zero()
#       e = M.eye()
#       for i in [0...3]
#         for j in [0...3]
#           M.set s, i, j, (if i is k then im else e)[i*3+j]
#       return s
#     @m_pqr = (sigma(i) for i in [0...3])
#     toString = ->
#       "Trg(#{@pqr[0]},#{@pqr[1]},#{@pqr[2]})"%self.pqr



###
# Impoementation of VD groups of order (n, m, 2)
# with 2 generators: a, b
#  and rules: a^n = b^m = abab = e
#
#  such that `a` has fixed point (0,0,1)
###
exports.CenteredVonDyck = class CenteredVonDyck
  constructor: (n, m, k=2) ->
    #a^n = b^m = (abab) = e
    {cos, sin, sqrt, PI} = Math
    alpha = PI / n
    beta = PI / m
    gamma = PI / k

    @n = n
    @m = m
    @k = k

    #Representation of generator A: rotation of the 2N-gon
    @a = M.rot 0, 1, (2*alpha)
    
    #Hyp.cosine of the distance from the center of ne 2N-gon to the order-K vertex. (when K=2, it is the center of the edge of N-gon)
    @cosh_x = (cos(beta)+cos(alpha)*cos(gamma))/(sin(alpha)*sin(gamma))
    
    #Hyp.cosine of the distance from the center of ne 2N-gon to the order-N vertex.
    @cosh_r = (cos(gamma)+cos(alpha)*cos(beta))/(sin(alpha)*sin(beta))

    if @cosh_r < 1.0 + 1e-10 #treshold
      throw new Error("von Dyck group {#{n},#{m},#{k}} is not hyperbolic, representation not supported.")
      
    @sinh_r = sqrt( @cosh_r**2 - 1 )
    @sinh_x = sqrt( @cosh_x**2 - 1 )

    #REpresentation of generator B: rotation of the 2N-gon around the vertex of order M.
    @b = M.mul( M.mul(M.hrot(0, 2, @sinh_r), M.rot(0, 1, 2*beta)), M.hrot(0, 2, -@sinh_r) )

    @aPowers = M.powers @a, n
    @bPowers = M.powers @b, m

    #Points, that are invariant under generator action. Rotation centers.
    @centerA = [0.0,0.0,1.0]
    @centerB = [@sinh_r, 0.0, @cosh_r]
    @centerAB = [@sinh_x*cos(alpha), @sinh_x*sin(alpha), @cosh_x ]

  aPower: (i) -> @aPowers[ mod i, @n ]
  bPower: (i) -> @bPowers[ mod i, @m ]
  generatorPower: (g, i)->
    if g is 'a'
      @aPower i
    else if g is 'b'
      @bPower i
    else throw new Error "Unknown generator: #{g}"
  toString: -> "CenteredVonDyck(#{@n},#{@m},#{@k})"

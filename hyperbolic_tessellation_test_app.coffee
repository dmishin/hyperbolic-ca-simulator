{Tessellation} = require "./hyperbolic_tessellation.coffee"
M = require "./matrix3.coffee"

E = (id) -> document.getElementById id

canvas = E "canvas"
context = canvas.getContext "2d"

tessellation = new Tessellation 5, 5
tfm = M.eye()



colors = ["red", "green", "blue", "yellow", "cyan", "magenta", "gray", "orange"]

powm = (m, n) ->
  mp = M.eye()
  for i in [0...n]
    mp = M.mul( mp, m)
  return mp

matrices = [M.eye()]

aPower = M.eye()
for i in [0...tessellation.group.n]
  for j in [1...tessellation.group.m-1]
    t = M.mul(powm(tessellation.group.a,i), powm(tessellation.group.b,j))
    matrices.push t

    for i1 in [0...tessellation.group.n]
      for j1 in [1...tessellation.group.m-1]
        t1 = M.mul(powm(tessellation.group.a,i1), powm(tessellation.group.b,j1))
        matrices.push M.mul(t1, t)

context.save()
context.scale 200, 200
context.translate 1, 1

for tfm, iColor in matrices    
  context.fillStyle = colors[iColor % colors.length];
  tessellation.makeCellShapePoincare( tfm, context );
  context.fill()


context.restore()

exports.ContextDelegate = class ContextDelegate
  constructor: ->
    @commands = []

  moveTo: (x,y) -> @commands.push 1, x, y
  lineTo: (x,y) -> @commands.push 2, x, y
  bezierCurveTo: (x1,y1,x2,y2,x3,y3) -> @commands.push 3, x1,y1,x2,y2,x3,y3
  closePath: -> @commands.push 4
  reset: -> @commands = []
  take: ->
    c = @commands
    @commands = []
    return c

exports.runCommands = runCommands = (context, cs) ->
  i = 0
  n = cs.length
  while i < n
    switch cs[i]
      when 1
        context.moveTo cs[i+1], cs[i+2]
        i += 3
      when 2
        context.lineTo cs[i+1], cs[i+2]
        i += 3
      when 3
        context.bezierCurveTo cs[i+1], cs[i+2], cs[i+3], cs[i+4], cs[i+5], cs[i+6]
        i += 7
      when 4
        context.closePath()
        i += 1
      else
        throw new Error "Unnown drawing command #{cs[i]}"
  return

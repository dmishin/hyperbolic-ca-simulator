"use strict";
{unity, node2array} = require "../core/vondyck_chain.coffee"
{makeXYT2path, poincare2hyperblic, hyperbolic2poincare, visibleNeighborhood, makeCellShapePoincare} = require "../core/poincare_view.coffee"
#{eliminateFinalA} = require "../core/vondyck_rewriter.coffee"
M = require "../core/matrix3.coffee"


exports.FieldObserver = class FieldObserver
  constructor: (@tiling, @minCellSize=1.0/400.0, center = unity, @tfm = M.eye())->
    
    @cells = null
    @center = null
    cells = visibleNeighborhood @tiling, @minCellSize
    @cellOffsets = (c.asStack() for c in cells)
    @isDrawingHomePtr = true
    @colorHomePtr = 'rgba(255,100,100,0.7)'
    
    if center isnt unity
      @rebuildAt center
    else
      @cells = cells
      @center = center
    
    @cellTransforms = (@tiling.repr(c) for c in cells)
    @drawEmpty = true
    @jumpLimit = 1.5
    
    
    @viewUpdates = 0
    #precision falls from 1e-16 to 1e-9 in 1000 steps.
    @maxViewUpdatesBeforeCleanup = 50
    @xyt2path = makeXYT2path @tiling
    @pattern = ["red", "black", "green", "blue", "yellow", "cyan", "magenta", "gray", "orange"]

    @onFinish = null

  getHomePtrPos: ->
    xyt = [0.0,0.0,1.0]
    #@mtx = M.mul @t.repr(generatorMatrices), generatorMatrices.generatorPower(@letter, @p)
    # xyt = genPow(head.letter, -head.p) * ... * xyt0
    #
    # reference formula.
    #     #xyt = M.mulv M.hyperbolicInv(@center.repr(@tiling)), xyt
    # it works, but matrix values can become too large.
    # 
    stack = @center.asStack()
    #apply inverse transformations in reverse order
    for [letter, p] in stack by -1
      xyt = M.mulv @tiling.representation.generatorPower(letter, -p), xyt
      #Denormalize coordinates to avoid extremely large values.
      invT = 1.0/xyt[2]
      xyt[0] *= invT
      xyt[1] *= invT
      xyt[2] = 1.0
    #Finally add view transform
    xyt = M.mulv @tfm, xyt
    #(denormalizetion not required, view transform is not large)
    # And map to poincare circle
    hyperbolic2poincare xyt #get distance too
    
  getColorForState: (state) ->
    @pattern[ (state % @pattern.length + @pattern.length) % @pattern.length ]
    
  getViewCenter: ->@center
  getViewOffsetMatrix: ->@tfm
  setViewOffsetMatrix: (m) ->
    @tfm = m
    @renderGrid @tfm
  rebuildAt: (newCenter) ->
    @center = newCenter
    @cells = for offset in @cellOffsets
      #it is important to make copy since AR empties the array!
      @tiling.toCell @tiling.appendRewrite(newCenter, offset[..])
    @_observedCellsChanged()
    return

  navigateTo: (chain, offsetMatrix=M.eye()) ->
    console.log "navigated to #{chain}"
    @rebuildAt chain
    @tfm = offsetMatrix
    @renderGrid @tfm
    return
        
  _observedCellsChanged: ->
    
  translateBy: (appendArray) ->
    #console.log  "New center at #{ newCenter}"
    @rebuildAt @tiling.appendRewrite @center, appendArray
    
  canDraw: -> true        
  draw: (cells, context) ->
    #first borders
    #cells grouped by state
    state2cellIndexList = {}
    
    for cell, i in @cells
      state = cells.get(cell) ? 0
      if (state isnt 0) or @drawEmpty
        stateCells = state2cellIndexList[state]
        unless stateCells?
          state2cellIndexList[state] = stateCells = []
        stateCells.push i
        
    for strState, cellIndices of state2cellIndexList
      state = parseInt strState, 10
      #console.log "Group: #{state}, #{JSON.stringify cellIndices}"
      
      context.beginPath()
      for cellIndex in cellIndices
        cellTfm = @cellTransforms[cellIndex]
        mtx = M.mul @tfm, cellTfm
        makeCellShapePoincare @tiling, mtx, context
        
      if state is 0
        context.stroke()
      else
        context.fillStyle = @getColorForState state
        context.fill()
    if @isDrawingHomePtr
      @drawHomePointer context
    #true because immediate-mode observer always finishes drawing.
    return true

  drawHomePointer: (context, size)->
    size = 0.06
    [x,y,d] = @getHomePtrPos()
    angle = Math.PI - Math.atan2 x, y
    
    context.save()
    context.translate x,y
    context.scale size, size
    context.rotate angle
    
    context.fillStyle = @colorHomePtr
    context.beginPath()
    
    context.moveTo 0,0
    
    context.bezierCurveTo 0.4,-0.8,  1,-1,  1,-2
    context.bezierCurveTo  1,-2.6,  0.6,-3,   0,-3
    context.bezierCurveTo  -0.6,-3,  -1,-2.6, -1,-2
    context.bezierCurveTo -1,-1,  -0.4, -0.8,  0,0

    context.closePath()
    context.fill()
    
    # context.translate 0, -1

    # context.rotate -angle    
    # context.translate 0, -1
    # context.font = "12px sans"
    
    # context.fillStyle = 'rgba(255,100,100,1.0)'
    # context.textAlign = "center"
    # context.scale 0.09, 0.09
    # context.fillText("#{Math.round(d*10)/10}", 0, 0);
    
    context.restore()
        
  visibleCells: (cells) ->
    for cell in @cells when (value=cells.get(cell)) isnt null
      [cell, value]
        
  checkViewMatrix: ->
    #me = [-1,0,0,  0,-1,0, 0,0,-1]
    #d = M.add( me, M.mul(@tfm, M.hyperbolicInv @tfm))
    #ad = (Math.abs(x) for x in d)
    #maxDiff = Math.max( ad ... )
    #console.log "Step: #{@viewUpdates}, R: #{maxDiff}"
    if (@viewUpdates+=1) > @maxViewUpdatesBeforeCleanup
      @viewUpdates = 0
      @tfm = M.cleanupHyperbolicMoveMatrix @tfm
      #console.log "cleanup"
    
  modifyView: (m) ->
    @tfm = M.mul m, @tfm
    @checkViewMatrix()
    originDistance = @viewDistanceToOrigin()
    if originDistance > @jumpLimit
      @rebaseView()
    else
      @renderGrid @tfm
    
  renderGrid: (viewMatrix) ->
    #for immediaet mode observer, grid is rendered while drawing.
    @onFinish?()
    
  viewDistanceToOrigin: ->
    #viewCenter = M.mulv tfm, [0.0,0.0,1.0]
    #Math.acosh(viewCenter[2])
    Math.acosh @tfm[8]
    
  #build new view around the cell which is currently at the center
  rebaseView: ->
    centerCoord = M.mulv M.hyperbolicInv(@tfm), [0.0, 0.0, 1.0]
    centerCoord[0] *= 1.9
    centerCoord[1] *= 1.9
    centerCoord[2] = Math.sqrt(1.0+centerCoord[0]**2 + centerCoord[1]**2)
    
    pathToCenterCell = @xyt2path centerCoord
    if pathToCenterCell is unity
      return
    #console.log "Jump by #{pathToCenterCell}"
    m = pathToCenterCell.repr @tiling

    #modifyView won't work, since it multiplies in different order.
    @tfm = M.mul @tfm, m
    @checkViewMatrix()

    #console.log JSON.stringify @tfm
    #move observation point
    @translateBy pathToCenterCell.asStack()
    @renderGrid @tfm
    
  straightenView: ->
    @rebaseView()
    originalTfm = @getViewOffsetMatrix()

    dAngle = Math.PI/@tiling.n
    minusEye = M.smul(-1, M.eye())
    distanceToEye = (m) ->
      d = M.add m, minusEye
      Math.max (Math.abs(di) for di in d) ...
    
    bestRotationMtx = null
    bestDifference = null

    angleOffsets = [0.0]
    angleOffsets.push Math.PI/2 if @tiling.n % 2 is 1
    for additionalAngle in angleOffsets
      for i in [0...2*@tiling.n]
        angle = dAngle*i + additionalAngle
        rotMtx = M.rotationMatrix angle
        difference = distanceToEye M.mul originalTfm, M.hyperbolicInv rotMtx
        if (bestDifference is null) or (bestDifference > difference)
          bestDifference = difference
          bestRotationMtx = rotMtx
    @setViewOffsetMatrix bestRotationMtx
      
    

  #xp, yp in range [-1..1]
  cellFromPoint:(xp,yp) ->
    xyt = poincare2hyperblic xp, yp
    throw new Error("point outside") if xyt is null
    #inverse transform it...
    xyt = M.mulv (M.inv @tfm), xyt
    visibleCell = @xyt2path xyt
    @tiling.toCell @tiling.appendRewrite @center, visibleCell.asStack()
    
  shutdown: -> #nothing to do.
  

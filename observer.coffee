"use strict";
{unity, showNode, node2array} = require "./vondyck_chain.coffee"
{makeXYT2path, poincare2hyperblic, visibleNeighborhood} = require "./poincare_view.coffee"
{eliminateFinalA} = require "./vondyck_rewriter.coffee"
M = require "./matrix3.coffee"


exports.FieldObserver = class FieldObserver
  constructor: (@tessellation, @appendRewrite, @minCellSize=1.0/400.0)->
    @center = unity
    @cells = visibleNeighborhood @tessellation, @appendRewrite, @minCellSize
    @cellOffsets = (node2array(c) for c in @cells)
    @cellTransforms = (c.repr(@tessellation.group) for c in @cells)
    @drawEmpty = true
    @jumpLimit = 1.5
    @tfm = M.eye()
    
    @viewUpdates = 0
    #precision falls from 1e-16 to 1e-9 in 1000 steps.
    @maxViewUpdatesBeforeCleanup = 50
    @xyt2path = makeXYT2path @tessellation.group, @appendRewrite
    @pattern = ["red", "black", "green", "blue", "yellow", "cyan", "magenta", "gray", "orange"]

    @onFinish = null
    
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
      eliminateFinalA @appendRewrite(newCenter, offset[..]), @appendRewrite, @tessellation.group.n
    @_observedCellsChanged()
    return

  navigateTo: (chain, offsetMatrix=M.eye()) ->
    console.log "navigated to #{showNode chain}"
    @rebuildAt chain
    @tfm = offsetMatrix
    @renderGrid @tfm
    return
        
  _observedCellsChanged: ->
    
  translateBy: (appendArray) ->
    #console.log  "New center at #{showNode newCenter}"
    @rebuildAt @appendRewrite @center, appendArray
    
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
        @tessellation.makeCellShapePoincare mtx, context
        
      if state is 0
        context.stroke()
      else
        context.fillStyle = @getColorForState state
        context.fill()
        
    #true because immediate-mode observer always finishes drawing.
    return true
    
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
  rebaseView1: ->
    centerCoord = M.mulv (M.inv @tfm), [0.0, 0.0, 1.0]
    pathToCenterCell = @xyt2path centerCoord
    #console.log "Jump by #{showNode pathToCenterCell}"
    m = pathToCenterCell.repr @tessellation.group

    #modifyView won't work, since it multiplies in different order.
    @tfm = M.mul @tfm, m
    @checkViewMatrix()

    #move observation point
    @translateBy node2array pathToCenterCell
  rebaseView: ->
    centerCoord = M.mulv (M.inv @tfm), [0.0, 0.0, 1.0]
    pathToCenterCell = @xyt2path centerCoord
    if pathToCenterCell is unity
      return
    #console.log "Jump by #{showNode pathToCenterCell}"
    m = pathToCenterCell.repr @tessellation.group

    #modifyView won't work, since it multiplies in different order.
    @tfm = M.mul @tfm, m
    @checkViewMatrix()

    #console.log JSON.stringify @tfm
    #move observation point
    @translateBy node2array pathToCenterCell
    @renderGrid @tfm
    
  straightenView: ->
    @rebaseView()
    originalTfm = @getViewOffsetMatrix()

    dAngle = Math.PI/@tessellation.group.n
    minusEye = M.smul(-1, M.eye())
    distanceToEye = (m) ->
      d = M.add m, minusEye
      Math.max (Math.abs(di) for di in d) ...
    
    bestRotationMtx = null
    bestDifference = null

    angleOffsets = [0.0]
    angleOffsets.push Math.PI/2 if @tessellation.group.n % 2 is 1
    for additionalAngle in angleOffsets
      for i in [0...2*@tessellation.group.n]
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
    eliminateFinalA @appendRewrite(@center, node2array(visibleCell)), @appendRewrite, @tessellation.group.n
    
  shutdown: -> #nothing to do.
  

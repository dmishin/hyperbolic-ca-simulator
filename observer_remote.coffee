"use strict"
{FieldObserver} = require "./observer.coffee"
{runCommands}= require "./context_delegate.coffee"

exports.FieldObserverWithRemoreRenderer = class FieldObserverWithRemoreRenderer extends FieldObserver
  constructor: (tessellation, appendRewrite, minCellSize=1.0/400.0)->
    super tessellation, appendRewrite, minCellSize
    @worker = new Worker "./render_worker.js"
    console.log "Worker created: #{@worker}"
    @worker.onmessage = (e) => @onMessage e

    @cellShapes = null

    @workerReady = false

    @rendering = true
    @cellSetState = 0
    @worker.postMessage ["I", [tessellation.group.n, tessellation.group.m, @cellTransforms]]
    
    @postponedRenderRequest = null

      
  _observedCellsChanged: ->
    console.log "Ignore all responces before answer..."
    @cellShapes = null
    @cellSetState+= 1
    return
        
  onMessage: (e) ->
    #console.log "message received: #{JSON.stringify e.data}"
    switch e.data[0]    
      when "I" then @onInitialized e.data[1] ...
      when "R" then @renderFinished e.data[1], e.data[2]
      else throw new Error "Unexpected answer from worker: #{JSON.stringify e.data}"
    return
    
  onInitialized: (n,m) ->
    if (n is @tessellation.group.n) and (m is @tessellation.group.m)
      console.log "Worker initialized"
      @workerReady = true
      #now waiting for first rendered field.
    else
      console.log "Init OK message received, but mismatched. Probably, late message"
      
  _runPostponed: ->
    if @postponedRenderRequest isnt null
      @renderGrid @postponedRenderRequest
      @postponedRenderRequest = null
          
  renderFinished: (renderedCells, cellSetState) ->
    #console.log "worker finished rendering #{renderedCells.length} cells"
    @rendering = false
    if cellSetState is @cellSetState
      @cellShapes = renderedCells
      @onFinish?()
    #else
    #  console.log "mismatch cell states: answer for #{cellSetState}, but current is #{@cellSetState}"
    @_runPostponed()
    
  renderGrid: (viewMatrix) ->
    if @rendering or not @workerReady
      @postponedRenderRequest = viewMatrix
    else
      @rendering = true
      @worker.postMessage ["R", viewMatrix, @cellSetState]
      
  canDraw: -> @cellShapes and @workerReady
  
  draw: (cells, context) ->
    if @cellShapes is null
      console.log "cell shapes null"
    return false if (not @cellShapes) or (not @workerReady)
    #first borders
    if @drawEmpty
      context.beginPath()
      for cell, i in @cells
        unless cells.get cell
          runCommands context, @cellShapes[i]
      context.stroke()

    #then cells
    context.beginPath()
    for cell, i in @cells
      if cells.get cell
        runCommands context, @cellShapes[i]
    context.fill()
    return true
  shutdown: ->
    @worker.terminate()

"use strict"
{E,flipSetTimeout} = require "./htmlutil.coffee"
{inverseChain, appendChain, appendInverseChain, showNode} = require "./vondyck_chain.coffee"
M = require "./matrix3.coffee"
{parseIntChecked} = require "./utils.coffee"
{formatString, pad} = require "./utils.coffee"
{decomposeToTranslations} = require "./decompose_to_translations.coffee"

interpolateHyperbolic = (T) ->
  [Trot, Tdx, Tdy] = M.hyperbolicDecompose T
  #Real distance translated is acosh( sqrt(1+dx^2+dy^2))
  Tr2 = Tdx**2 + Tdy**2
  Tdist = Math.acosh Math.sqrt(Tr2+1.0)
  Tr = Math.sqrt Tr2
  if Tr < 1e-6
    dirX = 0.0
    dirY = 0.0
  else
    dirX = Tdx / Tr
    dirY = Tdy / Tr

  return (p) ->
    rot = Trot * p
    dist = Tdist * p
    r = Math.sqrt(Math.cosh(dist)**2-1.0)
    dx = r*dirX
    dy = r*dirY
    
    M.mul M.translationMatrix(dx, dy), M.rotationMatrix(rot)  
exports.Animator = class Animator
  constructor: (@application)->
    @oldSize = null
    @uploadWorker = null
    @busy = false
    @reset()

  assertNotBusy: ->
    if @busy
      throw new Error "Animator is busy"
      
  reset: ->
    @cancelWork() if @busy
    @startChain = null
    @startOffset = null
    @endChain = null
    @endOffset = null
    @_updateButtons()
    
  _updateButtons: ->
    E('animate-view-start').disabled = @startChain is null
    E('animate-view-end').disabled = @endChain is null
    E('btn-upload-animation').disabled = (@startChain is null) or (@endChain is null)
    E('btn-animate-cancel').style.display = if @busy then '' else 'none'
    E('btn-upload-animation').style.display = unless @busy then '' else 'none'
    
    
  setStart: (observer) ->
    @assertNotBusy()
    @startChain = observer.getViewCenter()
    @startOffset = observer.getViewOffsetMatrix()
    @_updateButtons()
    
  setEnd: (observer) ->
    @assertNotBusy()
    @endChain = observer.getViewCenter()
    @endOffset = observer.getViewOffsetMatrix()
    @_updateButtons()
  viewStart: (observer) ->
    @assertNotBusy()
    observer.navigateTo @startChain, @startOffset
  viewEnd: (observer) ->
    @assertNotBusy()
    observer.navigateTo @endChain, @endOffset
    
  derotate: ->
    console.log "offset matrix:"
    console.dir @offsetMatrix()
    [t1, t2] = decomposeToTranslations @offsetMatrix()
    if t1 is null
      alert "Derotation not possible"
      return
    #@endOffset * Mdelta * @startOffset^-1 = t1^-1 * t2 * t1
    @endOffset = M.mul t1, @endOffset
    @startOffset = M.mul t1, @startOffset
    alert "Derotated OK!"
    
  _setCanvasSize: ->
    size = parseIntChecked E('animate-size').value
    if size <=0 or size >= 65536
      throw new Error("Size #{size} is inappropriate")
      
    @application.setCanvasResize true
    canvas = @application.getCanvas()
    @oldSize = [canvas.width, canvas.height]
    canvas.width = canvas.height = size
    
  _restoreCanvasSize: ->
    throw new Error("restore withou set")  unless @oldSize
    canvas = @application.getCanvas()
    [canvas.width, canvas.height] = @oldSize
    @oldSize = null
    @application.setCanvasResize false
    @application.redraw()

  _beginWork: ->
    @busy = true
    @_setCanvasSize()
    @_updateButtons()
    console.log "Started animation"
    
  _endWork: ->
    @_restoreCanvasSize()
    console.log "End animation"
    @busy = false
    @_updateButtons()
        
  cancelWork: ->
    return unless @busy
    clearTimeout @uploadWorker if @uploadWorker
    @uploadWorker = null
    @_endWork()

  #matrix between first and last points
  offsetMatrix: ->
    #global (surreally big) view matrix is:
    # 
    # Moffset * M(chain)
    #
    # where Moffset is view offset, and M(chain) is transformation matrix of the chain.
    # We need to find matrix T such that
    #
    #  T * MoffsetStart * M(chainStart) = MoffsetEnd * M(chainEnd)
    #
    # Solvign this, get:
    # T = MoffsetEnd * (M(chainEnd) * M(chainStart)^-1) * MoffsetStart^-1
    #
    # T = MoffsetEnd * M(chainEnd + invChain(chainStart) * MoffsetStart^-1
    appendRewrite = @application.getAppendRewrite()

    #Not very sure but lets try
    #Mdelta = appendInverseChain(@endChain, @startChain,appendRewrite).repr(tessellation.group)
    inv = (c) -> inverseChain(c, appendRewrite)
    app = (c1, c2) -> appendChain(c1,c2, appendRewrite)

    # e, S bad
    # S, e bad
    # 
    # E, s good? Seems to be good, but power calculation is wrong.
    Mdelta = app(inv(@endChain), @startChain ).repr(@application.getGroup())
    
    
    T = M.mul(M.mul(@endOffset, Mdelta), M.hyperbolicInv(@startOffset))
    return T
    
  animate: (observer, stepsPerGen, generations, callback)->
    return unless @startChain? and @endChain?
    @assertNotBusy()

    T = @offsetMatrix()
    
    #Make interpolator for this matrix
    Tinterp = interpolateHyperbolic M.hyperbolicInv T

    index = 0
    totalSteps = generations * stepsPerGen
    framesBeforeGeneration = stepsPerGen

    imageNameTemplate = E('upload-name').value
    @_beginWork()
    uploadStep = =>
      @uploadWorker = null
      #If we were cancelled - return quickly
      return unless @busy 
      @application.getObserver().navigateTo @startChain, @startOffset
      p = index / totalSteps
      @application.getObserver().modifyView M.hyperbolicInv Tinterp(p)
      @application.drawEverything()
      
      imageName = formatString imageNameTemplate, [pad(index,4)]
      @application.uploadToServer imageName, (ajax)=>
        #if we were cancelled, return quickly
        return unless @busy 
        if ajax.readyState is XMLHttpRequest.DONE and ajax.status is 200
          console.log "Upload success"
          index +=1
          framesBeforeGeneration -= 1
          if framesBeforeGeneration is 0
            @application.doStep()
            framesBeforeGeneration = stepsPerGen

          if index <= totalSteps
            console.log "request next frame"
            @uploadWorker = flipSetTimeout 50, uploadStep
          else
            @_endWork()
        else
          console.log "Upload failure, cancel"
          console.log ajax.responseText
          @_endWork()
          
    uploadStep()

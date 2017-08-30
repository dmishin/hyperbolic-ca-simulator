
###
# In some mobile browsers, ghost clicks can not be prevented. So here easy solution: every mouse event,
# coming after some interval after a touch event is ghost
###
exports.GhostClickDetector = class GhostClickDetector
  constructor: ->
    @isGhost = false
    @timerHandle = null
    @ghostInterval = 1000 #ms
    #Bound functions
    @_onTimer = =>
      @isGhost=false
      @timerHandle=null
    @_onTouch = =>
      @onTouch()
  onTouch: ->
    @stopTimer()
    @isGhost = true
    @timerHandle = window.setTimeout @_onTimer, @ghostInterval
    
  stopTimer: ->
    if (handle = @timerHandle)
      window.clearTimeout handle
      @timerHandle = null
  addListeners: (element)->
    for evtName in ["touchstart", "touchend"]
      element.addEventListener evtName, @_onTouch, false
      

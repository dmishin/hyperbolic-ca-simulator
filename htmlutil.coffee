#I am learning JS and want to implement this functionality by hand

exports.flipSetTimeout = (t, cb) -> setTimeout cb, t

exports.E = E = (id) -> document.getElementById id

# Remove class from the element
exports.removeClass = removeClass = (e, c) ->
  e.className = (ci for ci in e.className.split " " when c isnt ci).join " "
  
exports.addClass = addClass = (e, c) ->
  e.className =
    if (classes = e.className) is ""
      c
    else
      classes + " " + c
      
idOrNull = (elem)->
  if elem is null
    null
  else
    elem.getAttribute "id"

exports.ButtonGroup = class ButtonGroup
  constructor: (containerElem, tag, selectedId=null, @selectedClass="btn-selected")->
    if selectedId isnt null
      addClass (@selected = E selectedId), @selectedClass
    else
      @selected = null
      
    @handlers = change: []
    for btn in containerElem.getElementsByTagName tag
      btn.addEventListener "click", @_btnClickListener btn
    return

  _changeActiveButton: (newBtn, e)->
    newId = idOrNull newBtn
    oldBtn = @selected
    oldId = idOrNull oldBtn
    if newId isnt oldId
      if oldBtn isnt null then removeClass oldBtn, @selectedClass
      if newBtn isnt null then addClass newBtn, @selectedClass
      @selected = newBtn
      for handler in @handlers.change
        handler( e, newId, oldId )
      return
    
  _btnClickListener: (newBtn) -> (e) => @_changeActiveButton newBtn, e
    
  addEventListener: (name, handler)->
    unless (handlers = @handlers[name])?
      throw new Error "Hander #{name} is not supported"
    handlers.push handler
    
  setButton: (newId) ->
    if newId is null
      @_changeActiveButton null, null
    else
      @_changeActiveButton document.getElementById(newId), null

exports.windowWidth = ->
  #http://stackoverflow.com/questions/3437786/get-the-size-of-the-screen-current-web-page-and-browser-window
  window.innerWidth \
    || document.documentElement.clientWidth\
    || document.body.clientWidth
exports.windowHeight = ->
  window.innerHeight \
    || document.documentElement.clientHeight\
    || document.body.clientHeight

exports.documentWidth = ->
    document.documentElement.scrollWidth\
    || document.body.scrollWidth



if not HTMLCanvasElement.prototype.toBlob?
  Object.defineProperty HTMLCanvasElement.prototype, 'toBlob', {
    value: (callback, type, quality) -> 
      binStr = atob @toDataURL(type, quality).split(',')[1]
      len = binStr.length
      arr = new Uint8Array(len)
      for i in [0...len] by 1
         arr[i] = binStr.charCodeAt(i)
      callback new Blob [arr], {type: type || 'image/png'}
  }


exports.Debouncer = class Debouncer
  constructor: (@timeout, @callback) ->
    @timer = null
  fire:  ->
    if @timer
      clearTimeout @timer
    @timer = setTimeout (=>@onTimer()), @timeout
  onTimer: ->
    @timer = null
    @callback()


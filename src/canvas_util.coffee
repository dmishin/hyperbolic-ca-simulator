#taken from http://www.html5canvastutorials.com/advanced/html5-canvas-mouse-coordinates/
exports.getCanvasCursorPosition = (e, canvas) ->
  if e.type is "touchmove" or e.type is "touchstart" or e.type is "touchend"
    e=e.touches[0]
  if e.clientX?
    rect = canvas.getBoundingClientRect()
    return [e.clientX - rect.left, e.clientY - rect.top]

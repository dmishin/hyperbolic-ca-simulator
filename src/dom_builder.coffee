#########
# Let's make a bicycle!
#
exports.DomBuilder = class DomBuilder
  constructor: ( tag=null ) ->
    @root = root =
      if tag is null
        document.createDocumentFragment()
      else
        document.createElement tag
    @current = @root
    @vars = {}
        
  tag: (name) ->
    @current.appendChild e=document.createElement name
    @current = e
    this
  store: (varname) ->
    @vars[varname] = @current
    this
  rtag: (var_name, name) ->
    @tag name
    @store var_name
  end: ->
    @current = cur = @current.parentNode
    throw new Error "Too many end()'s" if cur is null
    this

  text: (txt) ->
    @current.appendChild document.createTextNode txt
    this      

  a: (name, value) ->
    @current.setAttribute name, value
    this
    
  append: (elementReference) ->
    @current.appendChild elementReference
    this
    
  DIV: -> @tag "div"
  A: -> @tag "a"
  SPAN: -> @tag "span"

  ID: (id) -> @a "id", id
  CLASS: (cls) -> @a "class", cls

  finalize: ->
    r = @root
    @root = @current = @vars = null
    r
#Usage:
# dom = new DimBuilder
# dom.tag("div").a("id", "my-div").a("class","toolbar").end()
# 

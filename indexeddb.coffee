#Storing and loading configuration in/from IndexedDB
#
# DB structure:
#  Table: catalog
#{
#    name: str
#    gridN: int
#    gridM: int
#    fucntionType: str (binary / Day-Night binary / Custom) 
#    functionId:str (code for binary, hash for custom)
#
# Table: files
#    key: id (autoincrement)
#    value: fieldData (stringified)

{E,removeClass, addClass} = require "./htmlutil.coffee"
{DomBuilder} = require "./dom_builder.coffee"

M = require "./matrix3.coffee"

VERSION = Date.now()

#Using info from https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API/Using_IndexedDB
# 
window.indexedDB = window.indexedDB ? window.mozIndexedDB ? window.webkitIndexedDB ? window.msIndexedDB
# This line should only be needed if it is needed to support the object's constants for older browsers
window.IDBTransaction = window.IDBTransaction ? window.webkitIDBTransaction ? window.msIDBTransaction ? {READ_WRITE: "readwrite"}
window.IDBKeyRange = window.IDBKeyRange ? window.webkitIDBKeyRange ? window.msIDBKeyRange

exports.hasDbSupport = -> window.indexedDB?

exports.OpenDialog = class OpenDialog
  constructor: (@application) ->
    @container = E('file-dialog')
    @btnCancel = E('btn-files-cancel')
    @filelistElement = E('file-dialog-files')

    @btnAllGrids = E('toggle-all-grids')
    @btnAllRules = E('toggle-all-rules')

    @allGridsEnabled = false
    @allRuelsEnabled = false

    #Bind events
    @btnAllRules.addEventListener 'click', (e)=>@_toggleAllRules()
    @btnAllGrids.addEventListener 'click', (e)=>@_toggleAllGrids()
    @btnCancel.addEventListener 'click', (e)=>@close()
  
  show: ->
    E('file-dialog-title').innerHTML = "Load from local database"
    @_updateUI()
    @container.style.display = ''

    @_generateFileList()
    
  _generateFileList: ->
    @filelistElement.innerHTML = '<img src="media/hrz-spinner.gif"/>'
    grid = if @allGridsEnabled then null else [@application.getGroup().n, @application.getGroup().m]
    rule = if @allGridsEnabled or @allRuelsEnabled
      null
    else
      ""+@application.getTransitionFunc()
      
    fileListGen = new GenerateFileList grid, rule, @filelistElement,
      (fileObj)=>@_loadFile(fileObj),
      =>@_fileListReady()

  _loadFile: (fileObj)->
    console.log "Loading file:"
    console.dir fileObj
    @close()
    
  _fileListReady: ->
    console.log "File list ready"
    
  close: ->
    @container.style.display = 'none'

  #Update state of the used interface.
  _updateUI: ->
    #WHen all grids are enabled, enable all ruels automaticelly.
    @btnAllRules.disabled = @allGridsEnabled

    removeClass @btnAllGrids, 'button-active'
    removeClass @btnAllRules, 'button-active'

    if @allGridsEnabled
      addClass @btnAllGrids, 'button-active'
    if @allRuelsEnabled or @allGridsEnabled
      addClass @btnAllRules, 'button-active'

  _toggleAllGrids: ->
    @allGridsEnabled = not @allGridsEnabled
    @_updateUI()
    @_generateFileList()
    
  _toggleAllRules: ->
    @allRuelsEnabled = not @allRuelsEnabled
    @_updateUI()
    @_generateFileList()

  
exports.GenerateFileList = class GenerateFileList
  constructor: (grid, rule, @container, @fileCallback, @readyCallback) ->
    self.db = null

    @status = "working"
    @populated = true
    
    request = window.indexedDB.open "SavedFields", VERSION
    request.onupgradeneeded = (e) => @upgradeNeeded e
    request.onerror = (e) =>
      console.log "DB error: #{e.target.errorCode}"
      @status="error"      
    request.onsuccess = (e)=>
      @db = e.target.result
      console.log "Success"
      @addSampleFiles =>
        
        if grid is null
          console.log "Loading whole list"
          @loadData()
        else
          console.log "Loading data: {#{grid[0]};#{grid[1]}}, rule='#{rule}'"
          @loadDataFor grid[0], grid[1], rule
    
  upgradeNeeded: (e)->
    console.log "Upgrade !"
    
    db = e.target.result
    if db.objectStoreNames.contains "files"
      console.log "Dropping files..."
      db.deleteObjectStore "files"
    if db.objectStoreNames.contains "catalog"
      console.log "Dropping catalog"
      db.deleteObjectStore "files"
      
    @fileStore = db.createObjectStore "files"
    @catalogStore = db.createObjectStore "catalog"
    
    @populated = false

  loadFromCursor: (cursor) ->
    dom = new DomBuilder()

    startGridGroup = (gridName) ->
      dom.tag("div").CLASS("files-grid-group")
         .tag("h1").text("Grid: #{gridName}").end()
    closeGridGroup = ->
      dom.end()
      
    startFuncGroup = (funcType, funcId) ->
      funcName = "#{funcType}: #{funcId}"
      dom.tag("div").CLASS("files-func-group")
         .tag("h2").text("Rule: #{funcName}").end()
         .tag("table").tag("thead").tag("tr")
         .tag("th").text("Name").end().tag("th").text("Size").end()
         .end().end()
         .tag("tbody")
        
    closeFuncGroup = ->
      dom.end().end().end() #tbody table div

    lastGrid = null
    lastFunc = null
    
    cursor.onsuccess = (e)=>
      res = e.target.result
      console.log "Load file: #{res.key}" if res?
      if res
        record = res.value
        
        grid = "{#{record.gridN};#{record.gridM}}"
        if grid isnt lastGrid
          #loading next group
          #close the previous group
          closeFuncGroup() if lastFunc isnt null
          closeGridGroup() if lastGrid isnt null
          startGridGroup grid
          lastGrid = grid
          lastFunc = null

        if record.funcId isnt lastFunc
          closeFuncGroup() if lastFunc isnt null
          startFuncGroup record.funcType, record.funcId
          lastFunc = record.funcId

        dom.tag('tr')
           .tag('td').rtag('alink','a').a('href',"#load#{record.name}").text(res.value.name).end().end()
           .tag('td').text(""+res.value.field.length).end()
           .end()
        #dom.tag('div').CLASS("file-list-file").text(res.value.name).end()
        dom.vars.alink.addEventListener "click", ((key)=> (e) =>
          e.preventDefault()
          @clickedFile key
          )(res.key)
          
        res.continue()
      else
        closeFuncGroup() if lastFunc isnt null
        closeGridGroup() if lastGrid isnt null
        @container.innerHTML = ""
        @container.appendChild dom.finalize()
        @readyCallback()

        
  clickedFile: (key) ->
    console.log "Load key #{key}"
    transaction = @db.transaction ["files"], "readonly"
    filesStore = transaction.objectStore "files"
    cursor = filesStore.openCursor key
    cursor.onerror = (e) ->
      console.log "Failed to load file #{key}"
      
    cursor.onsuccess = (e) =>
      res = e.target.result
      @fileCallback res.value
    
  loadData:  ->
    console.log "Loaddata"
    transaction = @db.transaction ["files"], "readonly"
    filesStore = transaction.objectStore "files"
    cursor = filesStore.openCursor()
    @loadFromCursor cursor

  loadDataFor: (gridN, gridM, funcId) ->
    transaction = @db.transaction ["files"], "readonly"
    filesStore = transaction.objectStore "files"
    #create range

    # key is N, M, func, name
    if funcId?
      start = @key(gridN, gridM, funcId, "")
      end= @key(gridN, gridM, funcId+" ", "")
    else
      start = @key(gridN, gridM, "","")
      end = @key(gridN, gridM+1, "","")
      
    console.log "Range: from #{start} to #{end}"
    range = IDBKeyRange.bound start, end, false, true
    
    cursor = filesStore.openCursor range
    @loadFromCursor cursor
    

  addSampleFiles:  (onFinish) ->
    # Add few random riles.
    # Transaction commits, when the last onsuccess does not schedules any more requests.
    #
    transaction = @db.transaction(["files", "catalog"],"readwrite");
    filesStore = transaction.objectStore "files"
    catalogStore = transaction.objectStore "catalog"
    i = 0
    doAdd = =>
      fieldData = "|1"
      rqStoreData = filesStore.put fieldData
      rqStoreData.onerror = (e)=>
        console.log "Error storing data #{e.target.error}"
      rqStoreData.onsuccess = (e)=>
        console.log "Stored data OK, key is #{e.target.key}"
        key = e.target.key
        console.log "Store catalog record"
        catalogRecord =
          gridN: (Math.random()*4)|0+4
          gridM: (Math.random()*4)|0+4
          name: "File #{i+1}"
          funcId: "B 3 S 2 3"
          funcType: "binary"
          base: 'e'
          offset: M.eye()
          field: key

        rqStoreCatalog = filesStore.put catalogRecord
        rqStoreCatalog.onerror = (e)=>
          console.log "Error storing data #{e.target.error}"
        rqStoreCatalog.onsuccess = (e)=>
          console.log "catalog record stored OK"
          
          if i < 3000
            #console.log "Adding next file"
            i += 1
            doAdd()
          else
            console.log "End generatign #{i} files"
            @populated = true
            onFinish()
    if not @populated
      console.log "Generating sample data"
      doAdd()
    else
      onFinish()
    

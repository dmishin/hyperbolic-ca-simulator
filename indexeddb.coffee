#Storing and loading configuration in/from IndexedDB
#
# DB structure:
#  Table: architectures
#{
#    name: str
#    gridN: int
#    gridM: int
#    fucntionType: str (binary / Day-Night binary / Custom) 
#    functionId:str (code for binary, hash for custom)
#    field: ste (stringified)
#

{E} = require "./htmlutil.coffee"
{DomBuilder} = require "./dom_builder.coffee"

#Using info from https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API/Using_IndexedDB
# 
window.indexedDB = window.indexedDB ? window.mozIndexedDB ? window.webkitIndexedDB ? window.msIndexedDB
# This line should only be needed if it is needed to support the object's constants for older browsers
window.IDBTransaction = window.IDBTransaction ? window.webkitIDBTransaction ? window.msIDBTransaction ? {READ_WRITE: "readwrite"}
window.IDBKeyRange = window.IDBKeyRange ? window.webkitIDBKeyRange ? window.msIDBKeyRange

exports.hasDbSupport = -> window.indexedDB?

exports.GenerateFileList = class GenerateFileList
  constructor: ->
    unless (@container = E 'file-dialog-files')?
      throw new Error "Container not found"
    self.db = null

    @status = "working"
    
    request = window.indexedDB.open "SavedFields", Date.now()
    request.onupgradeneeded = (e) => @upgradeNeeded e
    request.onerror = (e) =>
      console.log "DB error: #{e.target.errorCode}"
      @status="error"      
    request.onsuccess = (e)=>
      @db = e.target.result
      console.log "Success, first run: #{@firstrun}"
      @addSampleFiles =>
        @loadDataFor 3, 4
    
  upgradeNeeded: (e)->
    console.log "Upgrade !"
    
    db = e.target.result
    if db.objectStoreNames.contains "files"
      console.log "Dropping files..."
      db.deleteObjectStore "files"
    @fileStore = db.createObjectStore "files"

  recordKey: (rcd) -> @key rcd.gridN, rcd.gridM, rcd.funcId, rcd.name
  
  key: (n, m, func, name) ->
    paddedNum = (x) -> ("0000" + x.toString(16)).substr(4)
    "#{paddedNum n}$#{paddedNum m}$#{func}$#{name}"
    
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
        
  clickedFile: (key) -> console.log "Load key #{key}"
    
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
      range = IDBKeyRange.bound @key(gridN, gridM, funcId, ""), @key(gridN, gridM, funcId+" ", ""), false, true
    else
      range = IDBKeyRange.bound @key(gridN, gridM, "",""), @key(gridN, gridM+1, "",""), false, true
    
    cursor = filesStore.openCursor range
    @loadFromCursor cursor
    

  addSampleFiles:  (onFinish) ->
    # Add few random riles.
    # Transaction commits, when the last onsuccess does not schedules any more requests.
    #
    transaction = @db.transaction(["files"],"readwrite");
    filesStore = transaction.objectStore "files"
    i = 0
    doAdd = =>
      sampleFile =
        gridN: (i/2)|0+3
        gridM: (i/3)|0+4
        name: "File #{i+1}"
        funcId: "B 3 S 2 3"
        funcType: "binary"
        field: "|1"
      key = @recordKey sampleFile
      #console.log "Key: #{key}"
      # 
      request = filesStore.add sampleFile, key
      request.onerror = (e)=>
        console.log "error adding file"
        console.dir e.target.error
      request.onsuccess = =>
        #console.log "file added successfully"
        if i < 3000
          #console.log "Adding next file"
          i += 1
          doAdd()
        else
          console.log "End"
          onFinish()
          
    doAdd()
    

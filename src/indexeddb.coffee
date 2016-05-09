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

VERSION = 1

#Using info from https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API/Using_IndexedDB
# 
window.indexedDB = window.indexedDB ? window.mozIndexedDB ? window.webkitIndexedDB ? window.msIndexedDB
# This line should only be needed if it is needed to support the object's constants for older browsers
window.IDBTransaction = window.IDBTransaction ? window.webkitIDBTransaction ? window.msIDBTransaction ? {READ_WRITE: "readwrite"}
window.IDBKeyRange = window.IDBKeyRange ? window.webkitIDBKeyRange ? window.msIDBKeyRange

exports.hasDbSupport = -> window.indexedDB?

upgradeNeeded = (e)->
  console.log "Upgrade !"
  
  db = e.target.result
  if db.objectStoreNames.contains "files"
    console.log "Dropping files..."
    db.deleteObjectStore "files"
  if db.objectStoreNames.contains "catalog"
    console.log "Dropping catalog"
    db.deleteObjectStore "catalog"

  console.log "Create files and database store"
  db.createObjectStore "files", {autoIncrement: true}
  catalogStore = db.createObjectStore "catalog", {autoIncrement: true}

  catalogStore.createIndex "catalogByGrid", ['gridN', 'gridM', 'funcId', 'name', 'time'], {unique: false}



exports.OpenDialog = class OpenDialog
  constructor: (@application) ->
    @container = E('file-dialog-open')
    @btnCancel = E('btn-files-cancel')
    @filelistElement = E('file-dialog-files')

    @btnAllGrids = E('toggle-all-grids')
    @btnAllRules = E('toggle-all-rules')

    @allGridsEnabled = false
    @allRuelsEnabled = false
    @fileList = null

    #Bind events
    @btnAllRules.addEventListener 'click', (e)=>@_toggleAllRules()
    @btnAllGrids.addEventListener 'click', (e)=>@_toggleAllGrids()
    @btnCancel.addEventListener 'click', (e)=>@close()
    
    
  show: ->
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
      
    @fileList = new GenerateFileList grid, rule, @filelistElement,
      (fileRecord, fileData)=>@_loadFile(fileRecord, fileData),
      =>@_fileListReady()

  _loadFile: (fileRecord, fileData)->
    @application.loadData fileRecord, fileData
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

exports.SaveDialog = class SaveDialog
  constructor: (@application) ->
    @container = E('file-dialog-save')
    @btnCancel = E('btn-files-save-cancel')
    @btnSave = E('file-dialog-save-btn')
    @fldName = E('file-dialog-save-as')
    @filelistElement = E('file-dialog-save-files')

    @allGridsEnabled = false
    @allRuelsEnabled = false

    #Bind events
    @btnCancel.addEventListener 'click', (e)=>@close()
    
    @btnSave.addEventListener 'click', (e)=>@save()
    @fldName.addEventListener 'change', (e)=>@save()
  show: ->
    @_updateUI()
    @container.style.display = ''
    @_generateFileList()
    @fldName.focus()
    @fldName.select()
    
  _updateUI: ->
    
  _generateFileList: ->
    @filelistElement.innerHTML = '<img src="media/hrz-spinner.gif"/>'
    grid = [@application.getGroup().n, @application.getGroup().m]
    rule = ""+@application.getTransitionFunc()
      
    fileListGen = new GenerateFileList grid, rule, @filelistElement,
      null,
      =>@_fileListReady()
      
  _fileListReady: ->
    console.log "list ready"
    
  close: ->
    @container.style.display = 'none'
    
  save: ->
    console.log "Saving!"
    
    fname = @fldName.value
    unless fname
      alert "File name can not be empty"
      return
    [fieldData, catalogRecord] = @application.getSaveData(fname)


    request = window.indexedDB.open "SavedFields", VERSION
    request.onupgradeneeded = upgradeNeeded
    
    request.onerror = (e) =>
      console.log "DB error: #{e.target.errorCode}"
      
    request.onsuccess = (e)=>
      db = e.target.result
                
      transaction = db.transaction(["files", "catalog"],"readwrite");
      rqStoreData = transaction.objectStore("files").add fieldData
      rqStoreData.onerror = (e)=>
        console.log "Error storing data #{e.target.error}"
      rqStoreData.onsuccess = (e)=>
        key = e.target.result
        catalogRecord.field= key
        rqStoreCatalog = transaction.objectStore("catalog").add catalogRecord
        rqStoreCatalog.onerror = (e)=>
          console.log "Error storing catalog record #{e.target.error}"
        rqStoreCatalog.onsuccess = (e)=>
          @fileSaved()
  fileSaved: ->
    console.log "File saved OK"
    @close()

  
class GenerateFileList
  constructor: (@grid, @rule, @container, @fileCallback, @readyCallback) ->
    self.db = null

    @status = "working"
    @recordId2Controls = {}
    @_generateFileList()
    
  _generateFileList: ->
    request = window.indexedDB.open "SavedFields", VERSION
    request.onupgradeneeded = upgradeNeeded
    request.onerror = (e) =>
      console.log "DB error: #{e.target.errorCode}"
      @status="error"      
    request.onsuccess = (e)=>
      @db = e.target.result
      console.log "Success"
      if @grid is null
        console.log "Loading whole list"
        @loadData()
      else
        console.log "Loading data: {#{@grid[0]};#{@grid[1]}}, rule='#{@rule}'"
        @loadDataFor @grid[0], @grid[1], @rule

  selectAll: (selected) ->
    for _, controls of @recordId2Controls
      controls.check.checked = selected
      

  selectedIds: -> ([id|0, controls.record] for id, controls of @recordId2Controls when controls.check.checked)

  deleteSelected: ->
    ids = @selectedIds()
    if ids.length is 0
      return
    else if ids.length is 1
      if not confirm "Are you sure to delete \"#{ids[0][1].name}\"?"
        return
    else 
      if not confirm "Are you sure to delete #{ids.length} files?"
        return
    @_deleteIds ids
    
  _deleteIds: (ids) ->
    indexedDB.open("SavedFields", VERSION).onsuccess = (e)=>
      db = e.target.result
      request = db.transaction(["catalog", "files"], "readwrite")
      catalog = request.objectStore "catalog"
      files = request.objectStore "files"
       
      idx = 0
      doDelete = =>
        [catalogKey, record] = ids[idx]
        rq=catalog.delete(catalogKey).onsuccess = (e)=>
          files.delete(record.field).onsuccess = (e)=>
            idx += 1
            if idx >= ids.length
              console.log "Deleted selected fiels"
            else
              doDelete()
      request.oncomplete = (e)=>
        @_generateFileList()
      doDelete()
    
  loadFromCursor: (cursor, predicate) ->
    dom = new DomBuilder()

    dom.tag('div').CLASS('toolbar')
         .tag('span').CLASS('button-group')
         .text('Select:').rtag('btnSelectAll', 'button').CLASS('button-small').text('All').end()
                         .rtag('btnSelectNone', 'button').CLASS('button-small').text('None').end()
       .end()
       .tag('span').CLASS('button-group')
         .rtag('btnDeleteAll', 'button').CLASS('dangerous button-small').a('title','Delete selected files').text('Delete').end()
       .end()
       .end()



    dom.vars.btnDeleteAll.addEventListener 'click', (e)=>@deleteSelected()
    dom.vars.btnSelectNone.addEventListener 'click', (e)=>@selectAll(false)
    dom.vars.btnSelectAll.addEventListener 'click', (e)=>@selectAll(true)
    
    dom  .tag("table").CLASS("files-table").tag("thead").tag("tr")
         .tag("th").end().tag("th").text("Name").end().tag("th").text("Time").end()
         .end().end()
         .tag("tbody")

    startGridGroup = (gridName) ->
      dom.tag("tr").CLASS("files-grid-row")
         .tag("td").a('colspan','3').text("Grid: #{gridName}").end()
         .end()
        
    closeGridGroup = ->
      
    startFuncGroup = (funcType, funcId) ->
      funcName = "#{funcType}: #{funcId}"
      dom.tag("tr").CLASS("files-func-row")
         .tag("td").a('colspan','3').text("Rule: #{funcName}").end()
         .end()
        
    closeFuncGroup = ->

    lastGrid = null
    lastFunc = null
    filesEnumerated = 0
    
    onRecord = (res, record)=>
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

      dom.tag('tr').CLASS('files-file-row')
         .tag('td').rtag('filesel', 'input').a('type','checkbox').end().end()
        
      if @fileCallback?
         dom.tag('td').rtag('alink','a').a('href',"#load#{record.name}").text(res.value.name).end().end()
      else
         dom.tag('td').text(res.value.name).end()
      
      dom.tag('td').text((new Date(res.value.time)).toLocaleString()).end()
         .end()
        
      #dom.tag('div').CLASS("file-list-file").text(res.value.name).end()
      if dom.vars.alink?
        dom.vars.alink.addEventListener "click", ((key)=> (e) =>
          e.preventDefault()
          @clickedFile key
          )(record)
        
      @recordId2Controls[res.primaryKey] =
        check: dom.vars.filesel
        record: record
            
    cursor.onsuccess = (e)=>
      res = e.target.result
      if res
        filesEnumerated += 1
        record = res.value
        if predicate record
          onRecord res, record
        res.continue()
      else
        closeFuncGroup() if lastFunc isnt null
        closeGridGroup() if lastGrid isnt null
        @container.innerHTML = ""
        @container.appendChild dom.finalize()
        console.log "Enumerated #{filesEnumerated} files"
        @readyCallback()

        
  clickedFile: (catalogRecord) ->
    console.log "Load key #{JSON.stringify(catalogRecord)}"
    transaction = @db.transaction ["files"], "readonly"
    filesStore = transaction.objectStore "files"
    request = filesStore.get catalogRecord.field
    request.onerror = (e) ->
      console.log "Failed to load file #{catalogRecord.field}"
      
    request.onsuccess = (e) =>
      res = e.target.result
      @fileCallback catalogRecord, res
    
  loadData:  ->
    console.log "Loaddata"
    transaction = @db.transaction ["catalog"], "readonly"
    filesStore = transaction.objectStore "catalog"
    cursor = filesStore.index("catalogByGrid").openCursor()
    @loadFromCursor cursor, (rec)->true

  loadDataFor: (gridN, gridM, funcId) ->
    transaction = @db.transaction ["catalog"], "readonly"
    catalog = transaction.objectStore "catalog"
    catalogIndex = catalog.index "catalogByGrid"
    cursor = catalogIndex.openCursor()
    @loadFromCursor cursor, (rec)->
      (rec.gridN is gridN) and (rec.gridM is gridM) and ((funcId is null) or (rec.funcId is funcId))
    

  # addSampleFiles:  (onFinish) ->
  #   # Add few random riles.
  #   # Transaction commits, when the last onsuccess does not schedules any more requests.
  #   #
  #   transaction = @db.transaction(["files", "catalog"],"readwrite");
  #   filesStore = transaction.objectStore "files"
  #   catalogStore = transaction.objectStore "catalog"
  #   i = 0
  #   doAdd = =>
  #     fieldData = "|1"
  #     rqStoreData = filesStore.add fieldData
  #     rqStoreData.onerror = (e)=>
  #       console.log "Error storing data #{e.target.error}"
  #     rqStoreData.onsuccess = (e)=>
  #       #console.log "Stored data OK, key is #{e.target.result}"
  #       #console.dir e.target
  #       key = e.target.result
  #       #console.log "Store catalog record"
  #       catalogRecord =
  #         gridN: ((Math.random()*5)|0)+3
  #         gridM: ((Math.random()*5)|0)+3
  #         name: "File #{i+1}"
  #         funcId: "B 3 S 2 3"
  #         funcType: "binary"
  #         base: 'e'
  #         size: fieldData.length
  #         time: Date.now()
  #         offset: M.eye()
  #         field: key

  #       rqStoreCatalog = catalogStore.add catalogRecord
  #       rqStoreCatalog.onerror = (e)=>
  #         console.log "Error storing catalog record #{e.target.error}"
  #       rqStoreCatalog.onsuccess = (e)=>
  #         #console.log "catalog record stored OK"
          
  #         if i < 300
  #           #console.log "Adding next file"
  #           i += 1
  #           doAdd()
  #         else
  #           console.log "End generatign #{i} files"
  #           onFinish()
  #   #if not @populated
  #   #  console.log "Generating sample data"
  #   #  doAdd()
  #   #else
  #   #  onFinish()
    

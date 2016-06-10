#Hash map that uses chain as key
exports.NodeHashMap = class NodeHashMap
  constructor: (initialSize = 16) ->
    #table size MUST be power of 2! Or else write your own implementation of % that works with negative hashes.
    if initialSize & (initialSize-1) isnt 0 #this trick works!
      throw new Error "size must be power of 2"
    @table = ([] for i in [0...initialSize] by 1)
    @count = 0
    @maxFillRatio = 0.7
    
    @sizeMask = initialSize - 1

  _index: (chain) -> chain.hash() & @sizeMask
    
  putAccumulate: (chain, value, accumulateFunc, accumulateInitial)->
    cell = @table[@_index chain]

    for key_value in cell
      if key_value[0].equals chain
        #Update existing value
        key_value[1] = accumulateFunc key_value[1], value
        return
        
    cell.push [chain, accumulateFunc(accumulateInitial, value)]
    @count += 1
    if @count > @maxFillRatio*@table.length
      @_growTable()
    return this
          
  put: (chain, value) -> @putAccumulate chain, value, (x,y)->y

  get: (chain) ->
    # console.log "geting for #{showNode chain}"
    for key_value in @table[@_index chain]
      if key_value[0].equals chain
        #console.log "   found something"
        return key_value[1]
    #console.log "   not found"
    return null
    
  remove: (chain) ->
    tableCell = @table[@_index chain]
    for key_value, index in tableCell
      if key_value[0].equals chain
        tableCell.splice index, 1
        @count -= 1
        return true
    return false
    
  _growTable: ->
    newTable = new NodeHashMap (@table.length * 2)
    #console.log "Growing table to #{newTable.table.length}"
    for cell in @table
      for [key, value] in cell
        newTable.put key, value
    @table = newTable.table
    @sizeMask = newTable.sizeMask
    return
      
  forItems: (callback) ->
    for cell in @table
      for [key, value] in cell
        callback key, value
    return    

  copy: ->
    copied = new NodeHashMap 1 #minimal size

    copied.count = @count
    copied.maxFillRatio = @maxFillRatio
    copied.sizeMask = @sizeMask
    
    copied.table = for cell in @table
      for key_value in cell
        key_value[..]

    return copied

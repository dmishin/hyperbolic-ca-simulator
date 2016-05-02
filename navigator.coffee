#search for cell  clusters and navigate through them

{eliminateFinalA, NodeHashMap, chainLen} = require "./vondyck_chain.coffee"
{mooreNeighborhood, allClusters} = require "./field.coffee"
{DomBuilder} = require "./dom_builder.coffee"
{E} = require "./htmlutil.coffee"

exports.Navigator = class Navigator
  constructor: (@application, navigatorElemId="navigator-cluster-list", btnClearId="btn-nav-clear") ->
    @clustersElem = E navigatorElemId
    @btnClear = E btnClearId
    @clusters = []
    @btnClear.style.display = 'none'
    
  search: (field)->
    #field is NodeHashMap
    n = @application.getGroup().n
    m = @application.getGroup().m
    
    @clusters = allClusters field, n, m, @application.getAppendRewrite()
    @sortByDistance()
    @updateClusterList()
    @btnClear.style.display = if @clusters then '' else 'none'
    return @clusters.length

  sortByDistance: ->
    @clusters.sort (a, b) ->
      d = chainLen(b[0]) - chainLen(a[0])
      return d if d isnt 0
      d = b.length - a.length
      return d
      
  sortBySize: ->
    @clusters.sort (a, b) ->
      d = b.length - a.length
      return d if d isnt 0
      d = chainLen(b[0]) - chainLen(a[0])
      return d
      
  makeNavigateTo: (chain) -> (e) =>
    e.preventDefault()
    #console.log JSON.stringify chain
    observer = @application.getObserver()
    if observer?
      observer.navigateTo chain
    return

  navigateToResult: (index) ->
    observer = @application.getObserver()
    if observer?
      observer.navigateTo @clusters[index][0]
        
  clear: ->
    @clusters = []
    @clustersElem.innerHTML = ""
    @btnClear.style.display = 'none'
    
  updateClusterList: ->
    dom = new DomBuilder

    dom.tag("table")
       .tag("thead")
       .tag('tr')
          .tag('th').rtag('ssort').a("href","#sort-size").text('Cells').end().end()
          .tag('th').rtag('dsort').a("href","#sort-dist").text('Distance').end().end()
       .end()
       .end()
      
    dom.vars.ssort.addEventListener 'click', (e)=>
      e.preventDefault()
      @sortBySize()
      @updateClusterList()
    dom.vars.dsort.addEventListener 'click', (e)=>
      e.preventDefault()
      @sortByDistance()
      @updateClusterList()
    
    dom.tag "tbody"
    for cluster, idx in @clusters
      size = cluster.length
      dist = chainLen cluster[0]

      dom.tag("tr")
         .tag("td")
           .rtag("navtag", "a").a("href", "#nav-cluster#{idx}").text("#{size}").end()
         .end()
         .tag('td')
         .rtag("navtag1", "a").a("href", "#nav-cluster#{idx}").text("#{dist}").end()
         .end()
         .end()

      listener = @makeNavigateTo cluster[0]
      dom.vars.navtag.addEventListener "click", listener
      dom.vars.navtag1.addEventListener "click", listener        
      
    dom.end()
    
    @clustersElem.innerHTML = ""
    @clustersElem.appendChild dom.finalize()
  

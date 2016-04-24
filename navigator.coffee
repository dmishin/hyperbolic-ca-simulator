#search for cell  clusters and navigate through them

{eliminateFinalA, NodeHashMap, chainLen} = require "./vondyck_chain.coffee"
{mooreNeighborhood, allClusters} = require "./field.coffee"
{DomBuilder} = require "./dom_builder.coffee"
{E} = require "./htmlutil.coffee"

exports.Navigator = class Navigator
  constructor: (@observer, navigatorElemId="navigator-cluster-list", btnClearId="btn-nav-clear") ->
    @clustersElem = E navigatorElemId
    @btnClear = E btnClearId
    @clusters = []
    @btnClear.style.display = 'none'
    
  search: (field, n, m, appendRewrite)->
    #field is NodeHashMap
    @clusters = allClusters field, n, m, appendRewrite
    @updateClusterList()
    @btnClear.style.display = if @clusters then '' else 'none'  

  setObserver: (o) -> @observer = o
  
  makeNavigateTo: (chain) -> (e) =>
    e.preventDefault()
    #console.log JSON.stringify chain
    if @observer?
      @observer.navigateTo chain
    return
    
  clear: ->
    @clusters = []
    @clustersElem.innerHTML = ""
    @btnClear.style.display = 'none'
    
  updateClusterList: ->
    dom = new DomBuilder

    dom.tag("table")
       .tag("thead")
       .tag('tr')
          .tag('th').text('Cells').end()
          .tag('th').text('Distance').end()
       .end()
       .end()
      
      
    
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
  

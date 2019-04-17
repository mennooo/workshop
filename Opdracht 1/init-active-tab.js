window.mho = window.mho || {}

;(function (namespace) {
  // Static classes
  var rdsClass = '.apex-rds'

  // Keep history of active tabs
  var tabsState = []

  function initActiveTab (da) {
    var region$ = da.affectedElements
    var rds$ = region$.find(rdsClass)
    var tabs = rds$.aTabs('getTabs')
    var activeTab = rds$.aTabs('getActive')

    // Add all tab on page load to history
    for (var tab in tabs) {
      if (tabs[tab].el$.length > 0) {
        tabsState.push({
          region$: tabs[tab].el$,
          wasActive: false
        })
      }
    }

    // Trigger custom event on first activation
    rds$.on('atabsactivate', function (event, data) {
      if (tabs[tab].el$.length > 0) {
        onFirstActivation(data.active.el$)
      }
    })

    function onFirstActivation (region$) {
      tabsState.forEach(function (tabState) {
        if (tabState.region$.get(0) === region$.get(0) && !tabState.wasActive) {
          tabState.wasActive = true
          setTimeout(function () {
            tabState.region$.trigger('mho:tab:active')
          }, 0)
        }
      })
    }

    // Fire custom event on page load
    if (activeTab.el$.length > 0) {
      onFirstActivation(activeTab.el$)
    }
  }

  // Make the function public
  namespace.initActiveTab = initActiveTab
})(window.mho)

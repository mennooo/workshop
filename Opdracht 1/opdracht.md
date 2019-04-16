

```js
function refreshActiveTabRegion (tabs) {
  $(':apex-atabs').on('atabsactivate', function (event, data) {
    tabs.forEach(function(tab) {
      if (data.active.el$.get(0) === apex.region(tab.id).element.get(0) && !tab.wasActive) {
        tab.wasActive = true
        apex.item(tab.item).setValue('1')
        apex.region(tab.id).refresh()
      }
    })
  })
}

refreshActiveTabRegion(
  [
    { id: 'emp',
      item: 'P3_EMP_IND'
    },
    { id: 'dept',
      item: 'P3_DEPT_IND'
    }
  ]
)

```
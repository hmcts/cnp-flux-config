# yq

Anthor async control flow by generator without promise.

## No Promise

```js
const yq = require('yq')
const fs = require('fs')

let readFile = function *() {
  var caller = yield
  fs.readFile('example', { encoding: 'utf-8' }, function (err, content) {
    if (err) {
      caller.error(err)
    } else {
      caller.success(content)
    }
  })
}
```

## Yield

```js
const yq = require('yq')
const readFile = yq.yield(require('fs').readFile)

yq(function *() {
  var content = yield readFile('example', { encoding: 'utf-8' })
  console.log(content) // ...
})
```

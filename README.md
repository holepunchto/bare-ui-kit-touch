# bare-ui-kit-touch

Synthesized UIKit touches for testing Bare apps on iOS. A touch goes through the same path as a finger on the screen: it is hit tested, offered to gesture recognizers and controls, and delivered to the view's `touchesBegan` and friends.

UIKit has no public way to create a touch, so this uses private API, following [KIF](https://github.com/kif-framework/KIF). Use it in tests only, never in an app that ships.

```
npm i -D bare-ui-kit-touch
```

## Usage

```js
const { Scene, Window, ViewController } = require('bare-ui-kit')
const Touch = require('bare-ui-kit-touch')

const window = new Window({ scene: Scene.connected[0] })

window.rootViewController = new ViewController()
window.makeKeyAndVisible()

const touch = Touch.begin(window, 100, 200)

touch.move(120, 200)
touch.end()
```

## License

Apache-2.0

const { test } = require('bare-tap')
const { afterAnimationFrame } = require('bare-animation-frame')
const { Scene, Switch, View, ViewController, Window } = require('bare-ui-kit')
const Touch = require('.')

function open(t) {
  const window = new Window({ scene: Scene.connected[0] })
  const controller = new ViewController()

  window.rootViewController = controller
  window.makeKeyAndVisible()

  t.teardown(() => {
    window.hidden = true
  })

  return { window, root: controller.view }
}

function record(view) {
  const events = []

  for (const name of ['touchesBegan', 'touchesMoved', 'touchesEnded', 'touchesCancelled']) {
    view.on(name, ({ x, y }) => events.push([name, x, y]))
  }

  return events
}

test('delivers a touch to the view under it', async (t) => {
  const { window, root } = open(t)
  const view = new View({ x: 20, y: 100, width: 100, height: 100 })

  root.addSubview(view)

  await afterAnimationFrame()

  const events = record(view)

  const touch = Touch.begin(window, 70, 150)

  t.ok(touch.move(80, 160) === touch, 'returns the touch')

  touch.end()

  t.ok(touch.ended, 'ended')
  t.deepStrictEqual(events, [
    ['touchesBegan', 50, 50],
    ['touchesMoved', 60, 60],
    ['touchesEnded', 60, 60]
  ])
})

test('delivers a touch to the view on top', async (t) => {
  const { window, root } = open(t)
  const below = new View({ x: 0, y: 100, width: 200, height: 200 })
  const above = new View({ x: 50, y: 150, width: 100, height: 100 })

  root.addSubview(below)
  root.addSubview(above)

  await afterAnimationFrame()

  const under = record(below)
  const over = record(above)

  Touch.begin(window, 100, 200).end()

  t.deepStrictEqual(under, [], 'not the view below')
  t.deepStrictEqual(
    over,
    [
      ['touchesBegan', 50, 50],
      ['touchesEnded', 50, 50]
    ],
    'the view on top'
  )
})

test('cancels a touch', async (t) => {
  const { window, root } = open(t)
  const view = new View({ x: 0, y: 100, width: 100, height: 100 })

  root.addSubview(view)

  await afterAnimationFrame()

  const events = record(view)

  Touch.begin(window, 50, 150).cancel()

  t.deepStrictEqual(events, [
    ['touchesBegan', 50, 50],
    ['touchesCancelled', 50, 50]
  ])
})

test('toggles a switch', async (t) => {
  const { window, root } = open(t)
  const toggle = new Switch({ x: 20, y: 100 })

  root.addSubview(toggle)

  await afterAnimationFrame()

  const changed = new Promise((resolve) => toggle.once('valueChanged', resolve))

  const { width, height } = toggle.frame

  const touch = Touch.begin(window, 20 + width / 2, 100 + height / 2)

  await afterAnimationFrame()

  touch.end()

  await changed

  t.equal(toggle.isOn, true)
})

test('cannot be used once ended', (t) => {
  const { window } = open(t)

  const touch = Touch.begin(window, 10, 100)

  touch.end()

  t.throws(() => touch.move(20, 100), /already ended/, 'move')
  t.throws(() => touch.end(), /already ended/, 'end')
  t.throws(() => touch.cancel(), /already ended/, 'cancel')
})

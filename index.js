const binding = require('./binding')
const registry = require('bare-foundation-registry')

module.exports = class UIKitTouch {
  constructor(window, x, y) {
    this._tag = binding.touchBegin(registry.adopt(binding, window), x, y)
    this._token = binding.claim(this._tag, this)
    this._ended = false
  }

  static begin(window, x, y) {
    return new this(window, x, y)
  }

  get ended() {
    return this._ended
  }

  move(x, y) {
    this._check()

    binding.touchMove(this._tag, x, y)

    return this
  }

  end() {
    this._check()

    this._ended = true

    binding.touchEnd(this._tag, false)
  }

  cancel() {
    this._check()

    this._ended = true

    binding.touchEnd(this._tag, true)
  }

  _check() {
    if (this._ended) throw new Error('Touch has already ended')
  }

  [Symbol.for('bare.inspect')]() {
    return {
      __proto__: { constructor: UIKitTouch },
      ended: this.ended
    }
  }
}

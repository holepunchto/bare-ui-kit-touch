import { Wrapper } from 'bare-foundation-registry'

/**
 * A finger on the screen, delivered to the app as UIKit delivers a real one: hit tested, passed to
 * gesture recognizers and then to the view's `touchesBegan` and friends. Only one touch is down at
 * a time.
 */
declare class UIKitTouch {
  /** Put a finger down at a point in the coordinates of `window`. */
  constructor(window: Wrapper, x: number, y: number)

  /** Put a finger down at a point in the coordinates of `window`. */
  static begin(window: Wrapper, x: number, y: number): UIKitTouch

  readonly ended: boolean

  /** Move the finger to a point in the coordinates of the window. */
  move(x: number, y: number): this

  /** Lift the finger. */
  end(): void

  /** Lose the finger, as when the system takes the touch over. */
  cancel(): void
}

export = UIKitTouch

import Foundation
import IOKit.hid

@MainActor protocol LidReading: AnyObject {
    var diagnostic: String { get }
    func read() -> Double?
}

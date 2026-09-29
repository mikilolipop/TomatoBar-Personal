import AppKit

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    precondition(condition(), name)
    checks += 1
}
func launchEvent(eventClass: AEEventClass = kCoreEventClass, id: AEEventID = kAEOpenApplication,
                 marker: OSType? = nil) -> NSAppleEventDescriptor {
    let event = NSAppleEventDescriptor(eventClass: eventClass, eventID: id,
        targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
    if let marker = marker { event.setParam(NSAppleEventDescriptor(enumCode: marker), forKeyword: keyAEPropData) }
    return event
}
var context = LaunchContext()
check(context.shouldShowInitialWindows, "manual launch shows initial windows")
context.observe(nil)
check(context.shouldShowInitialWindows, "absent event preserves manual behavior")
context.observe(launchEvent())
check(context.shouldShowInitialWindows, "ordinary open application is not a login item")
context.observe(launchEvent(id: kAEReopenApplication, marker: keyAELaunchedAsLogInItem))
check(context.shouldShowInitialWindows, "reopen is not misclassified as initial login")
context.observe(launchEvent(eventClass: 0, marker: keyAELaunchedAsLogInItem))
check(context.shouldShowInitialWindows, "wrong event class cannot hide startup windows")
context.observe(launchEvent(marker: keyAELaunchedAsServiceItem))
check(context.shouldShowInitialWindows, "service launch is not silently called a login launch")
context.observe(launchEvent(marker: keyAELaunchedAsLogInItem))
check(context.launchedAtLogin && !context.shouldShowInitialWindows, "login marker suppresses initial windows")
context.observe(nil)
context.observe(launchEvent())
check(!context.shouldShowInitialWindows, "didFinish nil/default does not erase willFinish login marker")
print("PASS: \(checks) synthetic launch-event checks (not a real login test)")

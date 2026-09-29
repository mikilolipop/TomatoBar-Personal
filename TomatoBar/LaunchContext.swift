import AppKit

/// Capture the initial Apple event while launch callbacks still own it. A later nil
/// event must not erase an earlier login marker. This does not infer launch origin
/// from whether the login item is enabled or whether the application is hidden.
struct LaunchContext {
    private(set) var launchedAtLogin = false

    mutating func observe(_ event: NSAppleEventDescriptor?) {
        guard let event = event,
              event.eventClass == kCoreEventClass,
              event.eventID == kAEOpenApplication,
              event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        else { return }
        launchedAtLogin = true
    }

    var shouldShowInitialWindows: Bool { !launchedAtLogin }
}

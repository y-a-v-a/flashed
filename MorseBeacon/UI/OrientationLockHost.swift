import SwiftUI
import UIKit

/// Wraps a SwiftUI view in a `UIHostingController` subclass that locks the
/// supported interface orientation to whichever orientation was active when
/// the view appeared. Required by FR-10: orientation locks to current at
/// the moment the beacon screen appears, restored on disappear.
///
/// Why a UIKit bridge: SwiftUI does not expose a per-view orientation lock.
/// `UIHostingController.supportedInterfaceOrientations` is the only public
/// hook; we override it via this representable.
struct OrientationLockHost<Content: View>: UIViewControllerRepresentable {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  func makeUIViewController(context: Context) -> LockingHostingController<Content> {
    LockingHostingController(rootView: content)
  }

  func updateUIViewController(
    _ uiViewController: LockingHostingController<Content>, context: Context
  ) {
    uiViewController.rootView = content
  }
}

/// `UIHostingController` that captures the device orientation at first
/// appearance and refuses to rotate away from it until disappearance. On
/// disappear, restores `.all` so the rest of the app's screens are free
/// to rotate normally.
final class LockingHostingController<Content: View>: UIHostingController<Content> {

  private var lockedOrientation: UIInterfaceOrientationMask = .all
  private var hasLocked = false

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !hasLocked else { return }
    hasLocked = true

    let current = view.window?.windowScene?.interfaceOrientation ?? .portrait
    lockedOrientation = mask(for: current)
    view.window?.windowScene?
      .requestGeometryUpdate(.iOS(interfaceOrientations: lockedOrientation))
    setNeedsUpdateOfSupportedInterfaceOrientations()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    lockedOrientation = .all
    hasLocked = false
    setNeedsUpdateOfSupportedInterfaceOrientations()
  }

  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    lockedOrientation
  }

  private func mask(for orientation: UIInterfaceOrientation) -> UIInterfaceOrientationMask {
    switch orientation {
    case .portrait: return .portrait
    case .portraitUpsideDown: return .portraitUpsideDown
    case .landscapeLeft: return .landscapeLeft
    case .landscapeRight: return .landscapeRight
    case .unknown: return .portrait
    @unknown default: return .portrait
    }
  }
}

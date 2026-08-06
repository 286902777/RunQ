import UIKit

@main
final class RunQAppDelegate: UIResponder, UIApplicationDelegate {
    private let dataStore = RunQDataStore()
    private lazy var sessionStore = CynosureSessionStore(dataStore: dataStore)
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [
            UIApplication.LaunchOptionsKey: Any
        ]? = nil
    ) -> Bool {
        BundledFontRegistrar.registerFonts()
        let root = RunQRootViewController(
            dataStore: dataStore,
            sessionStore: sessionStore
        )
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window

        Task { @MainActor in
            await dataStore.prepareIfNeeded()
            sessionStore.restorePersistedSession()
            root.refreshRoot()
        }

        return true
    }
}

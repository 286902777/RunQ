import UIKit

@MainActor
final class RunQRootViewController: UIViewController {
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private var activeController: UIViewController?

    init(
        dataStore: RunQDataStore,
        sessionStore: CynosureSessionStore
    ) {
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .runQUIKitBackground
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override var childForStatusBarStyle: UIViewController? {
        activeController
    }

    func refreshRoot() {
        let controller: UIViewController
        #if DEBUG
        let previewArguments = ProcessInfo.processInfo.arguments
        let shouldShowAffinityPreview = previewArguments.contains("--affinity-preview")
        let shouldShowMainPreview = previewArguments.contains("--search-preview")
            || previewArguments.contains("--square-preview")
            || previewArguments.contains("--search-results-preview")
            || previewArguments.contains("--notifications-preview")
            || previewArguments.contains("--chat-room-preview")
            || previewArguments.contains("--create-chatbox-preview")
            || previewArguments.contains("--direct-chat-preview")
            || previewArguments.contains("--direct-chat-voice-preview")
            || previewArguments.contains("--ai-chat-preview")
            || previewArguments.contains("--ai-chat-keyboard-preview")
            || previewArguments.contains("--report-reason-preview")
            || previewArguments.contains("--insufficient-balance-preview")
            || previewArguments.contains("--login-required-preview")
            || previewArguments.contains("--profile-preview")
        #else
        let shouldShowAffinityPreview = false
        let shouldShowMainPreview = false
        #endif

        if !dataStore.isReady {
            controller = RunQUIKitLoadingViewController()
        } else if shouldShowAffinityPreview {
            controller = RunQNavigationController(
                rootViewController: RunQUIKitAffinityViewController(
                    dataStore: dataStore,
                    sessionStore: sessionStore
                )
            )
        } else if shouldShowMainPreview {
            controller = RunQUIKitMainTabBarController(
                dataStore: dataStore,
                sessionStore: sessionStore
            )
        } else if !RunQEULAConsent.isAccepted {
            controller = RunQNavigationController(
                rootViewController: RunQUIKitWelcomeViewController(
                    dataStore: dataStore,
                    sessionStore: sessionStore
                )
            )
        } else if sessionStore.isAuthenticated {
            controller = RunQUIKitMainTabBarController(
                dataStore: dataStore,
                sessionStore: sessionStore
            )
        } else {
            let welcome = RunQUIKitWelcomeViewController(
                dataStore: dataStore,
                sessionStore: sessionStore
            )
            controller = RunQNavigationController(rootViewController: welcome)
        }
        replace(controller)
    }

    private func replace(_ controller: UIViewController) {
        guard activeController !== controller else { return }
        activeController?.willMove(toParent: nil)
        activeController?.view.removeFromSuperview()
        activeController?.removeFromParent()
        addChild(controller)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        activeController = controller
        setNeedsStatusBarAppearanceUpdate()
    }
}

@MainActor
final class RunQNavigationController: UINavigationController,
    UIGestureRecognizerDelegate, UINavigationControllerDelegate {
    var onRootVisibilityChange: ((Bool, UIViewControllerTransitionCoordinator?) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
        delegate = self
        interactivePopGestureRecognizer?.delegate = self
        interactivePopGestureRecognizer?.isEnabled = true
    }

    override var childForStatusBarStyle: UIViewController? {
        topViewController
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        onRootVisibilityChange?(
            viewController === navigationController.viewControllers.first,
            transitionCoordinator
        )
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        onRootVisibilityChange?(
            viewController === navigationController.viewControllers.first,
            nil
        )
    }
}

private final class RunQUIKitLoadingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .runQUIKitBackground
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

extension UIColor {
    static let runQUIKitBackground = UIColor(
        red: 16 / 255,
        green: 16 / 255,
        blue: 15 / 255,
        alpha: 1
    )
}

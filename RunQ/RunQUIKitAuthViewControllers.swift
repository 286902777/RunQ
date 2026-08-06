import Darwin
import UIKit
import SnapKit
import WebKit

@MainActor
private enum RunQUIKitPalette {
    static let orange = UIColor(red: 1, green: 91 / 255, blue: 25 / 255, alpha: 1)
    static let panel = UIColor(red: 47 / 255, green: 47 / 255, blue: 52 / 255, alpha: 1)
    static let field = UIColor(white: 1, alpha: 0.21)
}

final class RunQUIKitInsetLabel: UILabel {
    var textInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + textInsets.left + textInsets.right,
            height: size.height + textInsets.top + textInsets.bottom
        )
    }
}

private final class RunQUIKitAuthGlowView: UIView {
    private let glows: [(UIColor, CGFloat)] = [
        (UIColor(red: 1, green: 0.93, blue: 0.25, alpha: 0.48), 0.02),
        (UIColor(red: 0.4, green: 1, blue: 0.38, alpha: 0.42), 0.22),
        (UIColor(red: 1, green: 0.9, blue: 0.18, alpha: 0.46), 0.43),
        (UIColor(red: 1, green: 0.48, blue: 0.18, alpha: 0.4), 0.62),
        (UIColor(red: 0.45, green: 1, blue: 0.34, alpha: 0.36), 0.81)
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true
        glows.forEach { color, _ in
            let gradient = CAGradientLayer()
            gradient.type = .radial
            gradient.colors = [color.cgColor, color.withAlphaComponent(0).cgColor]
            gradient.locations = [0, 1]
            gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 1)
            layer.addSublayer(gradient)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let diameter = bounds.height * 1.9
        for (index, item) in glows.enumerated() {
            let centerX = bounds.width * item.1
            layer.sublayers?[index].frame = CGRect(
                x: centerX - diameter / 2,
                y: bounds.midY - diameter / 2,
                width: diameter,
                height: diameter
            )
        }
    }
}

@MainActor
func runQUIKitLabel(
    _ text: String,
    size: CGFloat,
    weight: UIFont.Weight = .regular
) -> UILabel {
    let label = UILabel()
    label.text = text
    label.textColor = .white
    label.font = UIFont(name: weight == .bold ? "PassionOne-Bold" : "Barlow-Regular", size: size)
        ?? .systemFont(ofSize: size, weight: weight)
    label.numberOfLines = 0
    return label
}

@MainActor
func runQUIKitTextField(
    placeholder: String,
    secure: Bool = false
) -> UITextField {
    let field = UITextField()
    field.placeholder = placeholder
    field.attributedPlaceholder = NSAttributedString(
        string: placeholder,
        attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
    )
    field.textColor = .white
    field.tintColor = .white
    field.font = UIFont(name: "Barlow-Regular", size: 14) ?? .systemFont(ofSize: 14)
    field.backgroundColor = RunQUIKitPalette.field
    field.layer.cornerRadius = 16
    field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
    field.leftViewMode = .always
    field.isSecureTextEntry = secure
    field.returnKeyType = .next
    field.autocorrectionType = .no
    let toolbar = UIToolbar()
    toolbar.sizeToFit()
    toolbar.items = [
        UIBarButtonItem(systemItem: .flexibleSpace),
        UIBarButtonItem(
            title: "Done",
            style: .done,
            target: field,
            action: #selector(UIResponder.resignFirstResponder)
        )
    ]
    field.inputAccessoryView = toolbar
    return field
}

@MainActor
private func runQUIKitAuthActionButton(
    _ title: String,
    action: @escaping () -> Void
) -> UIButton {
    let button = UIButton(type: .custom)
    button.setBackgroundImage(
        UIImage(named: "runq_ember_affinity_cta"),
        for: .normal
    )
    button.setTitle(title, for: .normal)
    button.setTitleColor(.white, for: .normal)
    button.titleLabel?.font = UIFont(name: "Barlow-Regular", size: 15)
        ?? .systemFont(ofSize: 15)
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
}

@MainActor
func runQUIKitButton(_ title: String, action: @escaping () -> Void) -> UIButton {
    let button = UIButton(type: .custom)
    button.setTitle(title, for: .normal)
    button.setTitleColor(.white, for: .normal)
    button.titleLabel?.font = UIFont(name: "Barlow-Regular", size: 15) ?? .systemFont(ofSize: 15)
    button.backgroundColor = RunQUIKitPalette.orange
    button.layer.cornerRadius = 26
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
}

@MainActor
@discardableResult
func runQUIKitRequireAccount(
    from controller: UIViewController,
    dataStore: RunQDataStore,
    sessionStore: CynosureSessionStore
) -> Bool {
    if let user = sessionStore.currentUser, !user.isGuest { return true }
    guard controller.presentedViewController == nil else { return false }
    controller.view.endEditing(true)
    let dialog = RunQUIKitLoginRequiredViewController()
    dialog.modalPresentationStyle = .overFullScreen
    dialog.onSignIn = { [weak controller] in
        guard let controller else { return }
        let login = RunQUIKitLoginViewController(
            dataStore: dataStore,
            sessionStore: sessionStore
        )
        login.hidesBottomBarWhenPushed = true
        controller.navigationController?.pushViewController(login, animated: true)
    }
    controller.present(dialog, animated: true)
    return false
}

@MainActor
private func runQUIKitRoot(
    from controller: UIViewController
) -> RunQRootViewController? {
    if let root = controller.view.window?.rootViewController
        as? RunQRootViewController {
        return root
    }
    var current: UIViewController? = controller
    while let candidate = current {
        if let root = candidate as? RunQRootViewController {
            return root
        }
        current = candidate.parent ?? candidate.presentingViewController
    }
    return nil
}

@MainActor
class RunQUIKitAuthViewController: UIViewController, UITextFieldDelegate {
    let dataStore: RunQDataStore
    let sessionStore: CynosureSessionStore
    let scrollView = UIScrollView()
    let panel = UIView()
    private var loadingView: UIView?
    private weak var actionButton: UIButton?
    private var actionButtonBottomConstraint: Constraint?
    private var returnChain: [UITextField] = []

    init(dataStore: RunQDataStore, sessionStore: CynosureSessionStore) {
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = RunQUIKitPalette.orange
        navigationController?.setNavigationBarHidden(true, animated: false)
        configureKeyboard()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    @discardableResult
    func configurePanel(
        top: CGFloat = 284,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> UIButton {
        panel.backgroundColor = RunQUIKitPalette.panel
        panel.layer.cornerRadius = 30
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.clipsToBounds = true
        view.addSubview(panel)

        let panelArtwork = UIImageView(
            image: UIImage(named: "runq_nocturne_login_plinth")
        )
        panelArtwork.contentMode = .scaleToFill
        panel.addSubview(panelArtwork)

        let panelOrnament = UIImageView(
            image: UIImage(named: "runq_obsidian_threshold")
        )
        panelOrnament.contentMode = .scaleToFill
        panel.addSubview(panelOrnament)

        let actionButton = runQUIKitAuthActionButton(actionTitle, action: action)
        self.actionButton = actionButton
        panel.addSubview(actionButton)

        scrollView.alwaysBounceVertical = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.contentInsetAdjustmentBehavior = .never
        panel.addSubview(scrollView)

        panel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(top)
            make.leading.trailing.bottom.equalToSuperview()
        }
        panelArtwork.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        panelOrnament.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(panelOrnament.snp.width).multipliedBy(352.0 / 375.0)
        }
        actionButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(195)
            make.height.equalTo(52)
            actionButtonBottomConstraint = make.bottom
                .equalTo(view.safeAreaLayoutGuide)
                .offset(-17)
                .constraint
        }
        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top)
        }
        panel.bringSubviewToFront(scrollView)
        panel.bringSubviewToFront(actionButton)
        return actionButton
    }

    func addHero(assetName: String = "runq_wayfarer_portal") {
        let hero = UIImageView(image: UIImage(named: assetName))
        hero.contentMode = .scaleToFill
        hero.clipsToBounds = false
        view.insertSubview(hero, at: 0)
        hero.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            if assetName == "runq_forgot_password_hero" {
                make.height.equalTo(hero.snp.width).multipliedBy(306.0 / 375.0)
            } else {
                make.height.equalTo(hero.snp.width).multipliedBy(853.0 / 375.0)
            }
        }

        if assetName == "runq_wayfarer_portal" {
            let glow = RunQUIKitAuthGlowView()
            view.addSubview(glow)
            glow.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(248)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(58)
            }
        }
    }

    func addBackButton() {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "runq_navigation_back"), for: .normal)
        button.accessibilityLabel = "Back"
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if let navigationController,
               navigationController.viewControllers.count > 1 {
                navigationController.popViewController(animated: true)
            } else {
                dismiss(animated: true)
            }
        }, for: .touchUpInside)
        view.addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(3)
            make.size.equalTo(44)
        }
    }

    func makeFormContent(minimumHeight: CGFloat) -> UIView {
        let content = UIView()
        scrollView.addSubview(content)
        content.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.height.greaterThanOrEqualTo(minimumHeight)
        }
        return content
    }

    func addField(
        _ field: UITextField,
        labelText: String,
        labelTop: CGFloat,
        fieldTop: CGFloat,
        to content: UIView
    ) {
        let label = runQUIKitLabel(labelText, size: 13)
        content.addSubview(label)
        content.addSubview(field)
        label.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(labelTop)
            make.leading.equalToSuperview().offset(20)
        }
        field.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(fieldTop)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(48)
        }
    }

    func configureReturnChain(_ fields: [UITextField]) {
        returnChain = fields
        for (index, field) in fields.enumerated() {
            field.delegate = self
            field.returnKeyType = index == fields.count - 1 ? .done : .next
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let index = returnChain.firstIndex(where: { $0 === textField })
        else {
            textField.resignFirstResponder()
            return true
        }
        if index + 1 < returnChain.count {
            returnChain[index + 1].becomeFirstResponder()
        }
        textField.resignFirstResponder()
        return true
    }

    func finishSession() {
        runQUIKitRoot(from: self)?.refreshRoot()
    }

    func showToast(_ message: String) {
        let alert = RunQUIKitInsetLabel()
        alert.text = message
        alert.textColor = .white
        alert.textAlignment = .center
        alert.numberOfLines = 0
        alert.backgroundColor = UIColor(white: 0.1, alpha: 0.94)
        alert.layer.cornerRadius = 16
        alert.layer.masksToBounds = true
        view.addSubview(alert)
        alert.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-24)
            make.leading.greaterThanOrEqualToSuperview().offset(28)
            make.trailing.lessThanOrEqualToSuperview().offset(-28)
        }
        UIView.animate(withDuration: 0.2, delay: 1.8, options: .curveEaseIn) { alert.alpha = 0 } completion: { _ in alert.removeFromSuperview() }
    }

    func performLoading(_ operation: @escaping () -> Void) {
        guard loadingView == nil else { return }
        view.endEditing(true)
        actionButton?.isEnabled = false
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.48)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        overlay.addSubview(indicator)
        view.addSubview(overlay)
        overlay.snp.makeConstraints { make in make.edges.equalToSuperview() }
        indicator.snp.makeConstraints { make in make.center.equalToSuperview() }
        loadingView = overlay
        DispatchQueue.main.async { [weak self] in
            operation()
            self?.loadingView?.removeFromSuperview()
            self?.loadingView = nil
            self?.actionButton?.isEnabled = true
        }
    }

    private func configureKeyboard() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    @objc private func keyboardChanged(_ notification: Notification) {
        guard let info = notification.userInfo, let frame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let converted = view.convert(frame, from: nil)
        let overlap = max(0, view.bounds.maxY - converted.minY)
        let lift = max(0, overlap - view.safeAreaInsets.bottom)
        let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        let focusedField = returnChain.first(where: { $0.isFirstResponder })
        actionButtonBottomConstraint?.update(offset: -17 - lift)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curve << 16)
        ) {
            self.view.layoutIfNeeded()
            if lift > 0, let focusedField {
                let visibleRect = focusedField.convert(
                    focusedField.bounds.insetBy(dx: 0, dy: -12),
                    to: self.scrollView
                )
                self.scrollView.scrollRectToVisible(visibleRect, animated: false)
            } else {
                self.scrollView.setContentOffset(.zero, animated: false)
            }
        }
    }
}

@MainActor
final class RunQUIKitWelcomeViewController: UIViewController, UITextViewDelegate {
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let agreementButton = UIButton(type: .custom)
    private var isAgreementAccepted = false
    private var loadingView: UIView?

    init(dataStore: RunQDataStore, sessionStore: CynosureSessionStore) {
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentRequiredEULAIfNeeded()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = RunQUIKitPalette.orange
        let background = UIImageView(image: UIImage(named: "runq_wayfarer_portal"))
        background.contentMode = .scaleAspectFit
        background.clipsToBounds = false
        background.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(background)
        let panel = UIView()
        panel.backgroundColor = RunQUIKitPalette.panel
        panel.layer.cornerRadius = 30
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.clipsToBounds = true
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        let panelArtwork = UIImageView(
            image: UIImage(named: "runq_obsidian_threshold")
        )
        panelArtwork.contentMode = .scaleToFill
        panelArtwork.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(panelArtwork)
        let title = runQUIKitLabel("WELCOME TO  RUNQ", size: 23, weight: .bold)
        title.textAlignment = .center
        let login = runQUIKitButton("Login Now") { [weak self] in self?.openLogin() }
        let register = runQUIKitButton("I'm New") { [weak self] in self?.openRegistration() }
        login.layer.cornerRadius = 16
        register.layer.cornerRadius = 16
        [title, login, register].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview($0)
        }

        let separatorLabel = runQUIKitLabel("OR", size: 12)
        separatorLabel.textAlignment = .center
        separatorLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        separatorLabel.translatesAutoresizingMaskIntoConstraints = false
        let leftSeparator = UIView()
        let rightSeparator = UIView()
        [leftSeparator, rightSeparator].forEach {
            $0.backgroundColor = UIColor.white.withAlphaComponent(0.18)
            $0.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview($0)
        }
        panel.addSubview(separatorLabel)

        let agreementTextView = makeAgreementTextView()
        agreementButton.translatesAutoresizingMaskIntoConstraints = false
        agreementButton.accessibilityLabel = "Accept User Agreement and Privacy Policy"
        agreementButton.accessibilityHint = "Accepted through the EULA"
        agreementButton.isUserInteractionEnabled = false
        panel.addSubview(agreementButton)
        panel.addSubview(agreementTextView)

        isAgreementAccepted = RunQEULAConsent.isAccepted
        updateAgreementButton()

        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: view.topAnchor),
            background.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            background.heightAnchor.constraint(
                equalTo: background.widthAnchor,
                multiplier: 2559.0 / 1125.0
            ),
            panel.topAnchor.constraint(equalTo: view.topAnchor, constant: 462),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panelArtwork.topAnchor.constraint(equalTo: panel.topAnchor),
            panelArtwork.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            panelArtwork.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            panelArtwork.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            title.topAnchor.constraint(equalTo: panel.topAnchor, constant: 33),
            title.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            login.topAnchor.constraint(equalTo: panel.topAnchor, constant: 99),
            login.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            login.widthAnchor.constraint(equalToConstant: 195),
            login.heightAnchor.constraint(equalToConstant: 52),
            separatorLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 164),
            separatorLabel.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            separatorLabel.widthAnchor.constraint(equalToConstant: 22),
            leftSeparator.leadingAnchor.constraint(equalTo: login.leadingAnchor, constant: 26),
            leftSeparator.trailingAnchor.constraint(equalTo: separatorLabel.leadingAnchor, constant: -4),
            leftSeparator.centerYAnchor.constraint(equalTo: separatorLabel.centerYAnchor),
            leftSeparator.heightAnchor.constraint(equalToConstant: 1),
            rightSeparator.leadingAnchor.constraint(equalTo: separatorLabel.trailingAnchor, constant: 4),
            rightSeparator.trailingAnchor.constraint(equalTo: login.trailingAnchor, constant: -26),
            rightSeparator.centerYAnchor.constraint(equalTo: separatorLabel.centerYAnchor),
            rightSeparator.heightAnchor.constraint(equalToConstant: 1),
            register.topAnchor.constraint(equalTo: panel.topAnchor, constant: 191),
            register.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            register.widthAnchor.constraint(equalToConstant: 195),
            register.heightAnchor.constraint(equalToConstant: 52),
            agreementButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 60),
            agreementButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -9
            ),
            agreementButton.widthAnchor.constraint(equalToConstant: 20),
            agreementButton.heightAnchor.constraint(equalToConstant: 20),
            agreementTextView.leadingAnchor.constraint(
                equalTo: agreementButton.trailingAnchor,
                constant: 16
            ),
            agreementTextView.trailingAnchor.constraint(
                equalTo: panel.trailingAnchor,
                constant: -28
            ),
            agreementTextView.centerYAnchor.constraint(
                equalTo: agreementButton.centerYAnchor
            ),
            agreementTextView.heightAnchor.constraint(equalToConstant: 42)
        ])
    }

    private func makeAgreementTextView() -> UITextView {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.delegate = self
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true

        let font = UIFont(name: "Barlow-Regular", size: 13)
            ?? UIFont.systemFont(ofSize: 13)
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.55)
        ]
        let content = NSMutableAttributedString(
            string: "By signing up, you agree to the ",
            attributes: normalAttributes
        )
        content.append(
            NSAttributedString(
                string: "User Agreement",
                attributes: normalAttributes.merging([
                    .link: URL(string: "runq://user-agreement")!,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]) { _, new in new }
            )
        )
        content.append(NSAttributedString(string: " & ", attributes: normalAttributes))
        content.append(
            NSAttributedString(
                string: "Privacy Policy",
                attributes: normalAttributes.merging([
                    .link: URL(string: "runq://privacy-policy")!,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]) { _, new in new }
            )
        )
        textView.attributedText = content
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.72),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        return textView
    }

    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        let document: RunQLegalDocumentViewController.Document
        switch URL.host {
        case "user-agreement":
            document = .userAgreement
        case "privacy-policy":
            document = .privacyPolicy
        default:
            return false
        }
        navigationController?.pushViewController(
            RunQLegalDocumentViewController(document: document),
            animated: true
        )
        return false
    }

    private func updateAgreementButton() {
        agreementButton.setImage(
            isAgreementAccepted
                ? UIImage(named: "runq_celadon_assent_selected")
                : nil,
            for: .normal
        )
        agreementButton.backgroundColor = isAgreementAccepted
            ? .clear
            : UIColor.white.withAlphaComponent(0.22)
        agreementButton.layer.cornerRadius = 10
        agreementButton.accessibilityValue = isAgreementAccepted
            ? "Selected"
            : "Not selected"
    }

    private func openLogin() {
        guard RunQEULAConsent.isAccepted else {
            showAgreementToast()
            return
        }
        navigationController?.pushViewController(
            RunQUIKitLoginViewController(
                dataStore: dataStore,
                sessionStore: sessionStore
            ),
            animated: true
        )
    }

    private func openRegistration() {
        guard RunQEULAConsent.isAccepted else {
            showAgreementToast()
            return
        }
        guard loadingView == nil else { return }
        showWelcomeLoading()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            do {
                try sessionStore.continueAsGuest()
                finishSession()
            } catch {
                hideWelcomeLoading()
                showWelcomeToast("Unable to continue as guest.")
            }
        }
    }

    private func showWelcomeLoading() {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.48)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        overlay.addSubview(indicator)
        view.addSubview(overlay)
        overlay.snp.makeConstraints { make in make.edges.equalToSuperview() }
        indicator.snp.makeConstraints { make in make.center.equalToSuperview() }
        loadingView = overlay
    }

    private func hideWelcomeLoading() {
        loadingView?.removeFromSuperview()
        loadingView = nil
    }

    private func showAgreementToast() {
        showWelcomeToast(
            "Please accept the User Agreement and Privacy Policy."
        )
    }

    private func presentRequiredEULAIfNeeded() {
        guard !RunQEULAConsent.isAccepted,
              presentedViewController == nil else { return }
        let agreement = RunQObumbratedEulaViewController()
        agreement.dismissesOnCancel = false
        agreement.onCancel = {
            Darwin.exit(EXIT_SUCCESS)
        }
        agreement.onAgree = { [weak self] in
            guard let self else { return }
            RunQEULAConsent.accept()
            isAgreementAccepted = true
            updateAgreementButton()
            runQUIKitRoot(from: self)?.refreshRoot()
        }
        present(agreement, animated: true)
    }

    private func showWelcomeToast(_ message: String) {
        let toast = RunQUIKitInsetLabel()
        toast.text = message
        toast.textColor = .white
        toast.textAlignment = .center
        toast.numberOfLines = 0
        toast.backgroundColor = UIColor(white: 0.1, alpha: 0.94)
        toast.layer.cornerRadius = 16
        toast.layer.masksToBounds = true
        view.addSubview(toast)
        toast.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-70)
            make.leading.greaterThanOrEqualToSuperview().offset(28)
            make.trailing.lessThanOrEqualToSuperview().offset(-28)
        }
        UIView.animate(
            withDuration: 0.2,
            delay: 1.8,
            options: .curveEaseIn
        ) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }

    private func finishSession() {
        runQUIKitRoot(from: self)?.refreshRoot()
    }
}

@MainActor
final class RunQLegalDocumentViewController: UIViewController, WKNavigationDelegate {
    enum Document {
        case userAgreement
        case privacyPolicy

        var title: String {
            switch self {
            case .userAgreement: "USER AGREEMENT"
            case .privacyPolicy: "PRIVACY POLICY"
            }
        }

        var url: URL {
            switch self {
            case .userAgreement:
                URL(string: "https://sites.google.com/view/runqapp/users")!
            case .privacyPolicy:
                URL(string: "https://sites.google.com/view/runqapp/privacy")!
            }
        }
    }

    private let document: Document
    private let navigationHeader = UIView()
    private let webView = WKWebView(frame: .zero)
    private let loadingView = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    init(document: Document) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 16 / 255, green: 16 / 255, blue: 15 / 255, alpha: 1)
        configureNavigation()
        configureWebView()
        configureLoadingView()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }

    private func configureNavigation() {
        navigationHeader.translatesAutoresizingMaskIntoConstraints = false
        navigationHeader.backgroundColor = view.backgroundColor
        let backButton = UIButton(type: .custom)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setImage(UIImage(named: "runq_navigation_back"), for: .normal)
        backButton.accessibilityLabel = "Back"
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        let titleLabel = runQUIKitLabel(document.title, size: 22, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        view.addSubview(navigationHeader)
        navigationHeader.addSubview(backButton)
        navigationHeader.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            navigationHeader.topAnchor.constraint(equalTo: view.topAnchor),
            navigationHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationHeader.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 54
            ),
            backButton.leadingAnchor.constraint(equalTo: navigationHeader.leadingAnchor, constant: 12),
            backButton.bottomAnchor.constraint(equalTo: navigationHeader.bottomAnchor, constant: -5),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            titleLabel.centerXAnchor.constraint(equalTo: navigationHeader.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor)
        ])
    }

    private func configureWebView() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: navigationHeader.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        showLoading()
        webView.load(URLRequest(url: document.url))
    }

    private func configureLoadingView() {
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.backgroundColor = UIColor(red: 16 / 255, green: 16 / 255, blue: 15 / 255, alpha: 1)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = .white
        loadingView.addSubview(loadingIndicator)
        view.addSubview(loadingView)
        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: navigationHeader.bottomAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor)
        ])
    }

    private func showLoading() {
        loadingView.isHidden = false
        loadingIndicator.startAnimating()
    }

    private func hideLoading() {
        loadingIndicator.stopAnimating()
        loadingView.isHidden = true
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        showLoading()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoading()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        hideLoading()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        hideLoading()
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }
}

@MainActor
final class RunQUIKitLoginViewController: RunQUIKitAuthViewController {
    private let email = runQUIKitTextField(placeholder: "Please enter")
    private let password = runQUIKitTextField(placeholder: "Please enter", secure: true)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "LOGIN"
        addHero()
        configurePanel(actionTitle: "Login") { [weak self] in self?.submit() }
        addBackButton()
        configureReturnChain([email, password])
        email.keyboardType = .emailAddress

        let content = makeFormContent(minimumHeight: 407)
        let heading = runQUIKitLabel("LOGIN", size: 22, weight: .bold)
        content.addSubview(heading)
        heading.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(40)
            make.leading.equalToSuperview().offset(20)
        }
        addField(email, labelText: "EMAIL", labelTop: 98, fieldTop: 124, to: content)
        addField(
            password,
            labelText: "PASSWORD",
            labelTop: 195,
            fieldTop: 221,
            to: content
        )

        let forgot = UIButton(type: .system)
        let forgotTitle = NSAttributedString(
            string: "FORGOT PASSWORD?",
            attributes: [
                .font: UIFont(name: "Barlow-Regular", size: 13)
                    ?? UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.white,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        forgot.setAttributedTitle(forgotTitle, for: .normal)
        forgot.contentHorizontalAlignment = .right
        forgot.addAction(
            UIAction { [weak self] _ in self?.openForgot() },
            for: .touchUpInside
        )
        content.addSubview(forgot)
        forgot.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(278)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(34)
        }

        let registration = UIButton(type: .system)
        let registrationTitle = NSMutableAttributedString(
            string: "Don't have an account? ",
            attributes: [
                .font: UIFont(name: "Barlow-Regular", size: 13)
                    ?? UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.white
            ]
        )
        registrationTitle.append(
            NSAttributedString(
                string: "Sign up",
                attributes: [
                    .font: UIFont(name: "Barlow-Regular", size: 13)
                        ?? UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.white,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            )
        )
        registration.setAttributedTitle(registrationTitle, for: .normal)
        registration.addAction(
            UIAction { [weak self] _ in self?.openRegistration() },
            for: .touchUpInside
        )
        content.addSubview(registration)
        registration.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(356)
            make.centerX.equalToSuperview()
            make.height.equalTo(34)
        }
    }

    private func submit() {
        guard !(email.text ?? "").isEmpty, !(password.text ?? "").isEmpty else { showToast("Please complete all fields."); return }
        performLoading { [weak self] in
            guard let self else { return }
            do {
                try sessionStore.signIn(
                    email: email.text!,
                    password: password.text!
                )
                finishSession()
            } catch {
                showToast("Email or password is incorrect.")
            }
        }
    }

    private func openForgot() {
        navigationController?.pushViewController(
            RunQUIKitForgotPasswordViewController(
                dataStore: dataStore,
                sessionStore: sessionStore
            ),
            animated: true
        )
    }

    private func openRegistration() {
        navigationController?.pushViewController(
            RunQUIKitRegistrationViewController(
                dataStore: dataStore,
                sessionStore: sessionStore
            ),
            animated: true
        )
    }
}

@MainActor
final class RunQUIKitRegistrationViewController: RunQUIKitAuthViewController {
    private let email = runQUIKitTextField(placeholder: "Please enter")
    private let password = runQUIKitTextField(placeholder: "Please enter", secure: true)
    private let confirmation = runQUIKitTextField(placeholder: "Please enter the password again", secure: true)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "SIGN UP"
        addHero()
        configurePanel(actionTitle: "Sign up") { [weak self] in self?.submit() }
        addBackButton()
        configureReturnChain([email, password, confirmation])
        email.keyboardType = .emailAddress
        configureThreeFieldForm(title: "SIGN UP")
    }

    private func configureThreeFieldForm(title: String) {
        let content = makeFormContent(minimumHeight: 407)
        let heading = runQUIKitLabel(title, size: 22, weight: .bold)
        content.addSubview(heading)
        heading.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(40)
            make.leading.equalToSuperview().offset(20)
        }
        addField(email, labelText: "EMAIL", labelTop: 98, fieldTop: 124, to: content)
        addField(password, labelText: "PASSWORD", labelTop: 195, fieldTop: 221, to: content)
        addField(confirmation, labelText: "PASSWORD", labelTop: 292, fieldTop: 318, to: content)
    }
    private func submit() { guard let e = email.text, let p = password.text, !e.isEmpty, !p.isEmpty, p == confirmation.text else { showToast("Please check your registration details."); return }; performLoading { [weak self] in guard let self else { return }; do { try sessionStore.register(email: e, password: p); navigationController?.pushViewController(RunQUIKitAffinityViewController(dataStore: dataStore, sessionStore: sessionStore), animated: true) } catch { showToast("Unable to create account.") } } }
}

@MainActor
final class RunQUIKitForgotPasswordViewController: RunQUIKitAuthViewController {
    private let email = runQUIKitTextField(placeholder: "Please enter")
    private let password = runQUIKitTextField(placeholder: "Please enter", secure: true)
    private let confirmation = runQUIKitTextField(placeholder: "Please enter the password again", secure: true)
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "FORGOT PASSWORD"
        addHero()
        configurePanel(actionTitle: "Sign up") { [weak self] in self?.submit() }
        addBackButton()
        configureReturnChain([email, password, confirmation])
        email.keyboardType = .emailAddress

        let content = makeFormContent(minimumHeight: 407)
        let heading = runQUIKitLabel("FORGOT PASSWORD", size: 22, weight: .bold)
        content.addSubview(heading)
        heading.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(40)
            make.leading.equalToSuperview().offset(20)
        }
        addField(email, labelText: "EMAIL", labelTop: 98, fieldTop: 124, to: content)
        addField(password, labelText: "PASSWORD", labelTop: 195, fieldTop: 221, to: content)
        addField(confirmation, labelText: "PASSWORD", labelTop: 292, fieldTop: 318, to: content)
    }
    private func submit() {
        guard let emailText = email.text,
              let passwordText = password.text,
              !emailText.isEmpty,
              !passwordText.isEmpty,
              passwordText == confirmation.text else {
            showToast("Please check your password details.")
            return
        }
        performLoading { [weak self] in
            guard let self else { return }
            do {
                try sessionStore.resetPassword(
                    email: emailText,
                    newPassword: passwordText
                )
                RunQToastPresenter.show(
                    "Password updated.",
                    on: navigationController?.view ?? view
                )
                navigationController?.popViewController(animated: true)
            } catch {
                showToast("Unable to reset password.")
            }
        }
    }
}

@MainActor
final class RunQUIKitAffinityViewController: UIViewController {
    private struct Interest: Hashable {
        let title: String
        let imageName: String
    }

    private static let interests = [
        Interest(title: "GYM", imageName: "runq_interest_gym"),
        Interest(title: "CLIMBING", imageName: "runq_interest_climbing"),
        Interest(title: "DIVING", imageName: "runq_interest_diving"),
        Interest(title: "SKYDIVING", imageName: "runq_interest_skydiving"),
        Interest(title: "SURFING", imageName: "runq_interest_surfing"),
        Interest(title: "OTHER", imageName: "runq_interest_other")
    ]

    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private var selected = Set(["CLIMBING"])
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 21
        layout.minimumLineSpacing = 18
        layout.scrollDirection = .vertical
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.alwaysBounceVertical = false
        view.showsVerticalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .never
        return view
    }()
    private lazy var doneButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(
            UIImage(named: "runq_ember_affinity_cta"),
            for: .normal
        )
        button.setImage(
            UIImage(named: "runq_vector_continue_glyph"),
            for: .normal
        )
        button.accessibilityLabel = "Continue"
        button.addAction(UIAction { [weak self] _ in
            self?.complete()
        }, for: .touchUpInside)
        return button
    }()
    private var loadingView: UIView?

    init(dataStore: RunQDataStore, sessionStore: CynosureSessionStore) {
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .runQUIKitBackground
        configureInterface()
    }

    private func configureInterface() {
        let backdrop = UIImageView(
            image: UIImage(named: "runq_aurora_affinity_backdrop")
        )
        backdrop.contentMode = .scaleToFill

        let backButton = UIButton(type: .custom)
        backButton.setImage(
            UIImage(named: "runq_vector_continue_glyph")?.withHorizontallyFlippedOrientation(),
            for: .normal
        )
        backButton.accessibilityLabel = "Back"
        backButton.addAction(UIAction { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }, for: .touchUpInside)

        let titleLabel = UILabel()
        titleLabel.text = "What do you want to do with your\nbuddy?"
        titleLabel.textColor = .white
        titleLabel.font = AppFont.passionOne(size: 22)
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontForContentSizeCategory = true

        let subtitleLabel = UILabel()
        subtitleLabel.text = "(multiple choice)"
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        subtitleLabel.font = AppFont.barlow(size: 13)

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            RunQInterestCell.self,
            forCellWithReuseIdentifier: RunQInterestCell.reuseIdentifier
        )

        view.addSubview(backdrop)
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(collectionView)
        view.addSubview(doneButton)

        backdrop.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(backdrop.snp.width).multipliedBy(324.0 / 375.0)
        }
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.size.equalTo(24)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(backButton.snp.bottom).offset(35)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(15)
            make.leading.equalTo(titleLabel)
        }
        doneButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-18)
            make.width.equalTo(195)
            make.height.equalTo(52)
        }
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(35)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(doneButton.snp.top).offset(-24)
        }
    }

    private func complete() {
        guard loadingView == nil else { return }
        guard !selected.isEmpty else {
            showToast("Please select at least one interest.")
            return
        }
        doneButton.isEnabled = false
        showLoading()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            do {
                try sessionStore.completePendingRegistration(
                    affinities: Array(selected)
                )
                runQUIKitRoot(from: self)?.refreshRoot()
            } catch {
                hideLoading()
                doneButton.isEnabled = true
                showToast("Unable to complete registration.")
            }
        }
    }

    private func showLoading() {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.48)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        overlay.addSubview(indicator)
        view.addSubview(overlay)
        overlay.snp.makeConstraints { make in make.edges.equalToSuperview() }
        indicator.snp.makeConstraints { make in make.center.equalToSuperview() }
        loadingView = overlay
    }

    private func hideLoading() {
        loadingView?.removeFromSuperview()
        loadingView = nil
    }

    private func showToast(_ message: String) {
        let toast = RunQUIKitInsetLabel()
        toast.text = message
        toast.textColor = .white
        toast.textAlignment = .center
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.92)
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        toast.textInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        view.addSubview(toast)
        toast.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(doneButton.snp.top).offset(-16)
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
        }
        UIView.animate(withDuration: 0.2, delay: 1.6) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }
}

extension RunQUIKitAffinityViewController:
    UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        Self.interests.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RunQInterestCell.reuseIdentifier,
            for: indexPath
        ) as? RunQInterestCell else {
            return UICollectionViewCell()
        }
        let interest = Self.interests[indexPath.item]
        cell.configure(
            title: interest.title,
            imageName: interest.imageName,
            isSelected: selected.contains(interest.title)
        )
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let interest = Self.interests[indexPath.item]
        selected.toggle(interest.title)
        collectionView.reloadItems(at: [indexPath])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = floor((collectionView.bounds.width - 21) / 2)
        return CGSize(width: width, height: 138)
    }
}

private final class RunQInterestCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQInterestCell"

    private let imageView = UIImageView()
    private let titleBackground = UIVisualEffectView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 28
        contentView.clipsToBounds = true

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        titleLabel.textAlignment = .center
        titleLabel.textColor = .white
        titleLabel.font = AppFont.barlow(size: 15)

        contentView.addSubview(imageView)
        contentView.addSubview(titleBackground)
        titleBackground.contentView.addSubview(titleLabel)

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        titleBackground.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(45)
        }
        titleLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func configure(title: String, imageName: String, isSelected: Bool) {
        imageView.image = UIImage(named: imageName)
        titleLabel.text = title
        titleBackground.effect = isSelected
            ? nil
            : UIBlurEffect(style: .systemUltraThinMaterialLight)
        titleBackground.backgroundColor = isSelected
            ? UIColor(red: 0, green: 242 / 255, blue: 204 / 255, alpha: 1)
            : UIColor.white.withAlphaComponent(0.12)
    }
}

@MainActor
final class RunQUIKitMainTabBarController: UITabBarController {
    private static let designedTabBarHeight: CGFloat = 83
    private let designedTabBar = RunQMainTabBarView()
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore

    init(dataStore: RunQDataStore, sessionStore: CynosureSessionStore) {
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        super.init(nibName: nil, bundle: nil)
        let pages: [UIViewController] = [
            RunQUIKitHomeViewController(dataStore: dataStore, sessionStore: sessionStore),
            RunQUIKitSquareViewController(dataStore: dataStore, sessionStore: sessionStore),
            RunQUIKitReelViewController(dataStore: dataStore, sessionStore: sessionStore),
            RunQUIKitProfileViewController(dataStore: dataStore, sessionStore: sessionStore)
        ]
        viewControllers = pages.map { controller in
            let navigation = RunQNavigationController(rootViewController: controller)
            navigation.navigationBar.isHidden = true
            navigation.onRootVisibilityChange = { [weak self] isRoot, coordinator in
                self?.setDesignedTabBarVisible(isRoot, coordinator: coordinator)
            }
            return navigation
        }
        suppressNativeTabBar()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let initialIndex = arguments.contains("--report-preview")
            || arguments.contains("--report-reason-preview")
            ? 2
            : (arguments.contains("--search-preview")
                || arguments.contains("--search-results-preview")
            ? 1
            : (arguments.contains("--publish-preview")
            ? 1
            : (arguments.contains("--join-chatbox-preview")
                || arguments.contains("--chat-room-preview")
                || arguments.contains("--create-chatbox-preview")
            ? 1
            : (arguments.contains("--delete-account-preview")
                || arguments.contains("--insufficient-balance-preview")
                || arguments.contains("--login-required-preview")
                || arguments.contains("--direct-chat-preview")
                || arguments.contains("--direct-chat-voice-preview")
                || arguments.contains("--profile-preview")
            ? 3
            : (arguments.contains("--followers-preview")
            ? 3
            : (arguments.contains("--reel-preview")
                ? 2
                : (arguments.contains("--square-preview") ? 1 : 0)))))))
        #else
        let initialIndex = 0
        #endif
        selectedIndex = initialIndex
        synchronizeReelPlayback()
        designedTabBar.select(index: initialIndex)
        designedTabBar.onSelect = { [weak self] index in
            self?.requestTabSelection(index) ?? false
        }
        view.addSubview(designedTabBar)
        designedTabBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(Self.designedTabBarHeight)
        }
        #if DEBUG
        if arguments.contains("--notifications-preview"),
           let homeNavigation = viewControllers?.first
            as? UINavigationController {
            homeNavigation.pushViewController(
                RunQEpistolaryPagerViewController(
                    dataStore: dataStore,
                    sessionStore: sessionStore,
                    initialPage: .notifications
                ),
                animated: false
            )
        }
        if arguments.contains("--followers-preview"),
           let profileNavigation = viewControllers?[3]
            as? UINavigationController {
            profileNavigation.pushViewController(
                RunQUIKitBlacklistViewController(
                    initialCategory: .followers,
                    dataStore: dataStore,
                    sessionStore: sessionStore,
                    includesBlacklist: false
                ),
                animated: false
            )
        }
        if arguments.contains("--delete-account-preview"),
           let profileNavigation = viewControllers?[3]
            as? UINavigationController {
            let settings = RunQUIKitSettingsViewController(
                dataStore: dataStore,
                sessionStore: sessionStore
            )
            profileNavigation.pushViewController(settings, animated: false)
            DispatchQueue.main.async {
                settings.openAccountDeletion()
            }
        }
        if arguments.contains("--insufficient-balance-preview"),
           let profileNavigation = viewControllers?[3] as? UINavigationController {
            let settings = RunQUIKitSettingsViewController(
                dataStore: dataStore,
                sessionStore: sessionStore
            )
            profileNavigation.pushViewController(settings, animated: false)
            DispatchQueue.main.async {
                let dialog = RunQInsufficientBalanceViewController()
                dialog.modalPresentationStyle = .overFullScreen
                settings.present(dialog, animated: false)
            }
        }
        if arguments.contains("--login-required-preview"),
           let profileNavigation = viewControllers?[3] as? UINavigationController {
            let settings = RunQUIKitSettingsViewController(
                dataStore: dataStore,
                sessionStore: sessionStore
            )
            profileNavigation.pushViewController(settings, animated: false)
            DispatchQueue.main.async {
                let dialog = RunQUIKitLoginRequiredViewController()
                dialog.modalPresentationStyle = .overFullScreen
                settings.present(dialog, animated: false)
            }
        }
        if arguments.contains("--direct-chat-preview")
            || arguments.contains("--direct-chat-voice-preview"),
           let profileNavigation = viewControllers?[3] as? UINavigationController,
           let peer = dataStore.user(id: "seed-user-2") {
            profileNavigation.pushViewController(
                RunQDirectChatViewController(
                    peer: peer,
                    dataStore: dataStore,
                    sessionStore: sessionStore
                ),
                animated: false
            )
        }
        if arguments.contains("--toll-preview"),
           let previewNavigation = viewControllers?.first
            as? UINavigationController {
            let createPage = RunQUIKitCreateChatboxViewController(
                title: "CREATE MY CHATBOX",
                dataStore: dataStore,
                sessionStore: sessionStore
            )
            previewNavigation.pushViewController(createPage, animated: false)
            DispatchQueue.main.async {
                let toll = RunQUIKitTollViewController(
                    dataStore: self.dataStore,
                    sessionStore: self.sessionStore
                )
                toll.modalPresentationStyle = .overFullScreen
                createPage.present(toll, animated: false)
            }
        }
        if arguments.contains("--publish-preview"),
           let squareNavigation = viewControllers?[1]
            as? UINavigationController {
            squareNavigation.pushViewController(
                RunQUIKitPublishViewController(
                    dataStore: dataStore,
                    sessionStore: sessionStore
                ),
                animated: false
            )
        }
        if arguments.contains("--search-preview")
            || arguments.contains("--search-results-preview"),
           let squareNavigation = viewControllers?[1]
            as? UINavigationController {
            squareNavigation.pushViewController(
                RunQUIKitSearchViewController(
                    title: "SEARCH",
                    dataStore: dataStore,
                    sessionStore: sessionStore
                ),
                animated: false
            )
        }
        if arguments.contains("--ai-chat-preview")
            || arguments.contains("--ai-chat-keyboard-preview"),
           let homeNavigation = viewControllers?.first
            as? UINavigationController {
            homeNavigation.pushViewController(
                RunQUIKitAIChatViewController(
                    title: "AI RUNQ",
                    dataStore: dataStore,
                    sessionStore: sessionStore
                ),
                animated: false
            )
        }
        if arguments.contains("--join-chatbox-preview"),
           let squareNavigation = viewControllers?[1]
            as? UINavigationController,
           let room = dataStore.chatRooms().first {
            let chatboxPage = RunQUIKitChatboxViewController(
                dataStore: dataStore,
                sessionStore: sessionStore
            )
            squareNavigation.pushViewController(chatboxPage, animated: false)
            let previewWorkItem = DispatchWorkItem { [weak chatboxPage] in
                let dialog = RunQUIKitJoinChatboxViewController(
                    room: room,
                    dataStore: self.dataStore,
                    sessionStore: self.sessionStore
                )
                dialog.modalPresentationStyle = .overFullScreen
                chatboxPage?.present(dialog, animated: false)
            }
            DispatchQueue.main.async(execute: previewWorkItem)
        }
        if arguments.contains("--create-chatbox-preview"),
           let squareNavigation = viewControllers?[1]
            as? UINavigationController {
            squareNavigation.pushViewController(
                RunQUIKitCreateChatboxViewController(
                    title: "CREATE MY CHATBOX",
                    dataStore: dataStore,
                    sessionStore: sessionStore
                ),
                animated: false
            )
        }
        if arguments.contains("--chat-room-preview"),
           let squareNavigation = viewControllers?[1] as? UINavigationController,
           let room = dataStore.chatRooms().first(where: { $0.id == "1000784" }) {
            squareNavigation.pushViewController(
                RunQChatRoomViewController(
                    room: room,
                    dataStore: dataStore,
                    sessionStore: sessionStore
                ),
                animated: false
            )
        }
        if arguments.contains("--report-preview"),
           let reelNavigation = viewControllers?[2]
            as? UINavigationController,
           let reel = reelNavigation.viewControllers.first {
            DispatchQueue.main.async {
                let report = RunQUIKitReportViewController()
                report.modalPresentationStyle = .overFullScreen
                reel.present(report, animated: false)
            }
        }
        if arguments.contains("--report-reason-preview"),
           let reelNavigation = viewControllers?[2]
            as? UINavigationController {
            reelNavigation.pushViewController(
                RunQReportReasonViewController(),
                animated: false
            )
        }
        #endif
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        suppressNativeTabBar()
        updateRootContentInsets()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        suppressNativeTabBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        suppressNativeTabBar()
    }

    private func suppressNativeTabBar() {
        tabBar.isHidden = true
        tabBar.alpha = 0
        tabBar.isUserInteractionEnabled = false
        tabBar.accessibilityElementsHidden = true
    }

    private func updateRootContentInsets() {
        let bottomInset = max(
            0,
            Self.designedTabBarHeight - view.safeAreaInsets.bottom
        )
        viewControllers?.forEach { controller in
            guard let navigation = controller as? UINavigationController,
                  let root = navigation.viewControllers.first else { return }
            if root.additionalSafeAreaInsets.bottom != bottomInset {
                root.additionalSafeAreaInsets.bottom = bottomInset
            }
        }
    }

    private func requestTabSelection(_ index: Int) -> Bool {
        guard viewControllers?.indices.contains(index) == true else { return false }
        if index != 0, sessionStore.currentUser?.isGuest == true {
            presentGuestLoginRequirement()
            return false
        }
        selectedIndex = index
        synchronizeReelPlayback()
        return true
    }

    private func synchronizeReelPlayback() {
        guard let reelNavigation = viewControllers?[2]
            as? UINavigationController,
              let reelController = reelNavigation.viewControllers.first
            as? RunQUIKitReelViewController else { return }
        let shouldPlay = selectedIndex == 2
            && reelNavigation.topViewController === reelController
        reelController.setTabPlaybackActive(shouldPlay)
    }

    private func presentGuestLoginRequirement() {
        guard presentedViewController == nil else { return }
        let dialog = RunQUIKitLoginRequiredViewController()
        dialog.modalPresentationStyle = .overFullScreen
        dialog.onSignIn = { [weak self] in
            guard let self,
                  let homeNavigation = viewControllers?.first as? UINavigationController else {
                return
            }
            selectedIndex = 0
            synchronizeReelPlayback()
            designedTabBar.select(index: 0)
            let login = RunQUIKitLoginViewController(
                dataStore: dataStore,
                sessionStore: sessionStore
            )
            login.hidesBottomBarWhenPushed = true
            homeNavigation.pushViewController(login, animated: true)
        }
        present(dialog, animated: true)
    }

    private func setDesignedTabBarVisible(
        _ isVisible: Bool,
        coordinator: UIViewControllerTransitionCoordinator?
    ) {
        suppressNativeTabBar()
        designedTabBar.isUserInteractionEnabled = isVisible
        if isVisible {
            designedTabBar.isHidden = false
        }

        let changes = { [weak self] in
            guard let self else { return }
            designedTabBar.alpha = isVisible ? 1 : 0
            designedTabBar.transform = isVisible
                ? .identity
                : CGAffineTransform(
                    translationX: 0,
                    y: Self.designedTabBarHeight
                )
        }
        let completion: (UIViewControllerTransitionCoordinatorContext) -> Void = {
            [weak self] context in
            guard let self else { return }
            if context.isCancelled {
                synchronizeDesignedTabBar()
            } else {
                designedTabBar.isHidden = !isVisible
            }
        }

        if let coordinator {
            coordinator.animate(
                alongsideTransition: { _ in changes() },
                completion: completion
            )
        } else {
            changes()
            designedTabBar.isHidden = !isVisible
        }
    }

    private func synchronizeDesignedTabBar() {
        let isRoot = (selectedViewController as? UINavigationController)?
            .viewControllers.count == 1
        designedTabBar.isHidden = !isRoot
        designedTabBar.isUserInteractionEnabled = isRoot
        designedTabBar.alpha = isRoot ? 1 : 0
        designedTabBar.transform = isRoot
            ? .identity
            : CGAffineTransform(
                translationX: 0,
                y: Self.designedTabBarHeight
            )
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

private final class RunQMainTabBarView: UIView, UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {
    private let assetNames = [
        "runq_tab_home", "runq_tab_discover", "runq_tab_video",
        "runq_tab_profile"
    ]
    private let layout = UICollectionViewFlowLayout()
    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: layout
    )
    private var selectedIndex = 0
    var onSelect: ((Int) -> Bool)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .runQUIKitBackground
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            RunQMainTabBarCell.self,
            forCellWithReuseIdentifier: RunQMainTabBarCell.reuseIdentifier
        )
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(49)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func select(index: Int) {
        guard assetNames.indices.contains(index) else { return }
        selectedIndex = index
        collectionView.reloadData()
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        assetNames.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RunQMainTabBarCell.reuseIdentifier,
            for: indexPath
        ) as! RunQMainTabBarCell
        cell.configure(
            assetName: assetNames[indexPath.item],
            isSelected: indexPath.item == selectedIndex
        )
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: bounds.width / CGFloat(assetNames.count), height: 49)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        guard selectedIndex != indexPath.item else { return }
        guard onSelect?(indexPath.item) == true else { return }
        selectedIndex = indexPath.item
        collectionView.reloadData()
    }
}

private final class RunQMainTabBarCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQMainTabBarCell"
    private let iconView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        iconView.contentMode = .scaleAspectFit
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(48)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(assetName: String, isSelected: Bool) {
        iconView.image = UIImage(
            named: "\(assetName)_\(isSelected ? "selected" : "normal")"
        )?.withRenderingMode(.alwaysOriginal)
        isAccessibilityElement = true
        accessibilityLabel = switch assetName {
        case "runq_tab_home": "Home"
        case "runq_tab_discover": "Square"
        case "runq_tab_video": "Videos"
        case "runq_tab_profile": "Profile"
        default: "Tab"
        }
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}

private final class RunQUIKitPlaceholderViewController: UIViewController {
    private let pageTitle: String
    init(title: String) { pageTitle = title; super.init(nibName: nil, bundle: nil) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func viewDidLoad() { super.viewDidLoad(); view.backgroundColor = .runQUIKitBackground; let label = runQUIKitLabel(pageTitle, size: 28, weight: .bold); label.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(label); NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: view.centerXAnchor), label.centerYAnchor.constraint(equalTo: view.centerYAnchor)]) }
}

private extension Set where Element == String {
    mutating func toggle(_ value: String) { if contains(value) { remove(value) } else { insert(value) } }
}

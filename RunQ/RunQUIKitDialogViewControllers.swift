import SnapKit
import UIKit

enum RunQEULAConsent {
    private static let versionKey = "runq.eula.accepted.version"
    private static let authorizationAgreementKey = "runq.auth.agreement.accepted"
    private static let currentVersion = 1

    static var isAccepted: Bool {
        UserDefaults.standard.integer(forKey: versionKey) >= currentVersion
    }

    static func accept() {
        UserDefaults.standard.set(currentVersion, forKey: versionKey)
        UserDefaults.standard.set(true, forKey: authorizationAgreementKey)
    }
}

@MainActor
final class RunQObumbratedEulaViewController: UIViewController {
    var onAgree: (() -> Void)?
    var onCancel: (() -> Void)?
    var dismissesOnCancel = true

    private let cancelButton = UIButton(type: .custom)
    private let agreeButton = UIButton(type: .custom)
    private var isResolving = false

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.70)

        let receptacle = UIImageView(image: UIImage(named: "runq_obumbrated_eula_receptacle"))
        receptacle.contentMode = .scaleToFill
        receptacle.isUserInteractionEnabled = true

        let grip = UIView()
        grip.backgroundColor = UIColor(red: 94 / 255, green: 94 / 255, blue: 96 / 255, alpha: 1)
        grip.layer.cornerRadius = 3

        let titleLabel = UILabel()
        titleLabel.text = "EULA"
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.font = AppFont.passionOne(size: 30)

        let agreementView = UITextView()
        agreementView.backgroundColor = .clear
        agreementView.isEditable = false
        agreementView.isSelectable = false
        agreementView.isScrollEnabled = true
        agreementView.showsVerticalScrollIndicator = false
        agreementView.textContainerInset = .zero
        agreementView.textContainer.lineFragmentPadding = 0
        agreementView.accessibilityLabel = "End User License Agreement"
        agreementView.attributedText = agreementText()

        configureButton(cancelButton, title: "Cancel", color: UIColor(
            red: 87 / 255,
            green: 87 / 255,
            blue: 90 / 255,
            alpha: 1
        ))
        configureButton(agreeButton, title: "Agree", color: UIColor(
            red: 1,
            green: 91 / 255,
            blue: 25 / 255,
            alpha: 1
        ))

        cancelButton.addAction(
            UIAction { [weak self] _ in self?.resolve(agreeing: false) },
            for: .touchUpInside
        )
        agreeButton.addAction(
            UIAction { [weak self] _ in self?.resolve(agreeing: true) },
            for: .touchUpInside
        )

        view.addSubview(receptacle)
        [grip, titleLabel, agreementView, cancelButton, agreeButton].forEach(receptacle.addSubview)

        receptacle.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(receptacle.snp.width).multipliedBy(687.0 / 375.0).priority(.high)
            make.top.greaterThanOrEqualTo(view.safeAreaLayoutGuide.snp.top).offset(60)
        }
        grip.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(19)
            make.centerX.equalToSuperview()
            make.width.equalTo(45)
            make.height.equalTo(6)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(45)
            make.centerX.equalToSuperview()
            make.height.equalTo(36)
        }
        agreementView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(96)
            make.leading.equalToSuperview().offset(33)
            make.trailing.equalToSuperview().inset(33)
            make.bottom.equalTo(cancelButton.snp.top).offset(-22)
        }
        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(19)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-1)
            make.height.equalTo(52)
        }
        agreeButton.snp.makeConstraints { make in
            make.leading.equalTo(cancelButton.snp.trailing).offset(19)
            make.trailing.equalToSuperview().inset(17)
            make.bottom.width.height.equalTo(cancelButton)
        }
    }

    private func configureButton(_ button: UIButton, title: String, color: UIColor) {
        button.backgroundColor = color
        button.layer.cornerRadius = 16
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = AppFont.barlow(size: 15)
        button.accessibilityLabel = title
    }

    private func agreementText() -> NSAttributedString {
        let text = """
        Welcome to RunQ! To ensure a safe and positive community for everyone, the following content is strictly prohibited:

        1. Child Harm & Exploitation: Any content related to child harm, abuse, or pornography detrimental to minors.
        2. Misinformation: Fake or harmful messages concerning recent or current events.
        3. Objectionable Content: Any form of violence, bullying, hate speech, explicit pornography, or other abusive material.

        If we discover any content violating these guidelines (including but not limited to the above), your content will be removed, and your account may be permanently banned.

        By clicking "I agree", you acknowledge and agree to our Terms of Use and Privacy Policy.
        """
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 17.1
        paragraph.maximumLineHeight = 17.1
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(
            string: text,
            attributes: [
                .font: AppFont.barlow(size: 14),
                .foregroundColor: UIColor.white.withAlphaComponent(0.56),
                .paragraphStyle: paragraph
            ]
        )
    }

    private func resolve(agreeing: Bool) {
        guard !isResolving else { return }
        isResolving = true
        cancelButton.isEnabled = false
        agreeButton.isEnabled = false
        if !agreeing, !dismissesOnCancel {
            onCancel?()
            isResolving = false
            cancelButton.isEnabled = true
            agreeButton.isEnabled = true
            return
        }
        let action = agreeing ? onAgree : onCancel
        dismiss(animated: true) {
            action?()
        }
    }
}

@MainActor
final class RunQUIKitReportViewController: UIViewController {
    var onReport: (() -> Void)?
    var onBlock: (() -> Void)?
    private var isPerformingAction = false
    private let reportButton = UIButton(type: .custom)
    private let blockButton = UIButton(type: .custom)
    private let cancelButton = UIButton(type: .custom)

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.70)

        let panel = UIImageView(image: UIImage(named: "runq_caliginous_report_plinth"))
        panel.contentMode = .scaleToFill
        panel.isUserInteractionEnabled = true

        let grip = UIImageView(image: UIImage(named: "runq_cinerous_report_grip"))
        grip.contentMode = .scaleAspectFit

        let prompt = UILabel()
        prompt.text = "What do you want to do with this information?"
        prompt.textColor = UIColor.white.withAlphaComponent(0.58)
        prompt.font = AppFont.barlow(size: 13)

        configureActionButton(reportButton, title: "Report this information")
        configureActionButton(blockButton, title: "Block")
        configureActionButton(cancelButton, title: "Cancel")
        cancelButton.backgroundColor = UIColor(
            red: 88 / 255,
            green: 88 / 255,
            blue: 91 / 255,
            alpha: 1
        )
        reportButton.addAction(
            UIAction { [weak self] _ in
                self?.openReportReasons()
            },
            for: .touchUpInside
        )
        blockButton.addAction(
            UIAction { [weak self] _ in self?.finish(self?.onBlock) },
            for: .touchUpInside
        )
        cancelButton.addAction(
            UIAction { [weak self] _ in self?.dismiss(animated: true) },
            for: .touchUpInside
        )

        [panel, grip, prompt, reportButton, blockButton, cancelButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        view.addSubview(panel)
        panel.addSubview(grip)
        panel.addSubview(prompt)
        panel.addSubview(reportButton)
        panel.addSubview(blockButton)
        panel.addSubview(cancelButton)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panel.heightAnchor.constraint(equalToConstant: 346),

            grip.topAnchor.constraint(equalTo: panel.topAnchor, constant: 6),
            grip.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            grip.widthAnchor.constraint(equalToConstant: 46),
            grip.heightAnchor.constraint(equalToConstant: 6),

            prompt.topAnchor.constraint(equalTo: panel.topAnchor, constant: 37),
            prompt.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 47),
            prompt.heightAnchor.constraint(equalToConstant: 18),

            reportButton.topAnchor.constraint(equalTo: panel.topAnchor, constant: 94),
            reportButton.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            reportButton.widthAnchor.constraint(equalToConstant: 195),
            reportButton.heightAnchor.constraint(equalToConstant: 52),

            blockButton.topAnchor.constraint(equalTo: panel.topAnchor, constant: 162),
            blockButton.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            blockButton.widthAnchor.constraint(equalToConstant: 195),
            blockButton.heightAnchor.constraint(equalToConstant: 52),

            cancelButton.topAnchor.constraint(equalTo: panel.topAnchor, constant: 239),
            cancelButton.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 195),
            cancelButton.heightAnchor.constraint(equalToConstant: 52)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    private func configureActionButton(_ button: UIButton, title: String) {
        button.backgroundColor = UIColor(
            red: 1,
            green: 91 / 255,
            blue: 25 / 255,
            alpha: 1
        )
        button.layer.cornerRadius = 16
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = AppFont.barlow(size: 15)
        button.accessibilityLabel = title
    }

    private func finish(
        _ action: (() -> Void)?,
        successMessage: String? = nil
    ) {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        reportButton.isEnabled = false
        blockButton.isEnabled = false
        cancelButton.isEnabled = false
        let presenter = presentingViewController
        dismiss(animated: true) {
            action?()
            if let successMessage, let presenter {
                RunQToastPresenter.show(successMessage, on: presenter.view)
            }
        }
    }

    private func openReportReasons() {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        reportButton.isEnabled = false
        blockButton.isEnabled = false
        cancelButton.isEnabled = false
        let presenter = presentingViewController
        let reportAction = onReport
        dismiss(animated: true) {
            guard let presenter else { return }
            let reasons = RunQReportReasonViewController(onSubmit: reportAction)
            reasons.hidesBottomBarWhenPushed = true
            if let navigationController = presenter.navigationController {
                navigationController.pushViewController(reasons, animated: true)
            } else {
                let navigationController = RunQNavigationController(
                    rootViewController: reasons
                )
                navigationController.modalPresentationStyle = .fullScreen
                presenter.present(navigationController, animated: true)
            }
        }
    }

    @objc private func cancelTapped() {
        guard !isPerformingAction else { return }
        dismiss(animated: true)
    }
}

extension RunQUIKitReportViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touch.view === view
    }
}

@MainActor
final class RunQUIKitJoinChatboxViewController: UIViewController {
    var onJoined: (() -> Void)?
    private let room: RunQChatRoomRecord
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let keyField = UITextField()
    private let joinButton = UIButton(type: .custom)
    private let panel = UIImageView(image: UIImage(named: "runq_chatbox_join_panel"))
    private let lockView = UIImageView(image: UIImage(named: "runq_chatbox_join_lock"))
    private let closeButton = UIButton(type: .system)
    private var isJoining = false

    init(
        room: RunQChatRoomRecord,
        dataStore: RunQDataStore,
        sessionStore: CynosureSessionStore
    ) {
        self.room = room
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
        view.backgroundColor = UIColor.black.withAlphaComponent(0.76)

        panel.contentMode = .scaleToFill
        panel.isUserInteractionEnabled = true
        lockView.contentMode = .scaleAspectFit

        let avatar = UIImageView()
        if let avatarData = room.resolvedAvatarData {
            avatar.image = UIImage(data: avatarData)
        } else {
            avatar.image = UIImage(named: room.ownerAvatarAssetName)
        }
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 17

        let boxLabel = informationLabel("BOX ID:")
        let boxValue = informationLabel(room.id)

        let keyLabel = informationLabel("KEY:")
        keyField.backgroundColor = UIColor(
            red: 80 / 255,
            green: 80 / 255,
            blue: 83 / 255,
            alpha: 1
        )
        keyField.layer.cornerRadius = 16
        keyField.textColor = .white
        keyField.tintColor = .white
        keyField.font = AppFont.barlow(size: 14)
        keyField.placeholder = "Please enter"
        keyField.attributedPlaceholder = NSAttributedString(
            string: "Please enter",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.48)]
        )
        keyField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        keyField.leftViewMode = .always
        keyField.isSecureTextEntry = true
        keyField.returnKeyType = .done
        keyField.delegate = self
        keyField.inputAccessoryView = doneToolbar()

        joinButton.setBackgroundImage(UIImage(named: "runq_btn_bg"), for: .normal)
        joinButton.setTitle("JOIN IN", for: .normal)
        joinButton.setTitleColor(.white, for: .normal)
        joinButton.titleLabel?.font = AppFont.passionOne(size: 17)
        joinButton.accessibilityLabel = "Join chatbox"
        joinButton.addAction(UIAction { [weak self] _ in self?.join() }, for: .touchUpInside)

        closeButton.backgroundColor = .white
        closeButton.layer.cornerRadius = 17
        closeButton.tintColor = UIColor(red: 1, green: 91 / 255, blue: 25 / 255, alpha: 1)
        closeButton.setImage(
            UIImage(systemName: "xmark")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 14, weight: .black)
            ),
            for: .normal
        )
        closeButton.accessibilityLabel = "Close"
        closeButton.addAction(
            UIAction { [weak self] _ in self?.dismiss(animated: true) },
            for: .touchUpInside
        )

        [panel, lockView, closeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        [avatar, boxLabel, boxValue, keyLabel, keyField, joinButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview($0)
        }

        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 7),
            panel.widthAnchor.constraint(equalToConstant: 335),
            panel.heightAnchor.constraint(equalToConstant: 324),

            lockView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            lockView.topAnchor.constraint(equalTo: panel.topAnchor, constant: -117),
            lockView.widthAnchor.constraint(equalToConstant: 214),
            lockView.heightAnchor.constraint(equalToConstant: 214),

            avatar.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 20),
            avatar.topAnchor.constraint(equalTo: panel.topAnchor, constant: 28),
            avatar.widthAnchor.constraint(equalToConstant: 60),
            avatar.heightAnchor.constraint(equalToConstant: 60),

            boxLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 20),
            boxLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 130),
            boxLabel.heightAnchor.constraint(equalToConstant: 20),
            boxValue.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 101),
            boxValue.centerYAnchor.constraint(equalTo: boxLabel.centerYAnchor),
            boxValue.heightAnchor.constraint(equalToConstant: 20),

            keyLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 20),
            keyLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 193),
            keyLabel.heightAnchor.constraint(equalToConstant: 20),
            keyField.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 86),
            keyField.topAnchor.constraint(equalTo: panel.topAnchor, constant: 176),
            keyField.widthAnchor.constraint(equalToConstant: 229),
            keyField.heightAnchor.constraint(equalToConstant: 48),

            joinButton.topAnchor.constraint(equalTo: panel.topAnchor, constant: 248),
            joinButton.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            joinButton.widthAnchor.constraint(equalToConstant: 134),
            joinButton.heightAnchor.constraint(equalToConstant: 52),

            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            closeButton.topAnchor.constraint(equalTo: panel.bottomAnchor, constant: 34),
            closeButton.widthAnchor.constraint(equalToConstant: 34),
            closeButton.heightAnchor.constraint(equalToConstant: 34)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameChanged(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private func informationLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        label.font = AppFont.barlow(size: 14)
        return label
    }

    private func doneToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(
                title: "Done",
                style: .done,
                target: self,
                action: #selector(dismissKeyboard)
            )
        ]
        return toolbar
    }

    private func join() {
        guard !isJoining else { return }
        let key = keyField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else {
            showToast("Please enter the chatbox key.")
            return
        }
        guard let userID = sessionStore.currentUser?.id else {
            showToast("Please sign in first.")
            return
        }
        isJoining = true
        joinButton.isEnabled = false
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.startAnimating()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        joinButton.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerYAnchor.constraint(equalTo: joinButton.centerYAnchor),
            indicator.trailingAnchor.constraint(equalTo: joinButton.trailingAnchor, constant: -14)
        ])
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            do {
                try dataStore.joinChatRoom(roomID: room.id, userID: userID, key: key)
                dismiss(animated: true, completion: onJoined)
            } catch {
                indicator.removeFromSuperview()
                isJoining = false
                joinButton.isEnabled = true
                showToast("The chatbox key is incorrect.")
            }
        }
    }

    private func showToast(_ message: String) {
        let toast = RunQUIKitInsetLabel()
        toast.text = message
        toast.textInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
        toast.textColor = .white
        toast.textAlignment = .center
        toast.font = AppFont.barlow(size: 13)
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.94)
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
        UIView.animate(withDuration: 0.2, delay: 1.6, options: .curveEaseIn) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let info = notification.userInfo,
              let endFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let frame = view.convert(endFrame, from: nil)
        let overlap = max(0, panel.frame.maxY - frame.minY + 16)
        let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveValue = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curveValue << 16)
        ) {
            let transform = CGAffineTransform(translationX: 0, y: -overlap)
            self.panel.transform = transform
            self.lockView.transform = transform
            self.closeButton.transform = transform
        }
    }
}

extension RunQUIKitJoinChatboxViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

@MainActor
final class RunQUIKitTollViewController: UIViewController {
    var onConfirm: (() throws -> Void)?
    var onCompleted: (() -> Void)?
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let purchaseDescription: String
    private let confirmButton = UIButton(type: .custom)
    private var isConfirming = false
    private var loadingView: UIView?

    init(
        dataStore: RunQDataStore,
        sessionStore: CynosureSessionStore,
        purchaseDescription: String = "unlock the AI function"
    ) {
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        self.purchaseDescription = purchaseDescription
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.78)

        let titleLabel = runQUIKitLabel("Are you sure?", size: 24)
        titleLabel.font = AppFont.barlow(size: 24, weight: .semibold)
        titleLabel.textAlignment = .center

        let leftBeam = UIImageView(
            image: UIImage(named: "runq_albescent_toll_lumen_sinistral")
        )
        let rightBeam = UIImageView(
            image: UIImage(named: "runq_albescent_toll_lumen_dextral")
        )
        [leftBeam, rightBeam].forEach {
            $0.contentMode = .scaleAspectFit
        }

        let coinView = UIImageView(
            image: UIImage(named: "runq_chrysolitic_toll_aureole")
        )
        coinView.contentMode = .scaleAspectFit

        let messagePanel = UIView()
        messagePanel.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        messagePanel.layer.cornerRadius = 16
        let messageLabel = runQUIKitLabel(
            "You want to spend 200 gold coins to\n\(purchaseDescription)?",
            size: 13
        )
        messageLabel.font = AppFont.barlow(size: 13, weight: .semibold)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 2
        messagePanel.addSubview(messageLabel)

        confirmButton.setBackgroundImage(
            UIImage(named: "runq_ember_affinity_cta"),
            for: .normal
        )
        confirmButton.setTitle("SURE", for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = AppFont.passionOne(size: 17)
        confirmButton.accessibilityLabel = "Confirm 200 coin payment"
        confirmButton.addAction(
            UIAction { [weak self] _ in self?.confirm() },
            for: .touchUpInside
        )

        let closeButton = UIButton(type: .system)
        closeButton.backgroundColor = .white
        closeButton.layer.cornerRadius = 17
        closeButton.tintColor = UIColor(
            red: 1,
            green: 91 / 255,
            blue: 25 / 255,
            alpha: 1
        )
        closeButton.setImage(
            UIImage(systemName: "xmark")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 14, weight: .black)
            ),
            for: .normal
        )
        closeButton.accessibilityLabel = "Cancel"
        closeButton.addAction(
            UIAction { [weak self] _ in self?.dismiss(animated: true) },
            for: .touchUpInside
        )

        [leftBeam, rightBeam, coinView, titleLabel, messagePanel,
         confirmButton, closeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 207),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 29),

            leftBeam.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 43),
            leftBeam.topAnchor.constraint(equalTo: view.topAnchor, constant: 307),
            leftBeam.widthAnchor.constraint(equalToConstant: 90),
            leftBeam.heightAnchor.constraint(equalToConstant: 105),
            rightBeam.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -43),
            rightBeam.topAnchor.constraint(equalTo: leftBeam.topAnchor),
            rightBeam.widthAnchor.constraint(equalToConstant: 90),
            rightBeam.heightAnchor.constraint(equalToConstant: 105),

            coinView.topAnchor.constraint(equalTo: view.topAnchor, constant: 227),
            coinView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coinView.widthAnchor.constraint(equalToConstant: 214),
            coinView.heightAnchor.constraint(equalToConstant: 214),

            messagePanel.topAnchor.constraint(equalTo: view.topAnchor, constant: 407),
            messagePanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            messagePanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            messagePanel.heightAnchor.constraint(equalToConstant: 48),
            messageLabel.centerXAnchor.constraint(equalTo: messagePanel.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: messagePanel.centerYAnchor),
            messageLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: messagePanel.leadingAnchor,
                constant: 12
            ),
            messageLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: messagePanel.trailingAnchor,
                constant: -12
            ),

            confirmButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 476),
            confirmButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 134),
            confirmButton.heightAnchor.constraint(equalToConstant: 52),

            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 562),
            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 34),
            closeButton.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func confirm() {
        guard !isConfirming else { return }
        guard let userID = sessionStore.currentUser?.id else {
            showToast("Please sign in first.")
            return
        }
        let availableBalance: Int
        do {
            availableBalance = try RunQChrysalBalanceVault.shared.balance(
                userID: userID
            )
        } catch {
            showToast("Unable to read your coin balance.")
            return
        }
        guard availableBalance >= 200 else {
            showInsufficientBalance()
            return
        }

        isConfirming = true
        confirmButton.isEnabled = false
        showLoading()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            do {
                _ = try RunQChrysalBalanceVault.shared.apply(
                    delta: -200,
                    userID: userID,
                    dataStore: dataStore
                )
                do {
                    try onConfirm?()
                } catch {
                    _ = try? RunQChrysalBalanceVault.shared.apply(
                        delta: 200,
                        userID: userID,
                        dataStore: dataStore
                    )
                    throw error
                }
                hideLoading()
                dismiss(animated: true, completion: onCompleted)
            } catch {
                hideLoading()
                isConfirming = false
                confirmButton.isEnabled = true
                showToast("Unable to complete this purchase.")
            }
        }
    }

    private func showInsufficientBalance() {
        let presenter = presentingViewController
        dismiss(animated: true) { [dataStore, sessionStore] in
            guard let presenter else { return }
            let dialog = RunQInsufficientBalanceViewController()
            dialog.modalPresentationStyle = .overFullScreen
            dialog.onRecharge = { [weak presenter] in
                let wallet = RunQUIKitWalletViewController(
                    title: "WALLET",
                    dataStore: dataStore,
                    sessionStore: sessionStore
                )
                presenter?.navigationController?.pushViewController(wallet, animated: true)
            }
            presenter.present(dialog, animated: true)
        }
    }

    private func showLoading() {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
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
        toast.textInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
        toast.textColor = .white
        toast.textAlignment = .center
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.94)
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        view.addSubview(toast)
        toast.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-24)
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
        }
        UIView.animate(withDuration: 0.2, delay: 1.6, options: .curveEaseIn) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }
}

@MainActor
final class RunQUIKitLoginRequiredViewController: UIViewController {
    var onSignIn: (() -> Void)?
    private var isTransitioning = false

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.78)

        let panel = UIImageView(
            image: UIImage(named: "runq_lethean_deletion_plinth")
        )
        panel.contentMode = .scaleToFill
        panel.isUserInteractionEnabled = true

        let illustration = UIImageView(
            image: UIImage(named: "runq_login_required_lock")
        )
        illustration.contentMode = .scaleAspectFit

        let messageLabel = UILabel()
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 24
        paragraph.maximumLineHeight = 24
        messageLabel.attributedText = NSAttributedString(
            string: "To ensure the normal\noperation of\nthe function, please log in to\nyour account first.",
            attributes: [
                .font: AppFont.barlow(size: 16),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
        )
        messageLabel.numberOfLines = 4

        let cancelButton = actionButton(title: "CANCEL")
        cancelButton.accessibilityLabel = "Cancel sign in"
        cancelButton.addAction(
            UIAction { [weak self] _ in self?.cancel() },
            for: .touchUpInside
        )

        let signInButton = actionButton(title: "SIGN IN")
        signInButton.accessibilityLabel = "Sign in"
        signInButton.addAction(
            UIAction { [weak self] _ in self?.signIn() },
            for: .touchUpInside
        )

        let closeButton = UIButton(type: .custom)
        closeButton.backgroundColor = .white
        closeButton.tintColor = UIColor(
            red: 1,
            green: 91 / 255,
            blue: 25 / 255,
            alpha: 1
        )
        closeButton.layer.cornerRadius = 17
        closeButton.setImage(
            UIImage(systemName: "xmark")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 14, weight: .black)
            ),
            for: .normal
        )
        closeButton.accessibilityLabel = "Close"
        closeButton.addAction(
            UIAction { [weak self] _ in self?.cancel() },
            for: .touchUpInside
        )

        view.addSubview(panel)
        view.addSubview(illustration)
        panel.addSubview(messageLabel)
        panel.addSubview(cancelButton)
        panel.addSubview(signInButton)
        view.addSubview(closeButton)

        panel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.centerY.equalToSuperview().offset(7)
            make.height.equalTo(panel.snp.width).multipliedBy(323.0 / 335.0)
        }
        illustration.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(panel.snp.top).offset(-85)
            make.size.equalTo(214)
        }
        messageLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(103)
            make.leading.equalToSuperview().offset(50)
            make.trailing.equalToSuperview().offset(-50)
            make.height.equalTo(96)
        }
        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-32)
            make.height.equalTo(52)
        }
        signInButton.snp.makeConstraints { make in
            make.leading.equalTo(cancelButton.snp.trailing).offset(30)
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.width.height.equalTo(cancelButton)
        }
        closeButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(panel.snp.bottom).offset(35)
            make.size.equalTo(34)
        }
    }

    private func actionButton(title: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(
            UIImage(named: "runq_ember_affinity_cta"),
            for: .normal
        )
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = AppFont.passionOne(size: 17)
        return button
    }

    private func cancel() {
        guard !isTransitioning else { return }
        isTransitioning = true
        dismiss(animated: true)
    }

    private func signIn() {
        guard !isTransitioning else { return }
        isTransitioning = true
        let action = onSignIn
        dismiss(animated: true, completion: action)
    }
}

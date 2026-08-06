import SnapKit
import UIKit

@MainActor
final class RunQUIKitDeleteAccountViewController: UIViewController {
    var onCancel: (() -> Void)?

    private let sessionStore: CynosureSessionStore
    private let confirmButton = UIButton(type: .custom)
    private let sureButton = UIButton(type: .custom)
    private let closeButton = RunQDeleteCloseButton(type: .custom)
    private let logoutBackdrop = UIView()
    private var loadingView: UIView?

    init(sessionStore: CynosureSessionStore) {
        self.sessionStore = sessionStore
        super.init(nibName: nil, bundle: nil)
        modalPresentationCapturesStatusBarAppearance = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    private func configureView() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.8)

        let panelView = UIImageView(
            image: UIImage(named: "runq_lethean_deletion_plinth")
        )
        panelView.contentMode = .scaleToFill

        let illustrationView = UIImageView(
            image: UIImage(named: "runq_exuviae_deletion_receptacle")
        )
        illustrationView.contentMode = .scaleAspectFit

        let messageLabel = UILabel()
        messageLabel.attributedText = deletionMessage
        messageLabel.textColor = UIColor(white: 0.95, alpha: 1)
        messageLabel.numberOfLines = 4

        configureDimmedAction(
            confirmButton,
            title: "Deactivate Account",
            backgroundColor: UIColor(red: 51 / 255, green: 20 / 255, blue: 5 / 255, alpha: 1)
        )
        confirmButton.accessibilityLabel = "Confirm account deletion"
        confirmButton.isUserInteractionEnabled = false

        sureButton.setBackgroundImage(
            UIImage(named: "runq_btn_bg"),
            for: .normal
        )
        sureButton.setTitle("SURE", for: .normal)
        sureButton.setTitleColor(.white, for: .normal)
        sureButton.titleLabel?.font = AppFont.passionOne(size: 17)
        sureButton.accessibilityLabel = "Confirm account deletion"
        sureButton.addAction(
            UIAction { [weak self] _ in self?.deleteAccount() },
            for: .touchUpInside
        )

        logoutBackdrop.backgroundColor = UIColor(
            red: 10 / 255,
            green: 10 / 255,
            blue: 10 / 255,
            alpha: 1
        )
        logoutBackdrop.layer.cornerRadius = 26
        let logoutLabel = UILabel()
        logoutLabel.text = "Logout"
        logoutLabel.textAlignment = .center
        logoutLabel.textColor = UIColor(white: 0.25, alpha: 1)
        logoutLabel.font = AppFont.barlow(size: 14)
        logoutBackdrop.addSubview(logoutLabel)

        closeButton.accessibilityLabel = "Cancel account deletion"
        closeButton.addAction(
            UIAction { [weak self] _ in self?.cancel() },
            for: .touchUpInside
        )

        [panelView, illustrationView, messageLabel, sureButton, confirmButton,
         logoutBackdrop, closeButton].forEach(view.addSubview)

        panelView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.centerY.equalToSuperview().offset(7)
            make.height.equalTo(panelView.snp.width).multipliedBy(324.0 / 335.0)
        }
        illustrationView.snp.makeConstraints { make in
            make.top.equalTo(panelView.snp.top).offset(-100)
            make.centerX.equalToSuperview()
            make.size.equalTo(220)
        }
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(panelView.snp.top).offset(101)
            make.leading.equalToSuperview().offset(69)
            make.trailing.equalToSuperview().offset(-54)
        }
        sureButton.snp.makeConstraints { make in
            make.top.equalTo(panelView.snp.top).offset(240)
            make.centerX.equalToSuperview()
            make.width.equalTo(134)
            make.height.equalTo(52)
        }
        confirmButton.snp.makeConstraints { make in
            make.top.equalTo(panelView.snp.bottom).offset(58)
            make.centerX.equalToSuperview()
            make.width.equalTo(195)
            make.height.equalTo(52)
        }
        logoutBackdrop.snp.makeConstraints { make in
            make.top.equalTo(confirmButton.snp.bottom).offset(24)
            make.centerX.width.equalTo(confirmButton)
            make.height.equalTo(52)
        }
        logoutLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(panelView.snp.bottom).offset(36)
            make.centerX.equalToSuperview()
            make.size.equalTo(32)
        }
    }

    private var deletionMessage: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 24
        paragraph.maximumLineHeight = 24
        return NSAttributedString(
            string: "Deleting the account will clear\nthe data.\nAre you sure you want to\ncontinue?",
            attributes: [
                .font: AppFont.barlow(size: 18),
                .foregroundColor: UIColor(white: 0.95, alpha: 1),
                .paragraphStyle: paragraph
            ]
        )
    }

    private func configureDimmedAction(
        _ button: UIButton,
        title: String,
        backgroundColor: UIColor
    ) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIColor(white: 0.22, alpha: 1), for: .normal)
        button.titleLabel?.font = AppFont.barlow(size: 14)
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 26.5
    }

    private func deleteAccount() {
        guard sessionStore.currentUser != nil else {
            showToast("Unable to delete this account.")
            return
        }
        guard loadingView == nil else { return }

        sureButton.isEnabled = false
        closeButton.isEnabled = false
        showLoading()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            do {
                try sessionStore.deleteCurrentAccount()
                let root = view.window?.rootViewController
                    as? RunQRootViewController
                hideLoading()
                dismiss(animated: false) {
                    root?.refreshRoot()
                }
            } catch {
                hideLoading()
                sureButton.isEnabled = true
                closeButton.isEnabled = true
                showToast("Unable to delete this account.")
            }
        }
    }

    private func cancel() {
        dismiss(animated: false, completion: onCancel)
    }

    private func showLoading() {
        guard loadingView == nil else { return }
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlay.isUserInteractionEnabled = true

        let panel = UIView()
        panel.backgroundColor = UIColor(
            red: 47 / 255,
            green: 47 / 255,
            blue: 52 / 255,
            alpha: 0.96
        )
        panel.layer.cornerRadius = 18

        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()

        let label = UILabel()
        label.text = "Deleting..."
        label.textColor = .white
        label.textAlignment = .center
        label.font = AppFont.barlow(size: 14, weight: .medium)

        overlay.addSubview(panel)
        panel.addSubview(indicator)
        panel.addSubview(label)
        view.addSubview(overlay)
        overlay.snp.makeConstraints { make in make.edges.equalToSuperview() }
        panel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(132)
            make.height.equalTo(116)
        }
        indicator.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(19)
            make.centerX.equalToSuperview()
        }
        label.snp.makeConstraints { make in
            make.top.equalTo(indicator.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(10)
        }
        view.layoutIfNeeded()
        loadingView = overlay
    }

    private func hideLoading() {
        loadingView?.removeFromSuperview()
        loadingView = nil
    }

    private func showToast(_ message: String) {
        let toast = RunQDeleteToastLabel()
        toast.text = message
        toast.textAlignment = .center
        toast.textColor = .white
        toast.font = AppFont.barlow(size: 13)
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        view.addSubview(toast)
        toast.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(sureButton.snp.top).offset(-20)
            make.height.equalTo(40)
        }
        UIView.animate(withDuration: 0.2, delay: 1.6, options: .curveEaseIn) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }
}

private final class RunQDeleteCloseButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        layer.cornerRadius = 16

        let firstStroke = UIView()
        let secondStroke = UIView()
        [firstStroke, secondStroke].forEach {
            $0.backgroundColor = UIColor(
                red: 1,
                green: 98 / 255,
                blue: 25 / 255,
                alpha: 1
            )
            $0.layer.cornerRadius = 1
            $0.isUserInteractionEnabled = false
            addSubview($0)
            $0.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.equalTo(12)
                make.height.equalTo(2)
            }
        }
        firstStroke.transform = CGAffineTransform(rotationAngle: .pi / 4)
        secondStroke.transform = CGAffineTransform(rotationAngle: -.pi / 4)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}

private final class RunQDeleteToastLabel: UILabel {
    private let contentInsets = UIEdgeInsets(
        top: 0,
        left: 16,
        bottom: 0,
        right: 16
    )

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }
}

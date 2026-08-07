import SnapKit
import UIKit

@MainActor
final class RunQInsufficientBalanceViewController: UIViewController {
    var onRecharge: (() -> Void)?
    private let confirmButton = UIButton(type: .custom)
    private var isConfirming = false

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationCapturesStatusBarAppearance = true
        configureView()
    }

    private func configureView() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.80)

        let panel = UIImageView(image: UIImage(named: "runq_lethean_deletion_plinth"))
        panel.contentMode = .scaleToFill

        let coin = UIImageView(image: UIImage(named: "runq_insufficient_balance_coin"))
        coin.contentMode = .scaleAspectFit

        let messageLabel = UILabel()
        messageLabel.attributedText = messageText
        messageLabel.numberOfLines = 3

        let cancelButton = actionButton(title: "CANCEL")
        cancelButton.accessibilityLabel = "Cancel recharge"
        cancelButton.addAction(
            UIAction { [weak self] _ in self?.dismiss(animated: true) },
            for: .touchUpInside
        )

        configureActionButton(confirmButton, title: "CONFIRM")
        confirmButton.accessibilityLabel = "Recharge coins"
        confirmButton.addAction(
            UIAction { [weak self] _ in self?.confirmRecharge() },
            for: .touchUpInside
        )

        let closeButton = RunQInsufficientBalanceCloseButton(type: .custom)
        closeButton.accessibilityLabel = "Close"
        closeButton.addAction(
            UIAction { [weak self] _ in self?.dismiss(animated: true) },
            for: .touchUpInside
        )

        [panel, coin, messageLabel, cancelButton, confirmButton, closeButton].forEach(view.addSubview)

        panel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.centerY.equalToSuperview().offset(7)
            make.height.equalTo(panel.snp.width).multipliedBy(324.0 / 335.0)
        }
        coin.snp.makeConstraints { make in
            make.top.equalTo(panel.snp.top).offset(-100)
            make.centerX.equalToSuperview()
            make.size.equalTo(214)
        }
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(panel.snp.top).offset(101)
            make.leading.equalTo(panel.snp.leading).offset(49)
            make.trailing.equalTo(panel.snp.trailing).inset(34)
        }
        cancelButton.snp.makeConstraints { make in
            make.leading.equalTo(panel.snp.leading).offset(20)
            make.top.equalTo(panel.snp.top).offset(240)
            make.size.equalTo(CGSize(width: 133, height: 52))
        }
        confirmButton.snp.makeConstraints { make in
            make.trailing.equalTo(panel.snp.trailing).inset(19)
            make.top.size.equalTo(cancelButton)
        }
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(panel.snp.bottom).offset(36)
            make.centerX.equalToSuperview()
            make.size.equalTo(32)
        }
    }

    private var messageText: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 24
        paragraph.maximumLineHeight = 24
        return NSAttributedString(
            string: "You don't have enough Coins\nto continue. Would you like to\nrecharge now?",
            attributes: [
                .font: AppFont.barlow(size: 18),
                .foregroundColor: UIColor(white: 0.95, alpha: 1),
                .paragraphStyle: paragraph
            ]
        )
    }

    private func actionButton(title: String) -> UIButton {
        let button = UIButton(type: .custom)
        configureActionButton(button, title: title)
        return button
    }

    private func configureActionButton(_ button: UIButton, title: String) {
        button.setBackgroundImage(UIImage(named: "runq_btn_bg"), for: .normal)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = AppFont.passionOne(size: 17)
    }

    private func confirmRecharge() {
        guard !isConfirming else { return }
        isConfirming = true
        confirmButton.isEnabled = false
        let rechargeAction = onRecharge
        dismiss(animated: true) {
            DispatchQueue.main.async {
                rechargeAction?()
            }
        }
    }
}

private final class RunQInsufficientBalanceCloseButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        layer.cornerRadius = 16

        let firstStroke = UIView()
        let secondStroke = UIView()
        [firstStroke, secondStroke].forEach {
            $0.backgroundColor = UIColor(red: 1, green: 98 / 255, blue: 25 / 255, alpha: 1)
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

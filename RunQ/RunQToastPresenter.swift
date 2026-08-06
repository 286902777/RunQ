import SnapKit
import UIKit

@MainActor
enum RunQToastPresenter {
    private static let toastTag = 8_104_221

    static func show(_ message: String, on hostView: UIView) {
        hostView.viewWithTag(toastTag)?.removeFromSuperview()

        let toast = RunQToastLabel()
        toast.tag = toastTag
        toast.text = message
        toast.textAlignment = .center
        toast.textColor = .white
        toast.font = AppFont.barlow(size: 13)
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        hostView.addSubview(toast)
        toast.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(hostView.safeAreaLayoutGuide).offset(-96)
            make.height.equalTo(40)
            make.leading.greaterThanOrEqualToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
        }

        UIView.animate(withDuration: 0.2, delay: 1.6, options: .curveEaseIn) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }
}

private final class RunQToastLabel: UILabel {
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

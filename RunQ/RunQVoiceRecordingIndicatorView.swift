import UIKit

@MainActor
final class RunQVoiceRecordingIndicatorView: UIView {
    private let pulseView = UIView()
    private let microphoneView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        isUserInteractionEnabled = false
        backgroundColor = UIColor.black.withAlphaComponent(0.82)
        layer.cornerRadius = 20
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: 8)

        pulseView.backgroundColor = UIColor(
            red: 1,
            green: 91 / 255,
            blue: 25 / 255,
            alpha: 0.28
        )
        pulseView.layer.cornerRadius = 30

        microphoneView.image = UIImage(
            systemName: "mic.fill",
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 25,
                weight: .semibold
            )
        )
        microphoneView.tintColor = .white
        microphoneView.contentMode = .center
        microphoneView.backgroundColor = UIColor(
            red: 1,
            green: 91 / 255,
            blue: 25 / 255,
            alpha: 1
        )
        microphoneView.layer.cornerRadius = 23

        titleLabel.text = "Recording..."
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.font = AppFont.barlow(size: 13, weight: .medium)

        [pulseView, microphoneView, titleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            pulseView.topAnchor.constraint(equalTo: topAnchor, constant: 13),
            pulseView.centerXAnchor.constraint(equalTo: centerXAnchor),
            pulseView.widthAnchor.constraint(equalToConstant: 60),
            pulseView.heightAnchor.constraint(equalToConstant: 60),
            microphoneView.centerXAnchor.constraint(equalTo: pulseView.centerXAnchor),
            microphoneView.centerYAnchor.constraint(equalTo: pulseView.centerYAnchor),
            microphoneView.widthAnchor.constraint(equalToConstant: 46),
            microphoneView.heightAnchor.constraint(equalToConstant: 46),
            titleLabel.topAnchor.constraint(equalTo: pulseView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func show(in container: UIView) {
        layer.removeAllAnimations()
        pulseView.layer.removeAllAnimations()
        if superview !== container {
            removeFromSuperview()
            translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(self)
            NSLayoutConstraint.activate([
                centerXAnchor.constraint(equalTo: container.centerXAnchor),
                centerYAnchor.constraint(equalTo: container.centerYAnchor),
                widthAnchor.constraint(equalToConstant: 116),
                heightAnchor.constraint(equalToConstant: 116)
            ])
        }
        container.bringSubviewToFront(self)
        isHidden = false
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseOut]
        ) {
            self.alpha = 1
            self.transform = .identity
        }

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = 1.2
        scale.duration = 0.62
        scale.autoreverses = true
        scale.repeatCount = .infinity
        scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseView.layer.add(scale, forKey: "runq.recording.pulse")

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.35
        opacity.toValue = 1
        opacity.duration = 0.62
        opacity.autoreverses = true
        opacity.repeatCount = .infinity
        opacity.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseView.layer.add(opacity, forKey: "runq.recording.opacity")
    }

    func hide(animated: Bool = true) {
        pulseView.layer.removeAllAnimations()
        guard !isHidden else { return }
        let changes = {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        }
        let completion: (Bool) -> Void = { _ in
            self.isHidden = true
            self.alpha = 1
            self.transform = .identity
        }
        if animated {
            UIView.animate(
                withDuration: 0.16,
                delay: 0,
                options: [.beginFromCurrentState, .curveEaseIn],
                animations: changes,
                completion: completion
            )
        } else {
            changes()
            completion(true)
        }
    }
}

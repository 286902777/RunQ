import SnapKit
import UIKit

@MainActor
enum RunQAuroralTabBackdrop {
    @discardableResult
    static func install(in containerView: UIView) -> UIImageView {
        let imageView = UIImageView(
            image: UIImage(named: "runq_aurora_affinity_backdrop")
        )
        imageView.contentMode = .scaleToFill
        imageView.clipsToBounds = true
        containerView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(imageView.snp.width).multipliedBy(324.0 / 375.0)
        }
        return imageView
    }
}

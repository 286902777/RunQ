import SnapKit
import UIKit

@MainActor
final class RunQReportReasonViewController: UIViewController {
    private let reasons = [
        "DANGEROUS ACTIVITY OR ADVICE",
        "HARASSMENT OR HATE",
        "WILDLIFE HARM",
        "ILLEGAL TRESPASSING",
        "SPAM OR MISLEADING CONTENT",
        "SOMETHING ELSE"
    ]
    private let onSubmit: (() -> Void)?
    private let collectionView: UICollectionView
    private let continueButton = UIButton(type: .custom)
    private var selectedIndex = 0
    private var loadingView: UIView?
    private var isSubmitting = false

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    init(onSubmit: (() -> Void)? = nil) {
        self.onSubmit = onSubmit
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 23
        layout.minimumInteritemSpacing = 0
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        configureConstraints()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    private func configureViews() {
        view.backgroundColor = UIColor(
            red: 20 / 255,
            green: 19 / 255,
            blue: 18 / 255,
            alpha: 1
        )

        let backButton = UIButton(type: .custom)
        backButton.setImage(
            UIImage(named: "runq_navigation_back")?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        backButton.accessibilityLabel = "Back"
        backButton.addAction(
            UIAction { [weak self] _ in self?.close() },
            for: .touchUpInside
        )

        let titleLabel = UILabel()
        titleLabel.text = "REPORT"
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.font = AppFont.passionOne(size: 24)

        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            RunQReportReasonCell.self,
            forCellWithReuseIdentifier: RunQReportReasonCell.reuseIdentifier
        )

        continueButton.setBackgroundImage(
            UIImage(named: "runq_ember_affinity_cta"),
            for: .normal
        )
        continueButton.setTitle("Continue", for: .normal)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.titleLabel?.font = AppFont.barlow(size: 18)
        continueButton.accessibilityLabel = "Continue report"
        continueButton.addAction(
            UIAction { [weak self] _ in self?.submitReport() },
            for: .touchUpInside
        )

        [backButton, titleLabel, collectionView, continueButton].forEach(view.addSubview)

        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(3)
            make.size.equalTo(44)
        }
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(backButton)
            make.height.equalTo(36)
        }
    }

    private func configureConstraints() {
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(78)
            make.leading.trailing.equalToSuperview().inset(26)
            make.bottom.equalTo(continueButton.snp.top).offset(-20)
        }
        continueButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-18)
            make.size.equalTo(CGSize(width: 195, height: 52))
        }
    }

    private func submitReport() {
        guard !isSubmitting else { return }
        guard reasons.indices.contains(selectedIndex) else {
            RunQToastPresenter.show("Select a report reason.", on: view)
            return
        }
        isSubmitting = true
        continueButton.isEnabled = false
        collectionView.isUserInteractionEnabled = false
        showLoading()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            self.hideLoading()
            self.onSubmit?()

            guard let hostView = self.navigationController?.view ?? self.viewIfLoaded else { return }
            RunQToastPresenter.show("Report submitted.", on: hostView)
            if let navigationController = self.navigationController,
               navigationController.viewControllers.count > 1 {
                navigationController.popViewController(animated: true)
            } else {
                self.dismiss(animated: true)
            }
        }
    }

    private func close() {
        if let navigationController,
           navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func showLoading() {
        guard loadingView == nil else { return }
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        overlay.addSubview(indicator)
        view.addSubview(overlay)
        overlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        indicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        loadingView = overlay
    }

    private func hideLoading() {
        loadingView?.removeFromSuperview()
        loadingView = nil
    }
}

extension RunQReportReasonViewController: UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        reasons.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RunQReportReasonCell.reuseIdentifier,
            for: indexPath
        ) as! RunQReportReasonCell
        cell.configure(
            title: reasons[indexPath.item],
            isSelected: indexPath.item == selectedIndex
        )
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: 40)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard selectedIndex != indexPath.item else { return }
        let previousIndex = selectedIndex
        selectedIndex = indexPath.item
        collectionView.reloadItems(at: [
            IndexPath(item: previousIndex, section: 0),
            indexPath
        ])
    }
}

private final class RunQReportReasonCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQReportReasonCell"

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true

        titleLabel.textAlignment = .center
        titleLabel.textColor = .white
        titleLabel.font = AppFont.barlow(size: 15)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.82
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func configure(title: String, isSelected: Bool) {
        titleLabel.text = title
        accessibilityLabel = title
        accessibilityTraits = isSelected ? [.button, .selected] : .button
        contentView.backgroundColor = isSelected
            ? UIColor(red: 21 / 255, green: 45 / 255, blue: 38 / 255, alpha: 1)
            : UIColor(red: 79 / 255, green: 79 / 255, blue: 82 / 255, alpha: 1)
        contentView.layer.borderWidth = isSelected ? 1 : 0
        contentView.layer.borderColor = UIColor(
            red: 26 / 255,
            green: 1,
            blue: 198 / 255,
            alpha: 1
        ).cgColor
    }
}

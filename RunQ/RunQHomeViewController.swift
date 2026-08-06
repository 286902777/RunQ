import SnapKit
import UIKit

private enum RunQHomeCategory: Int, CaseIterable {
    case featured
    case climbing
    case surfing
    case diving
    case skydiving
    case gym

    var title: String {
        switch self {
        case .featured: "FEATURED"
        case .climbing: "CLIMBING"
        case .surfing: "SURFING"
        case .diving: "DIVING"
        case .skydiving: "SKYDIVING"
        case .gym: "GYM"
        }
    }

    var iconAssetName: String? {
        self == .featured ? "runq_home_featured" : nil
    }

    func includes(_ user: RunQUserRecord) -> Bool {
        switch self {
        case .featured:
            true
        case .climbing:
            user.category.localizedCaseInsensitiveContains("CLIMB")
        case .surfing:
            user.category.localizedCaseInsensitiveContains("SURF")
        case .diving:
            user.category.localizedCaseInsensitiveContains("DIVING")
                && !user.category.localizedCaseInsensitiveContains("SKYDIVING")
        case .skydiving:
            user.category.localizedCaseInsensitiveContains("SKYDIVING")
        case .gym:
            user.category.localizedCaseInsensitiveContains("GYM")
        }
    }
}

@MainActor
final class RunQUIKitHomeViewController: UIViewController {
    private enum Section: Int, CaseIterable {
        case coach
        case categories
        case buddies
    }

    private static var hasPresentedInitialLoading = false
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let navigationView = UIView()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    private var loadingView: UIView?
    private var allBuddies: [RunQUserRecord] = []
    private var buddies: [RunQUserRecord] = []
    private var selectedCategory: RunQHomeCategory = .featured

    init(dataStore: RunQDataStore, sessionStore: CynosureSessionStore) {
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .runQUIKitBackground
        configureBackdrop()
        configureNavigation()
        configureCollectionView()
        reloadBuddies()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(socialDataDidChange),
            name: .runQSocialDataDidChange,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadBuddies()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !Self.hasPresentedInitialLoading else { return }
        Self.hasPresentedInitialLoading = true
        showInitialLoading()
    }

    @objc private func socialDataDidChange() {
        reloadBuddies()
    }

    private func configureBackdrop() {
        RunQAuroralTabBackdrop.install(in: view)
    }

    private func configureNavigation() {
        navigationView.backgroundColor = .clear
        view.addSubview(navigationView)

        let titleLabel = UILabel()
        titleLabel.text = "RUNQ"
        titleLabel.textColor = .white
        titleLabel.font = AppFont.passionOne(size: 28)

        let logoView = UIImageView(image: UIImage(named: "runq_home_logo_dumbbell"))
        logoView.contentMode = .scaleAspectFit

        let notificationButton = UIButton(type: .custom)
        notificationButton.setImage(UIImage(named: "runq_home_notifications"), for: .normal)
        notificationButton.accessibilityLabel = "Notifications"
        notificationButton.addAction(UIAction { [weak self] _ in
            self?.openMessages()
        }, for: .touchUpInside)

        navigationView.addSubview(titleLabel)
        navigationView.addSubview(logoView)
        navigationView.addSubview(notificationButton)
        navigationView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(-2)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(56)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }
        logoView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(12)
            make.centerY.equalTo(titleLabel)
            make.size.equalTo(28)
        }
        notificationButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.size.equalTo(48)
        }
    }

    private func openMessages() {
        guard requireAccount() else { return }
        navigationController?.pushViewController(
            RunQEpistolaryPagerViewController(
                dataStore: dataStore,
                sessionStore: sessionStore,
                initialPage: .notifications
            ),
            animated: true
        )
    }

    private func configureCollectionView() {
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(RunQHomeCoachCell.self, forCellWithReuseIdentifier: RunQHomeCoachCell.reuseIdentifier)
        collectionView.register(RunQHomeCategoryStripCell.self, forCellWithReuseIdentifier: RunQHomeCategoryStripCell.reuseIdentifier)
        collectionView.register(RunQHomeBuddyCell.self, forCellWithReuseIdentifier: RunQHomeBuddyCell.reuseIdentifier)
        view.insertSubview(collectionView, belowSubview: navigationView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(navigationView.snp.bottom).offset(-24)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            guard let section = Section(rawValue: sectionIndex) else { return nil }
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
            switch section {
            case .coach:
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(160)), subitems: [item])
                let result = NSCollectionLayoutSection(group: group)
                result.contentInsets = NSDirectionalEdgeInsets(top: 19, leading: 20, bottom: 0, trailing: 20)
                return result
            case .categories:
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(67)), subitems: [item])
                return NSCollectionLayoutSection(group: group)
            case .buddies:
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(176)), subitems: [item])
                let result = NSCollectionLayoutSection(group: group)
                result.interGroupSpacing = 20
                result.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 24, trailing: 20)
                return result
            }
        }
    }

    private func openAICoach() {
        let controller = RunQUIKitAIChatViewController(title: "AI COACH", dataStore: dataStore, sessionStore: sessionStore)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func openBuddyProfile(_ user: RunQUserRecord) {
        let controller = RunQUIKitOtherProfileViewController(
            title: "PROFILE",
            dataStore: dataStore,
            sessionStore: sessionStore,
            userID: user.id
        )
        navigationController?.pushViewController(controller, animated: true)
    }

    private func reloadBuddies() {
        let currentUserID = sessionStore.currentUser?.id
        allBuddies = dataStore.discoverableUsers(excluding: currentUserID).filter {
            guard let currentUserID else { return true }
            return dataStore.isUserVisible($0.id, to: currentUserID)
        }
        applyCategoryFilter()
    }

    private func selectCategory(_ category: RunQHomeCategory) {
        guard requireAccount() else {
            collectionView.reloadSections(
                IndexSet(integer: Section.categories.rawValue)
            )
            return
        }
        guard selectedCategory != category else { return }
        selectedCategory = category
        applyCategoryFilter()
    }

    private func applyCategoryFilter() {
        buddies = allBuddies.filter(selectedCategory.includes)
        collectionView.reloadSections(IndexSet(integer: Section.buddies.rawValue))
    }

    @discardableResult
    private func requireAccount() -> Bool {
        runQUIKitRequireAccount(
            from: self,
            dataStore: dataStore,
            sessionStore: sessionStore
        )
    }

    private func showInitialLoading() {
        guard loadingView == nil else { return }
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.36)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        overlay.addSubview(indicator)
        view.addSubview(overlay)
        overlay.snp.makeConstraints { make in make.edges.equalToSuperview() }
        indicator.snp.makeConstraints { make in make.center.equalToSuperview() }
        loadingView = overlay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.loadingView?.removeFromSuperview()
            self?.loadingView = nil
        }
    }

    private func showToast(_ message: String) {
        let label = RunQHomeInsetLabel()
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.backgroundColor = UIColor(white: 0.1, alpha: 0.94)
        label.layer.cornerRadius = 16
        label.clipsToBounds = true
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-24)
            make.leading.greaterThanOrEqualToSuperview().offset(28)
            make.trailing.lessThanOrEqualToSuperview().offset(-28)
        }
        UIView.animate(withDuration: 0.2, delay: 1.8, options: .curveEaseIn) {
            label.alpha = 0
        } completion: { _ in
            label.removeFromSuperview()
        }
    }
}

private final class RunQHomeInsetLabel: UILabel {
    private let insets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}

extension RunQUIKitHomeViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int { Section.allCases.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        return section == .buddies ? buddies.count : 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UICollectionViewCell() }
        switch section {
        case .coach:
            return collectionView.dequeueReusableCell(withReuseIdentifier: RunQHomeCoachCell.reuseIdentifier, for: indexPath)
        case .categories:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: RunQHomeCategoryStripCell.reuseIdentifier,
                for: indexPath
            ) as! RunQHomeCategoryStripCell
            cell.configure(selectedCategory: selectedCategory)
            cell.onSelection = { [weak self] category in
                self?.selectCategory(category)
            }
            return cell
        case .buddies:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RunQHomeBuddyCell.reuseIdentifier, for: indexPath) as! RunQHomeBuddyCell
            let buddy = buddies[indexPath.item]
            let post = dataStore.posts(
                for: buddy.id,
                visibleTo: sessionStore.currentUser?.id
            ).first
            cell.configure(user: buddy, likeCount: post?.likeCount ?? 0)
            cell.onAction = { [weak self] in
                guard let self, requireAccount() else { return }
                openBuddyProfile(buddy)
            }
            cell.onAvatar = { [weak self] in
                guard let self, requireAccount() else { return }
                openBuddyProfile(buddy)
            }
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else { return }
        switch section {
        case .coach:
            openAICoach()
        case .buddies:
            guard buddies.indices.contains(indexPath.item) else { return }
            openBuddyProfile(buddies[indexPath.item])
        case .categories:
            break
        }
    }
}

private final class RunQHomeCoachCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQHomeCoachCell"

    override init(frame: CGRect) {
        super.init(frame: frame)
        let imageView = UIImageView(image: UIImage(named: "runq_home_ai_coach_banner"))
        imageView.contentMode = .scaleToFill
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        accessibilityLabel = "Open AI Coach"
        isAccessibilityElement = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

private final class RunQHomeCategoryStripCell: UICollectionViewCell, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    static let reuseIdentifier = "RunQHomeCategoryStripCell"
    var onSelection: ((RunQHomeCategory) -> Void)?

    private let categories = RunQHomeCategory.allCases
    private let horizontalLayout = UICollectionViewFlowLayout()
    private lazy var categoryCollectionView = UICollectionView(frame: .zero, collectionViewLayout: horizontalLayout)
    private let trackView = UIView()
    private let indicatorView = UIImageView(image: UIImage(named: "runq_square_section_indicator"))
    private var selectedIndex = 0
    private var indicatorLeadingConstraint: Constraint?
    private var indicatorWidthConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        horizontalLayout.scrollDirection = .horizontal
        horizontalLayout.minimumLineSpacing = 28
        categoryCollectionView.backgroundColor = .clear
        categoryCollectionView.showsHorizontalScrollIndicator = false
        categoryCollectionView.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        categoryCollectionView.dataSource = self
        categoryCollectionView.delegate = self
        categoryCollectionView.register(RunQHomeCategoryCell.self, forCellWithReuseIdentifier: RunQHomeCategoryCell.reuseIdentifier)

        trackView.backgroundColor = UIColor.white.withAlphaComponent(0.28)
        indicatorView.contentMode = .scaleToFill
        contentView.addSubview(categoryCollectionView)
        contentView.addSubview(trackView)
        contentView.addSubview(indicatorView)
        categoryCollectionView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(29)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(34)
        }
        trackView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(2)
        }
        indicatorView.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.height.equalTo(3)
            indicatorLeadingConstraint = make.leading.equalToSuperview().offset(20).constraint
            indicatorWidthConstraint = make.width.equalTo(categoryWidth(at: selectedIndex)).constraint
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func prepareForReuse() {
        super.prepareForReuse()
        onSelection = nil
    }

    func configure(selectedCategory: RunQHomeCategory) {
        guard selectedIndex != selectedCategory.rawValue else { return }
        selectedIndex = selectedCategory.rawValue
        categoryCollectionView.reloadData()
        categoryCollectionView.layoutIfNeeded()
        updateIndicator(animated: false)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { categories.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RunQHomeCategoryCell.reuseIdentifier, for: indexPath) as! RunQHomeCategoryCell
        let category = categories[indexPath.item]
        cell.configure(title: category.title, iconAssetName: category.iconAssetName, isSelected: indexPath.item == selectedIndex)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: categoryWidth(at: indexPath.item), height: 32)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard selectedIndex != indexPath.item else { return }
        selectedIndex = indexPath.item
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
        updateIndicator(animated: true)
        onSelection?(categories[indexPath.item])
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === categoryCollectionView else { return }
        updateIndicator(animated: false)
    }

    private func categoryWidth(at index: Int) -> CGFloat {
        let category = categories[index]
        let font = index == selectedIndex
            ? AppFont.passionOne(size: 16, weight: .regular)
            : AppFont.barlow(size: 15)
        let textWidth = ceil((category.title as NSString).size(withAttributes: [.font: font]).width)
        return textWidth + (category.iconAssetName == nil ? 0 : 26)
    }

    private func updateIndicator(animated: Bool) {
        let indexPath = IndexPath(item: selectedIndex, section: 0)
        guard let attributes = horizontalLayout.layoutAttributesForItem(at: indexPath) else { return }
        indicatorLeadingConstraint?.update(offset: attributes.frame.minX - categoryCollectionView.contentOffset.x)
        indicatorWidthConstraint?.update(offset: categoryWidth(at: selectedIndex))
        let changes = { self.contentView.layoutIfNeeded() }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: changes)
        } else {
            changes()
        }
    }
}

private final class RunQHomeCategoryCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQHomeCategoryCell"
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        iconView.contentMode = .scaleAspectFit
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(title: String, iconAssetName: String?, isSelected: Bool) {
        titleLabel.text = title
        titleLabel.textColor = isSelected ? .white : UIColor.white.withAlphaComponent(0.72)
        titleLabel.font = isSelected
            ? AppFont.passionOne(size: 16, weight: .regular)
            : AppFont.barlow(size: 15)
        iconView.image = iconAssetName.flatMap(UIImage.init(named:))
        iconView.isHidden = iconAssetName == nil
        if iconAssetName != nil {
            iconView.snp.remakeConstraints { make in
                make.leading.centerY.equalToSuperview()
                make.size.equalTo(20)
            }
            titleLabel.snp.remakeConstraints { make in
                make.leading.equalTo(iconView.snp.trailing).offset(6)
                make.centerY.trailing.equalToSuperview()
            }
        } else {
            titleLabel.snp.remakeConstraints { make in make.edges.equalToSuperview() }
        }
    }
}

private final class RunQHomeBuddyCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQHomeBuddyCell"
    var onAction: (() -> Void)?
    var onAvatar: (() -> Void)?

    private let cardBackgroundView = UIImageView(image: UIImage(named: "runq_home_buddy_card_background"))
    private let photoView = UIImageView()
    private let titleLabel = UILabel()
    private let usernameLabel = UILabel()
    private let ageBadge = RunQHomeMetricBadge()
    private let medalView = UIImageView(image: UIImage(named: "runq_home_certification_medal"))
    private let certificationLabel = UILabel()
    private let likeBadge = UIView()
    private let likeIconView = UIImageView(image: UIImage(named: "runq_home_like_idle"))
    private let likeCountLabel = UILabel()
    private let actionButton = UIButton(type: .custom)
    private let avatarButton = UIButton(type: .custom)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViews()
        configureConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func prepareForReuse() {
        super.prepareForReuse()
        onAction = nil
        onAvatar = nil
    }

    func configure(user: RunQUserRecord, likeCount: Int) {
        photoView.image = UIImage(named: user.avatarAssetName)
        titleLabel.text = user.category.uppercased()
        usernameLabel.text = "@\(user.username.uppercased())"
        ageBadge.configure(
            iconAssetName: user.gender.lowercased() == "female"
                ? "runq_home_gender_female"
                : "runq_home_gender_male",
            text: "AGE \(user.age)"
        )
        certificationLabel.text = user.certificate
        likeCountLabel.text = "\(likeCount)"
    }

    private func configureViews() {
        cardBackgroundView.contentMode = .scaleToFill
        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.layer.cornerRadius = 28
        titleLabel.textColor = .white
        titleLabel.font = AppFont.passionOne(size: 20)
        usernameLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        usernameLabel.font = AppFont.barlow(size: 15)
        medalView.contentMode = .scaleAspectFit
        certificationLabel.text = "ACE American Council\non Exercise"
        certificationLabel.numberOfLines = 2
        certificationLabel.textColor = UIColor.white.withAlphaComponent(0.58)
        certificationLabel.font = AppFont.barlow(size: 12)
        likeBadge.backgroundColor = UIColor.black.withAlphaComponent(0.48)
        likeBadge.layer.cornerRadius = 16
        likeIconView.contentMode = .scaleAspectFit
        likeCountLabel.text = "108"
        likeCountLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        likeCountLabel.font = AppFont.barlow(size: 15)
        actionButton.setImage(UIImage(named: "runq_home_card_action"), for: .normal)
        actionButton.accessibilityLabel = "Open buddy profile"
        actionButton.addAction(UIAction { [weak self] _ in self?.onAction?() }, for: .touchUpInside)
        avatarButton.accessibilityLabel = "Open buddy profile"
        avatarButton.addAction(
            UIAction { [weak self] _ in self?.onAvatar?() },
            for: .touchUpInside
        )

        [cardBackgroundView, photoView, avatarButton, titleLabel, usernameLabel, ageBadge, medalView, certificationLabel, likeBadge, actionButton].forEach(contentView.addSubview)
        likeBadge.addSubview(likeIconView)
        likeBadge.addSubview(likeCountLabel)
    }

    private func configureConstraints() {
        cardBackgroundView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(164)
        }
        photoView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(121)
        }
        avatarButton.snp.makeConstraints { make in
            make.edges.equalTo(photoView)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(142)
            make.top.equalToSuperview().offset(30)
            make.trailing.lessThanOrEqualTo(actionButton.snp.leading).offset(-8)
        }
        usernameLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
        }
        ageBadge.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalToSuperview().offset(89)
            make.height.equalTo(28)
        }
        medalView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-7)
            make.size.equalTo(42)
        }
        certificationLabel.snp.makeConstraints { make in
            make.leading.equalTo(medalView.snp.trailing).offset(-2)
            make.centerY.equalTo(medalView)
            make.trailing.equalToSuperview().offset(-18)
        }
        likeBadge.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.bottom.equalToSuperview().offset(-12)
            make.width.equalTo(86)
            make.height.equalTo(32)
        }
        likeIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(2)
            make.centerY.equalToSuperview()
            make.size.equalTo(40)
        }
        likeCountLabel.snp.makeConstraints { make in
            make.leading.equalTo(likeIconView.snp.trailing).offset(6)
            make.centerY.equalToSuperview()
        }
        actionButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.trailing.equalToSuperview()
            make.size.equalTo(48)
        }
    }
}

private final class RunQHomeMetricBadge: UIView {
    private let iconView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white.withAlphaComponent(0.16)
        layer.cornerRadius = 14
        iconView.contentMode = .scaleAspectFit
        label.textColor = .white
        label.font = AppFont.barlow(size: 14)
        addSubview(iconView)
        addSubview(label)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
        label.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(5)
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(iconAssetName: String, text: String) {
        iconView.image = UIImage(named: iconAssetName)
        label.text = text
    }
}

import SnapKit
import UIKit

@MainActor
final class RunQUIKitBlacklistViewController: UIViewController {
    enum ConnectionCategory: Int, CaseIterable {
        case following
        case followers
        case blacklist

        var title: String {
            switch self {
            case .following: "FOLLOWING"
            case .followers: "FOLLOWERS"
            case .blacklist: "BLACKLIST"
            }
        }
    }

    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let includesBlacklist: Bool
    private let navigationHeader = UIView()
    private let categoryHeader = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let followingButton = UIButton(type: .custom)
    private let followersButton = UIButton(type: .custom)
    private let blacklistButton = UIButton(type: .custom)
    private let indicatorView = UIImageView(
        image: UIImage(named: "runq_square_section_indicator")
    )
    private var selectedCategory: ConnectionCategory
    private var profiles: [RunQUserRecord] = []

    init(
        initialCategory: ConnectionCategory,
        dataStore: RunQDataStore,
        sessionStore: CynosureSessionStore,
        includesBlacklist: Bool
    ) {
        selectedCategory = initialCategory
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        self.includesBlacklist = includesBlacklist
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .runQUIKitBackground
        configureNavigation()
        configureCategories()
        configureTable()
        reloadProfiles()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(socialDataDidChange),
            name: .runQSocialDataDidChange,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadProfiles()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }

    @objc private func socialDataDidChange() {
        reloadProfiles()
    }

    private func configureNavigation() {
        navigationHeader.backgroundColor = .clear
        view.addSubview(navigationHeader)
        navigationHeader.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(100)
        }

        let backButton = UIButton(type: .custom)
        backButton.setImage(
            UIImage(named: "runq_navigation_back")?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        backButton.accessibilityLabel = "Back"
        backButton.addAction(
            UIAction { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            },
            for: .touchUpInside
        )
        navigationHeader.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-6)
            make.size.equalTo(44)
        }

    }

    private func configureCategories() {
        categoryHeader.backgroundColor = UIColor.black.withAlphaComponent(0.06)
        view.addSubview(categoryHeader)
        categoryHeader.snp.makeConstraints { make in
            make.top.equalTo(navigationHeader.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(64)
        }

        configureCategoryButton(followingButton, category: .following)
        configureCategoryButton(followersButton, category: .followers)
        configureCategoryButton(blacklistButton, category: .blacklist)
        categoryHeader.addSubview(followingButton)
        categoryHeader.addSubview(followersButton)
        if includesBlacklist {
            categoryHeader.addSubview(blacklistButton)
        }

        followingButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(5)
            make.height.equalTo(38)
        }
        followersButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.height.equalTo(followingButton)
        }
        if includesBlacklist {
            blacklistButton.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-20)
                make.centerY.height.equalTo(followingButton)
            }
        }

        let trackView = UIView()
        trackView.backgroundColor = UIColor.white.withAlphaComponent(0.34)
        categoryHeader.addSubview(trackView)
        trackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().offset(-15)
            make.height.equalTo(2)
        }

        indicatorView.contentMode = .scaleToFill
        categoryHeader.addSubview(indicatorView)
        indicatorView.snp.makeConstraints { make in
            let button = categoryButton(for: selectedCategory)
            make.centerX.equalTo(button)
            make.width.equalTo(button.titleLabel!.snp.width)
            make.bottom.equalTo(trackView)
            make.height.equalTo(3)
        }
        updateCategoryAppearance()
    }

    private func configureCategoryButton(
        _ button: UIButton,
        category: ConnectionCategory
    ) {
        button.setTitle(category.title, for: .normal)
        button.tag = category.rawValue
        button.addAction(
            UIAction { [weak self] action in
                guard let sender = action.sender as? UIButton,
                      let category = ConnectionCategory(rawValue: sender.tag) else {
                    return
                }
                self?.selectCategory(category)
            },
            for: .touchUpInside
        )
    }

    private func configureTable() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            RunQBlacklistProfileCell.self,
            forCellReuseIdentifier: RunQBlacklistProfileCell.reuseIdentifier
        )
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(categoryHeader.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func selectCategory(_ category: ConnectionCategory) {
        guard selectedCategory != category else { return }
        selectedCategory = category
        updateCategoryAppearance()
        reloadProfiles()
        indicatorView.snp.remakeConstraints { make in
            let button = categoryButton(for: category)
            make.centerX.equalTo(button)
            make.width.equalTo(button.titleLabel!.snp.width)
            make.bottom.equalToSuperview().offset(-15)
            make.height.equalTo(3)
        }
        UIView.animate(withDuration: 0.2) {
            self.categoryHeader.layoutIfNeeded()
        }
    }

    private func updateCategoryAppearance() {
        let categories: [ConnectionCategory] = includesBlacklist
            ? ConnectionCategory.allCases
            : [.following, .followers]
        categories.forEach { category in
            let button = categoryButton(for: category)
            let isSelected = category == selectedCategory
            button.setTitleColor(
                isSelected ? .white : UIColor.white.withAlphaComponent(0.62),
                for: .normal
            )
            button.titleLabel?.font = AppFont.barlow(
                size: 15,
                weight: isSelected ? .semibold : .regular
            )
        }
    }

    private func categoryButton(for category: ConnectionCategory) -> UIButton {
        switch category {
        case .following: followingButton
        case .followers: followersButton
        case .blacklist: blacklistButton
        }
    }

    private func openProfile(_ profile: RunQUserRecord) {
        guard profile.id != sessionStore.currentUser?.id else { return }
        let page = RunQUIKitOtherProfileViewController(
            title: "PROFILE",
            dataStore: dataStore,
            sessionStore: sessionStore,
            userID: profile.id
        )
        navigationController?.pushViewController(page, animated: true)
    }

    private func performAction(at indexPath: IndexPath) {
        guard profiles.indices.contains(indexPath.row) else { return }
        let profile = profiles[indexPath.row]
        guard let currentUserID = sessionStore.currentUser?.id,
              currentUserID != profile.id else { return }
        do {
            switch selectedCategory {
            case .following:
                try dataStore.setFollowing(
                    sourceUserID: currentUserID,
                    targetUserID: profile.id,
                    isFollowing: false
                )
                showToast("Unfollowed.")
                reloadProfiles()
            case .followers:
                try dataStore.setFollowing(
                    sourceUserID: currentUserID,
                    targetUserID: profile.id,
                    isFollowing: true
                )
                reloadProfiles()
                showToast("Followed successfully.")
            case .blacklist:
                try dataStore.setBlocked(
                    sourceUserID: currentUserID,
                    targetUserID: profile.id,
                    isBlocked: false
                )
                showToast("Removed from blocked list.")
                reloadProfiles()
            }
        } catch {
            showToast("Unable to update this user.")
        }
    }

    private func reloadProfiles() {
        guard let currentUserID = sessionStore.currentUser?.id else {
            profiles = []
            tableView.reloadData()
            return
        }
        switch selectedCategory {
        case .following:
            profiles = dataStore.followingUsers(for: currentUserID)
        case .followers:
            profiles = dataStore.followerUsers(for: currentUserID)
        case .blacklist:
            profiles = dataStore.blockedUsers(for: currentUserID)
        }
        tableView.reloadData()
    }

    private func showToast(_ message: String) {
        RunQToastPresenter.show(message, on: navigationController?.view ?? view)
    }
}

extension RunQUIKitBlacklistViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        profiles.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        96
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RunQBlacklistProfileCell.reuseIdentifier,
            for: indexPath
        ) as! RunQBlacklistProfileCell
        let profile = profiles[indexPath.row]
        let isCurrentUser = profile.id == sessionStore.currentUser?.id
        let isAlreadyFollowing = sessionStore.currentUser.map {
            dataStore.isFollowing(
                sourceUserID: $0.id,
                targetUserID: profile.id
            )
        } ?? false
        let showsAction = !isCurrentUser
            && (selectedCategory != .followers || !isAlreadyFollowing)
        cell.configure(
            profile: profile,
            action: selectedCategory == .followers ? .follow : .remove,
            showsAction: showsAction
        )
        if showsAction {
            cell.onAction = { [weak self, weak cell] in
                guard let self, let cell,
                      let currentIndexPath = tableView.indexPath(for: cell) else {
                    return
                }
                performAction(at: currentIndexPath)
            }
        } else {
            cell.onAction = nil
        }
        cell.onAvatar = { [weak self] in self?.openProfile(profile) }
        return cell
    }
}

private final class RunQBlacklistProfileCell: UITableViewCell {
    enum Action {
        case remove
        case follow
    }

    static let reuseIdentifier = "RunQBlacklistProfileCell"
    var onAction: (() -> Void)?
    var onAvatar: (() -> Void)?
    private let nameLabel = UILabel()
    private let avatarView = UIImageView()
    private let genderView = UIImageView()
    private let ageLabel = UILabel()
    private let actionButton = UIButton(type: .custom)
    private let avatarButton = UIButton(type: .custom)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        let cardView = UIView()
        cardView.backgroundColor = UIColor(
            red: 48 / 255,
            green: 48 / 255,
            blue: 52 / 255,
            alpha: 1
        )
        cardView.layer.cornerRadius = 16
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(80)
        }

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 12
        cardView.addSubview(avatarView)
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.size.equalTo(40)
        }
        avatarButton.accessibilityLabel = "Open user profile"
        avatarButton.addAction(
            UIAction { [weak self] _ in self?.onAvatar?() },
            for: .touchUpInside
        )
        cardView.addSubview(avatarButton)
        avatarButton.snp.makeConstraints { make in make.edges.equalTo(avatarView) }

        nameLabel.textColor = .white
        nameLabel.font = AppFont.barlow(size: 14)
        cardView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(16)
            make.top.equalToSuperview().offset(15)
        }

        let ageBadge = metricBadge(iconView: genderView, label: ageLabel)
        cardView.addSubview(ageBadge)
        ageBadge.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.bottom.equalToSuperview().offset(-13)
            make.width.equalTo(80)
            make.height.equalTo(28)
        }

        actionButton.addAction(
            UIAction { [weak self] _ in self?.onAction?() },
            for: .touchUpInside
        )
        cardView.addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.size.equalTo(40)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onAction = nil
        onAvatar = nil
    }

    func configure(
        profile: RunQUserRecord,
        action: Action,
        showsAction: Bool
    ) {
        nameLabel.text = profile.username.uppercased()
        avatarView.image = UIImage(named: profile.avatarAssetName)
            ?? UIImage(named: "runq_square_buddy_avatar")
        genderView.image = UIImage(
            named: profile.gender.lowercased() == "female"
                ? "runq_home_gender_female"
                : "runq_home_gender_male"
        )
        ageLabel.text = "AGE \(profile.age)"
        actionButton.isHidden = !showsAction
        actionButton.isUserInteractionEnabled = showsAction
        switch action {
        case .remove:
            actionButton.setImage(
                UIImage(named: "runq_cinnabar_unfollow")?
                    .withRenderingMode(.alwaysOriginal),
                for: .normal
            )
            actionButton.tintColor = nil
            actionButton.accessibilityLabel = "Remove"
        case .follow:
            actionButton.setImage(
                UIImage(named: "runq_other_profile_follow_add")?
                    .withRenderingMode(.alwaysOriginal),
                for: .normal
            )
            actionButton.tintColor = nil
            actionButton.accessibilityLabel = "Follow"
        }
    }

    private func metricBadge(iconName: String, text: String) -> UIView {
        let badge = UIView()
        badge.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        badge.layer.cornerRadius = 14
        let iconView = UIImageView(image: UIImage(named: iconName))
        iconView.contentMode = .scaleAspectFit
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = AppFont.barlow(size: 13)
        badge.addSubview(iconView)
        badge.addSubview(label)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
        label.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(5)
            make.centerY.equalToSuperview()
        }
        return badge
    }

    private func metricBadge(iconView: UIImageView, label: UILabel) -> UIView {
        let badge = UIView()
        badge.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        badge.layer.cornerRadius = 14
        iconView.contentMode = .scaleAspectFit
        label.textColor = .white
        label.font = AppFont.barlow(size: 13)
        badge.addSubview(iconView)
        badge.addSubview(label)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
        label.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(5)
            make.centerY.equalToSuperview()
        }
        return badge
    }
}

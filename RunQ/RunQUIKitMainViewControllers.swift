import SnapKit
import UIKit

@MainActor
private enum RunQUIKitPageStyle {
    static let background = UIColor(red: 16 / 255, green: 16 / 255, blue: 15 / 255, alpha: 1)
    static let card = UIColor(red: 55 / 255, green: 55 / 255, blue: 61 / 255, alpha: 1)
    static let orange = UIColor(red: 1, green: 0.30, blue: 0.07, alpha: 1)
}

@MainActor
private func runQUIKitTitle(_ text: String, size: CGFloat = 28) -> UILabel {
    let label = UILabel()
    label.text = text
    label.textColor = .white
    label.font = UIFont(name: "PassionOne-Bold", size: size) ?? .boldSystemFont(ofSize: size)
    return label
}

@MainActor
class RunQUIKitScrollableViewController: UIViewController {
    let scrollView = UIScrollView()
    let content = UIStackView()
    private let navigationHeader = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = RunQUIKitPageStyle.background
        RunQAuroralTabBackdrop.install(in: view)
        navigationHeader.backgroundColor = .clear
        navigationHeader.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationHeader)
        view.addSubview(scrollView)
        scrollView.addSubview(content)
        NSLayoutConstraint.activate([
            navigationHeader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationHeader.heightAnchor.constraint(equalToConstant: 56),
            scrollView.topAnchor.constraint(equalTo: navigationHeader.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    func addHeader(_ title: String, trailing: UIButton? = nil) {
        let label = runQUIKitTitle(title)
        label.translatesAutoresizingMaskIntoConstraints = false
        navigationHeader.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: navigationHeader.leadingAnchor, constant: 20),
            label.centerYAnchor.constraint(equalTo: navigationHeader.centerYAnchor)
        ])
        if let trailing {
            trailing.translatesAutoresizingMaskIntoConstraints = false
            navigationHeader.addSubview(trailing)
            NSLayoutConstraint.activate([
                trailing.trailingAnchor.constraint(equalTo: navigationHeader.trailingAnchor, constant: -20),
                trailing.centerYAnchor.constraint(equalTo: label.centerYAnchor),
                trailing.widthAnchor.constraint(equalToConstant: 44),
                trailing.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
    }

    func card(title: String, subtitle: String? = nil, imageName: String? = nil) -> UIView {
        let card = UIView()
        card.backgroundColor = RunQUIKitPageStyle.card
        card.layer.cornerRadius = 28
        card.clipsToBounds = true
        card.heightAnchor.constraint(equalToConstant: 151).isActive = true
        let titleLabel = runQUIKitTitle(title, size: 20)
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18)
        ])
        if let imageName, let image = UIImage(named: imageName) {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.layer.cornerRadius = 12
            imageView.clipsToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
                imageView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
                imageView.widthAnchor.constraint(equalToConstant: 58),
                imageView.heightAnchor.constraint(equalToConstant: 58)
            ])
        }
        if let subtitle {
            let label = runQUIKitLabel(subtitle, size: 13)
            label.textColor = UIColor.white.withAlphaComponent(0.72)
            label.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
                label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
            ])
        }
        return card
    }
}

@MainActor
private final class RunQUIKitLegacyReelViewController: UIViewController {
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let likeButton = UIButton(type: .custom)
    private let likeCountLabel = runQUIKitLabel("0", size: 13)
    private var isLiked = false
    private var baseLikeCount = 0

    init(dataStore: RunQDataStore, sessionStore: CynosureSessionStore) {
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let currentUserID = sessionStore.currentUser?.id
        let visiblePosts = dataStore.feedPosts(visibleTo: currentUserID)
        let post = visiblePosts.first(where: { $0.authorID != currentUserID })
            ?? visiblePosts.first
        let author = post.flatMap { dataStore.user(id: $0.authorID) }

        let sceneView = UIImageView(image: UIImage(named: "runq_peregrine_reel_scene"))
        sceneView.contentMode = .scaleAspectFill
        sceneView.clipsToBounds = true

        let topVeil = UIImageView(image: UIImage(named: "runq_umbriferous_reel_top_veil"))
        topVeil.contentMode = .scaleToFill

        let bottomVeil = UIImageView(image: UIImage(named: "runq_vespertine_reel_bottom_veil"))
        bottomVeil.contentMode = .scaleToFill

        let nearbyLabel = runQUIKitLabel("NEARBY", size: 15)
        nearbyLabel.textColor = UIColor.white.withAlphaComponent(0.62)
        let recommendLabel = runQUIKitLabel("RECOMMEND", size: 15, weight: .medium)
        let categoryStack = UIStackView(arrangedSubviews: [nearbyLabel, recommendLabel])
        categoryStack.axis = .horizontal
        categoryStack.spacing = 25
        categoryStack.alignment = .center

        let reportButton = UIButton(type: .custom)
        reportButton.setImage(UIImage(named: "runq_square_report"), for: .normal)
        reportButton.accessibilityLabel = "More"
        let canReport = post.map { $0.authorID != currentUserID } ?? false
        reportButton.isHidden = !canReport
        reportButton.isUserInteractionEnabled = canReport
        if canReport, let post {
            reportButton.addAction(UIAction { [weak self] _ in
                guard let self,
                      post.authorID != self.sessionStore.currentUser?.id else {
                    return
                }
                let dialog = RunQUIKitReportViewController()
                dialog.modalPresentationStyle = .overFullScreen
                self.present(dialog, animated: true)
            }, for: .touchUpInside)
        }

        baseLikeCount = post?.likeCount ?? 13
        likeButton.setImage(UIImage(named: "runq_home_like_idle"), for: .normal)
        likeButton.accessibilityLabel = "Like"
        likeButton.addAction(UIAction { [weak self] _ in
            self?.toggleLike()
        }, for: .touchUpInside)
        likeCountLabel.text = "\(baseLikeCount)"
        likeCountLabel.textAlignment = .center

        let commentButton = UIButton(type: .custom)
        commentButton.setImage(UIImage(named: "runq_square_comment"), for: .normal)
        commentButton.accessibilityLabel = "Comments"
        let commentCountLabel = runQUIKitLabel("\(post?.commentCount ?? 13)", size: 13)
        commentCountLabel.textAlignment = .center

        let actionStack = UIStackView(arrangedSubviews: [
            reelAction(button: likeButton, countLabel: likeCountLabel),
            reelAction(button: commentButton, countLabel: commentCountLabel)
        ])
        actionStack.axis = .vertical
        actionStack.spacing = 24
        actionStack.alignment = .center

        let avatarView = UIImageView(
            image: UIImage(named: author?.avatarAssetName ?? "runq_square_author_avatar")
        )
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 30
        avatarView.layer.borderWidth = 1
        avatarView.layer.borderColor = UIColor.white.cgColor

        let followButton = UIButton(type: .custom)
        followButton.setImage(UIImage(named: "runq_solaris_reel_follow"), for: .normal)
        followButton.accessibilityLabel = "Follow"

        let usernameLabel = runQUIKitLabel(
            "@\((author?.username ?? post?.authorName ?? "LUNA").uppercased())",
            size: 14
        )
        let profileStack = UIStackView(arrangedSubviews: [avatarView, usernameLabel])
        profileStack.axis = .horizontal
        profileStack.spacing = 24
        profileStack.alignment = .center

        let captionLabel = runQUIKitLabel(
            post?.text ?? "Sharing epic rock climbing adventures with my bestie at Joshua Tree National Park! 🧗✨",
            size: 14
        )
        captionLabel.textColor = UIColor.white.withAlphaComponent(0.68)
        captionLabel.numberOfLines = 2

        [sceneView, topVeil, bottomVeil, categoryStack, reportButton,
         actionStack, profileStack, followButton, captionLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            topVeil.topAnchor.constraint(equalTo: view.topAnchor),
            topVeil.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topVeil.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topVeil.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 136.0 / 375.0),

            bottomVeil.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomVeil.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomVeil.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomVeil.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 98.0 / 375.0),

            categoryStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            categoryStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            reportButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            reportButton.centerYAnchor.constraint(equalTo: categoryStack.centerYAnchor),
            reportButton.widthAnchor.constraint(equalToConstant: 44),
            reportButton.heightAnchor.constraint(equalToConstant: 44),

            actionStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            actionStack.bottomAnchor.constraint(equalTo: profileStack.topAnchor, constant: -42),

            avatarView.widthAnchor.constraint(equalToConstant: 60),
            avatarView.heightAnchor.constraint(equalToConstant: 60),
            profileStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            profileStack.bottomAnchor.constraint(equalTo: captionLabel.topAnchor, constant: -12),

            followButton.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            followButton.centerYAnchor.constraint(equalTo: avatarView.bottomAnchor),
            followButton.widthAnchor.constraint(equalToConstant: 24),
            followButton.heightAnchor.constraint(equalToConstant: 24),

            captionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            captionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            captionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -72)
        ])
    }

    private func reelAction(
        button: UIButton,
        countLabel: UILabel
    ) -> UIView {
        let container = UIView()
        button.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)
        container.addSubview(countLabel)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            button.widthAnchor.constraint(equalToConstant: 48),
            button.heightAnchor.constraint(equalToConstant: 48),
            countLabel.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 2),
            countLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            countLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            countLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.widthAnchor.constraint(equalToConstant: 52)
        ])
        return container
    }

    private func toggleLike() {
        isLiked.toggle()
        likeButton.setImage(
            UIImage(named: isLiked ? "runq_home_like_selected" : "runq_home_like_idle"),
            for: .normal
        )
        likeCountLabel.text = "\(baseLikeCount + (isLiked ? 1 : 0))"
    }
}

@MainActor
final class RunQUIKitProfileViewController: UIViewController {
    private enum FeedSelection {
        case posts
        case likes
    }

    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = runQUIKitLabel("", size: 16, weight: .medium)
    private let idLabel = runQUIKitLabel("", size: 13)
    private let biographyLabel = runQUIKitLabel("", size: 14)
    private let followersCountLabel = runQUIKitLabel("0", size: 24, weight: .bold)
    private let followingCountLabel = runQUIKitLabel("0", size: 24, weight: .bold)
    private let walletCountLabel = runQUIKitLabel("0", size: 20, weight: .bold)
    private let itineraryStack = UIStackView()
    private let itineraryCard = UIView()
    private let itineraryTimeline = UIView()
    private let postTabButton = UIButton(type: .custom)
    private let likeTabButton = UIButton(type: .custom)
    private let tabIndicator = UIImageView(
        image: UIImage(named: "runq_square_section_indicator")
    )
    private let postListView = RunQProfilePostListView()
    private var feedChromeViews: [UIView] = []
    private var itineraryHeightConstraint: NSLayoutConstraint!
    private var postListHeightConstraint: NSLayoutConstraint!
    private var tabIndicatorLeadingConstraint: NSLayoutConstraint!
    private var selectedFeed: FeedSelection = .posts

    init(dataStore: RunQDataStore, sessionStore: CynosureSessionStore) {
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        reloadProfile()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(walletBalanceChanged(_:)),
            name: .runQWalletBalanceDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(socialDataDidChange),
            name: .runQSocialDataDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itineraryDidChange(_:)),
            name: .runQItinerariesDidChange,
            object: dataStore
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadProfile()
    }

    @objc private func socialDataDidChange() {
        reloadProfile()
    }

    @objc private func itineraryDidChange(_ notification: Notification) {
        guard let changedUserID = notification.userInfo?["userID"] as? String,
              changedUserID == sessionStore.currentUser?.id else { return }
        reloadItinerary(userID: changedUserID)
        view.layoutIfNeeded()
    }

    private func configureView() {
        view.backgroundColor = .runQUIKitBackground
        RunQAuroralTabBackdrop.install(in: view)
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 42
        avatarView.layer.borderWidth = 1.5
        avatarView.layer.borderColor = UIColor.white.cgColor

        let editButton = UIButton(type: .custom)
        editButton.setImage(UIImage(named: "runq_palimpsest_profile_edit"), for: .normal)
        editButton.accessibilityLabel = "Edit profile"
        editButton.addAction(UIAction { [weak self] _ in self?.openEditProfile() }, for: .touchUpInside)

        let settingsButton = UIButton(type: .custom)
        settingsButton.setImage(UIImage(named: "runq_claviger_profile_settings"), for: .normal)
        settingsButton.accessibilityLabel = "Settings"
        settingsButton.addAction(UIAction { [weak self] _ in self?.openSettings() }, for: .touchUpInside)

        idLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        biographyLabel.textColor = UIColor.white.withAlphaComponent(0.68)
        biographyLabel.numberOfLines = 2

        let followersTitle = profileCaption("Followers")
        let followingTitle = profileCaption("Following")
        let followersStack = profileMetric(value: followersCountLabel, title: followersTitle)
        let followingStack = profileMetric(value: followingCountLabel, title: followingTitle)
        followersStack.isUserInteractionEnabled = true
        followersStack.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(openFollowersList)
            )
        )
        followingStack.isUserInteractionEnabled = true
        followingStack.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(openFollowingList)
            )
        )

        let walletBackdrop = UIImageView(image: UIImage(named: "runq_cinnabar_profile_balance_plinth"))
        walletBackdrop.contentMode = .scaleToFill
        walletBackdrop.isUserInteractionEnabled = true
        walletBackdrop.accessibilityLabel = "Coin balance"
        let coinView = UIImageView(image: UIImage(named: "runq_chrysus_profile_coin"))
        coinView.contentMode = .scaleAspectFit
        let walletArrow = UIImageView(image: UIImage(named: "runq_vector_continue_glyph"))
        walletArrow.contentMode = .scaleAspectFit
        [coinView, walletCountLabel, walletArrow].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            walletBackdrop.addSubview($0)
        }
        let walletTap = UITapGestureRecognizer(target: self, action: #selector(openWallet))
        walletBackdrop.addGestureRecognizer(walletTap)

        itineraryCard.backgroundColor = UIColor(red: 48 / 255, green: 48 / 255, blue: 52 / 255, alpha: 1)
        itineraryCard.layer.cornerRadius = 28
        itineraryCard.clipsToBounds = true
        let itineraryIcon = UIImageView(image: UIImage(named: "runq_periplus_profile_itinerary"))
        itineraryIcon.contentMode = .scaleAspectFit
        let itineraryTitle = runQUIKitLabel("ITINERARY", size: 13)
        itineraryStack.axis = .vertical
        itineraryStack.spacing = 10
        itineraryStack.alignment = .fill
        itineraryTimeline.backgroundColor = UIColor(
            red: 39 / 255,
            green: 236 / 255,
            blue: 197 / 255,
            alpha: 0.72
        )
        [itineraryIcon, itineraryTitle, itineraryTimeline, itineraryStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            itineraryCard.addSubview($0)
        }

        let postTabIcon = UIImageView(image: UIImage(named: "runq_square_section_mark"))
        postTabIcon.contentMode = .scaleAspectFit
        configureFeedButton(postTabButton, title: "POST")
        configureFeedButton(likeTabButton, title: "LIKE")
        postTabButton.addAction(
            UIAction { [weak self] _ in self?.selectFeed(.posts) },
            for: .touchUpInside
        )
        likeTabButton.addAction(
            UIAction { [weak self] _ in self?.selectFeed(.likes) },
            for: .touchUpInside
        )
        let tabStack = UIStackView(
            arrangedSubviews: [postTabIcon, postTabButton, likeTabButton]
        )
        tabStack.axis = .horizontal
        tabStack.spacing = 8
        tabStack.alignment = .center
        tabStack.setCustomSpacing(29, after: postTabButton)
        let tabLine = UIView()
        tabLine.backgroundColor = UIColor.white.withAlphaComponent(0.32)
        tabIndicator.contentMode = .scaleToFill
        feedChromeViews = [postTabIcon, tabStack, tabLine, tabIndicator]
        configurePostListActions()

        [scrollView, contentView, avatarView, editButton, settingsButton,
         nameLabel, idLabel, biographyLabel, followersStack, followingStack,
         walletBackdrop, itineraryCard, tabStack, tabLine, tabIndicator,
         postListView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        [avatarView, editButton, settingsButton, nameLabel, idLabel,
         biographyLabel, followersStack, followingStack, walletBackdrop,
         itineraryCard, tabStack, tabLine, tabIndicator, postListView].forEach {
            contentView.addSubview($0)
        }

        itineraryHeightConstraint = itineraryCard.heightAnchor.constraint(equalToConstant: 158)
        postListHeightConstraint = postListView.heightAnchor.constraint(equalToConstant: 96)
        tabIndicatorLeadingConstraint = tabIndicator.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: 20
        )
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor
            ),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 69),
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            avatarView.widthAnchor.constraint(equalToConstant: 84),
            avatarView.heightAnchor.constraint(equalToConstant: 84),
            editButton.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            editButton.centerYAnchor.constraint(equalTo: avatarView.bottomAnchor),
            editButton.widthAnchor.constraint(equalToConstant: 36),
            editButton.heightAnchor.constraint(equalToConstant: 36),
            settingsButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 67),
            settingsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            settingsButton.widthAnchor.constraint(equalToConstant: 34),
            settingsButton.heightAnchor.constraint(equalToConstant: 34),
            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 20),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 93),
            idLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            idLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 5),
            biographyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 192),
            biographyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            biographyLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            followersStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 250),
            followersStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            followersStack.widthAnchor.constraint(equalToConstant: 72),
            followingStack.topAnchor.constraint(equalTo: followersStack.topAnchor),
            followingStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 111),
            followingStack.widthAnchor.constraint(equalToConstant: 72),
            walletBackdrop.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 247),
            walletBackdrop.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 200),
            walletBackdrop.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            walletBackdrop.heightAnchor.constraint(equalToConstant: 52),
            coinView.leadingAnchor.constraint(equalTo: walletBackdrop.leadingAnchor, constant: -4),
            coinView.centerYAnchor.constraint(equalTo: walletBackdrop.centerYAnchor),
            coinView.widthAnchor.constraint(equalToConstant: 64),
            coinView.heightAnchor.constraint(equalToConstant: 64),
            walletCountLabel.centerXAnchor.constraint(equalTo: walletBackdrop.centerXAnchor, constant: 16),
            walletCountLabel.centerYAnchor.constraint(equalTo: walletBackdrop.centerYAnchor),
            walletArrow.trailingAnchor.constraint(equalTo: walletBackdrop.trailingAnchor, constant: 7),
            walletArrow.centerYAnchor.constraint(equalTo: walletBackdrop.centerYAnchor),
            walletArrow.widthAnchor.constraint(equalToConstant: 24),
            walletArrow.heightAnchor.constraint(equalToConstant: 24),
            itineraryCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 320),
            itineraryCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            itineraryCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            itineraryHeightConstraint,
            itineraryIcon.leadingAnchor.constraint(equalTo: itineraryCard.leadingAnchor, constant: 16),
            itineraryIcon.topAnchor.constraint(equalTo: itineraryCard.topAnchor, constant: 15),
            itineraryIcon.widthAnchor.constraint(equalToConstant: 24),
            itineraryIcon.heightAnchor.constraint(equalToConstant: 24),
            itineraryTitle.leadingAnchor.constraint(equalTo: itineraryIcon.trailingAnchor, constant: 12),
            itineraryTitle.centerYAnchor.constraint(equalTo: itineraryIcon.centerYAnchor),
            itineraryStack.topAnchor.constraint(equalTo: itineraryCard.topAnchor, constant: 54),
            itineraryStack.leadingAnchor.constraint(equalTo: itineraryCard.leadingAnchor, constant: 20),
            itineraryStack.trailingAnchor.constraint(equalTo: itineraryCard.trailingAnchor, constant: -18),
            itineraryTimeline.topAnchor.constraint(equalTo: itineraryCard.topAnchor, constant: 62),
            itineraryTimeline.leadingAnchor.constraint(equalTo: itineraryCard.leadingAnchor, constant: 27),
            itineraryTimeline.bottomAnchor.constraint(equalTo: itineraryCard.bottomAnchor, constant: -31),
            itineraryTimeline.widthAnchor.constraint(equalToConstant: 1),
            tabStack.topAnchor.constraint(equalTo: itineraryCard.bottomAnchor, constant: 27),
            tabStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            postTabIcon.widthAnchor.constraint(equalToConstant: 20),
            postTabIcon.heightAnchor.constraint(equalToConstant: 20),
            tabLine.topAnchor.constraint(equalTo: tabStack.bottomAnchor, constant: 12),
            tabLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tabLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tabLine.heightAnchor.constraint(equalToConstant: 1),
            tabIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tabIndicator.centerYAnchor.constraint(equalTo: tabLine.centerYAnchor),
            tabIndicator.widthAnchor.constraint(equalToConstant: 80),
            tabIndicator.heightAnchor.constraint(equalToConstant: 3),
            tabIndicatorLeadingConstraint,
            postListView.topAnchor.constraint(equalTo: tabLine.bottomAnchor, constant: 24),
            postListView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            postListView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            postListHeightConstraint,
            postListView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func profileCaption(_ text: String) -> UILabel {
        let label = runQUIKitLabel(text, size: 13)
        label.textColor = UIColor.white.withAlphaComponent(0.55)
        label.textAlignment = .left
        return label
    }

    private func profileMetric(value: UILabel, title: UILabel) -> UIStackView {
        value.textAlignment = .left
        let stack = UIStackView(arrangedSubviews: [value, title])
        stack.axis = .vertical
        stack.spacing = 1
        stack.alignment = .leading
        return stack
    }

    private func reloadProfile() {
        guard let user = sessionStore.currentUser else { return }
        sessionStore.refreshCurrentUser()
        let refreshedUser = sessionStore.currentUser ?? user
        let details = dataStore.profileDetails(for: refreshedUser.id)
        if let avatarData = details.avatarData, let image = UIImage(data: avatarData) {
            avatarView.image = image
        } else {
            avatarView.image = UIImage(named: refreshedUser.avatarAssetName)
        }
        nameLabel.text = refreshedUser.username
        idLabel.text = "ID: \(profileDisplayID(from: refreshedUser.id))"
        biographyLabel.text = refreshedUser.biography.isEmpty
            ? "Complete your profile to help buddies find you."
            : refreshedUser.biography
        followersCountLabel.text = "\(dataStore.followerUsers(for: refreshedUser.id).count)"
        followingCountLabel.text = "\(dataStore.followingUsers(for: refreshedUser.id).count)"
        let walletBalance = (try? RunQChrysalBalanceVault.shared.balance(
            userID: refreshedUser.id
        )) ?? 0
        walletCountLabel.text = "\(walletBalance)"
        reloadItinerary(userID: refreshedUser.id)
        reloadSelectedFeed(userID: refreshedUser.id)
    }

    @objc private func walletBalanceChanged(_ notification: Notification) {
        guard let changedUserID = notification.userInfo?["userID"] as? String,
              changedUserID == sessionStore.currentUser?.id else { return }
        if let updatedBalance = notification.userInfo?["balance"] as? Int {
            walletCountLabel.text = "\(updatedBalance)"
        } else {
            let walletBalance = (try? RunQChrysalBalanceVault.shared.balance(
                userID: changedUserID
            )) ?? 0
            walletCountLabel.text = "\(walletBalance)"
        }
    }

    private func reloadItinerary(userID: String) {
        itineraryStack.arrangedSubviews.forEach {
            itineraryStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let entries = dataStore.itineraries(for: userID)
        itineraryCard.isHidden = entries.isEmpty
        for entry in entries {
            let dot = UIView()
            dot.backgroundColor = UIColor(red: 39 / 255, green: 236 / 255, blue: 197 / 255, alpha: 1)
            dot.layer.cornerRadius = 6
            dot.translatesAutoresizingMaskIntoConstraints = false
            let dateLabel = profileCaption(entry.dateText)
            let detailsLabel = runQUIKitLabel(entry.details, size: 13)
            detailsLabel.numberOfLines = 2
            let row = UIStackView(arrangedSubviews: [dot, dateLabel, detailsLabel])
            row.axis = .horizontal
            row.spacing = 12
            row.alignment = .top
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 12),
                dot.heightAnchor.constraint(equalToConstant: 12),
                dateLabel.widthAnchor.constraint(equalToConstant: 56),
                row.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
            ])
            itineraryStack.addArrangedSubview(row)
        }
        itineraryHeightConstraint.constant = entries.isEmpty
            ? 0
            : max(158, 60 + CGFloat(entries.count) * 42)
    }

    private func configureFeedButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = AppFont.barlow(size: 16, weight: .medium)
        button.contentEdgeInsets = .zero
        button.accessibilityLabel = title.capitalized
    }

    private func selectFeed(_ selection: FeedSelection) {
        guard selectedFeed != selection else { return }
        selectedFeed = selection
        guard let userID = sessionStore.currentUser?.id else { return }
        reloadSelectedFeed(userID: userID)
        updateFeedSelection(animated: true)
    }

    private func reloadSelectedFeed(userID: String) {
        let publishedPosts = dataStore.posts(
            for: userID,
            visibleTo: sessionStore.currentUser?.id
        )
        let showsPostSection = !publishedPosts.isEmpty
        feedChromeViews.forEach { $0.isHidden = !showsPostSection }
        guard showsPostSection else {
            postListView.isHidden = true
            postListHeightConstraint.constant = 0
            return
        }

        let selectedPosts: [RunQPostRecord]
        let emptyMessage: String
        switch selectedFeed {
        case .posts:
            selectedPosts = publishedPosts
            emptyMessage = "No posts yet."
        case .likes:
            selectedPosts = dataStore.likedPosts(
                by: userID,
                visibleTo: sessionStore.currentUser?.id
            )
            emptyMessage = "No liked posts yet."
        }
        postListView.update(
            posts: selectedPosts,
            currentUserID: sessionStore.currentUser?.id,
            emptyMessage: emptyMessage,
            displaysLikedState: selectedFeed == .likes
        )
        postListView.isHidden = selectedPosts.isEmpty
        postListHeightConstraint.constant = selectedPosts.isEmpty
            ? 0
            : postListView.requiredHeight
        updateFeedSelection(animated: false)
    }

    private func updateFeedSelection(animated: Bool) {
        postTabButton.setTitleColor(
            selectedFeed == .posts ? .white : UIColor.white.withAlphaComponent(0.58),
            for: .normal
        )
        likeTabButton.setTitleColor(
            selectedFeed == .likes ? .white : UIColor.white.withAlphaComponent(0.58),
            for: .normal
        )
        view.layoutIfNeeded()
        tabIndicatorLeadingConstraint.constant = selectedFeed == .posts
            ? 20
            : likeTabButton.convert(.zero, to: contentView).x - 16
        let changes = { self.view.layoutIfNeeded() }
        if animated {
            UIView.animate(withDuration: 0.2, animations: changes)
        } else {
            changes()
        }
    }

    private func configurePostListActions() {
        postListView.onOpenPost = { [weak self] post in
            self?.openPost(post)
        }
        postListView.onOpenAuthor = { [weak self] userID in
            self?.openAuthor(userID)
        }
        postListView.onReportPost = { [weak self] post in
            self?.showReport(for: post)
        }
        postListView.onSharePost = { [weak self] _ in
            self?.openPublisher()
        }
    }

    private func openPost(_ post: RunQPostRecord) {
        navigationController?.pushViewController(
            RunQUIKitActivityDetailViewController(
                post: post,
                dataStore: dataStore,
                sessionStore: sessionStore
            ),
            animated: true
        )
    }

    private func openAuthor(_ userID: String) {
        guard userID != sessionStore.currentUser?.id,
              dataStore.isUserVisible(userID, to: sessionStore.currentUser?.id),
              dataStore.user(id: userID) != nil else { return }
        navigationController?.pushViewController(
            RunQUIKitOtherProfileViewController(
                title: "PROFILE",
                dataStore: dataStore,
                sessionStore: sessionStore,
                userID: userID
            ),
            animated: true
        )
    }

    private func openPublisher() {
        navigationController?.pushViewController(
            RunQUIKitPublishViewController(
                dataStore: dataStore,
                sessionStore: sessionStore
            ),
            animated: true
        )
    }

    private func showReport(for post: RunQPostRecord) {
        guard let currentUserID = sessionStore.currentUser?.id,
              post.authorID != currentUserID else { return }
        let dialog = RunQUIKitReportViewController()
        dialog.modalPresentationStyle = .overFullScreen
        dialog.onBlock = { [weak self] in
            guard let self else { return }
            do {
                try dataStore.setBlocked(
                    sourceUserID: currentUserID,
                    targetUserID: post.authorID,
                    isBlocked: true
                )
                RunQToastPresenter.show(
                    "Added to blocked list.",
                    on: navigationController?.view ?? view
                )
            } catch {
                RunQToastPresenter.show(
                    "Unable to block this user.",
                    on: navigationController?.view ?? view
                )
            }
        }
        present(dialog, animated: true)
    }

    private func openEditProfile() {
        let page = RunQUIKitEditProfileViewController(
            title: "EDIT PROFILE",
            dataStore: dataStore,
            sessionStore: sessionStore
        )
        page.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(page, animated: true)
    }

    private func openSettings() {
        let page = RunQUIKitSettingsViewController(
            dataStore: dataStore,
            sessionStore: sessionStore
        )
        page.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(page, animated: true)
    }

    @objc
    private func openFollowersList() {
        openConnections(initialCategory: .followers)
    }

    @objc
    private func openFollowingList() {
        openConnections(initialCategory: .following)
    }

    private func openConnections(
        initialCategory: RunQUIKitBlacklistViewController.ConnectionCategory
    ) {
        let page = RunQUIKitBlacklistViewController(
            initialCategory: initialCategory,
            dataStore: dataStore,
            sessionStore: sessionStore,
            includesBlacklist: true
        )
        navigationController?.pushViewController(page, animated: true)
    }

    @objc
    private func openWallet() {
        let page = RunQUIKitWalletViewController(
            title: "WALLET",
            dataStore: dataStore,
            sessionStore: sessionStore
        )
        page.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(page, animated: true)
    }

    private func profileDisplayID(from id: String) -> String {
        let digits = id.unicodeScalars.reduce(into: UInt64(0)) { result, scalar in
            result = (result &* 31 &+ UInt64(scalar.value)) % 10_000_000_000
        }
        return String(format: "%010llu", digits)
    }

}

@MainActor
final class RunQUIKitSettingsViewController: UIViewController {
    private enum SettingsRow: Int, CaseIterable {
        case blockedList
        case privacy
        case userAgreement
        case clearCache

        var title: String {
            switch self {
            case .blockedList:
                "BLACKED LIST"
            case .privacy:
                "PRIVACY"
            case .userAgreement:
                "USER AGREEMENT"
            case .clearCache:
                "CLEAR THE CACHE"
            }
        }
    }

    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let navigationHeader = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let deactivateButton = UIButton(type: .custom)
    private let logoutButton = UIButton(type: .custom)
    private var cacheLoadingView: UIView?
    private var isClearingCache = false

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
        view.backgroundColor = RunQUIKitPageStyle.background
        configureBackdrop()
        configureNavigation()
        configureTable()
        configureBottomActions()
    }

    private func configureBackdrop() {
        RunQAuroralTabBackdrop.install(in: view)
    }

    private func configureNavigation() {
        navigationHeader.backgroundColor = .clear
        view.addSubview(navigationHeader)
        navigationHeader.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top).offset(56)
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
            make.bottom.equalToSuperview().offset(-9)
            make.size.equalTo(44)
        }

        let titleLabel = UILabel()
        titleLabel.text = "SETTINGS"
        titleLabel.textColor = .white
        titleLabel.font = AppFont.passionOne(size: 22)
        titleLabel.textAlignment = .center
        navigationHeader.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(backButton)
        }
    }

    private func configureTable() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            RunQSettingsRowCell.self,
            forCellReuseIdentifier: RunQSettingsRowCell.reuseIdentifier
        )
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(navigationHeader.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(288)
        }
    }

    private func configureBottomActions() {
        configureButton(
            deactivateButton,
            title: "Deactivate Account",
            backgroundColor: RunQUIKitPageStyle.orange
        )
        deactivateButton.addAction(
            UIAction { [weak self] _ in self?.openAccountDeletion() },
            for: .touchUpInside
        )
        view.addSubview(deactivateButton)

        configureButton(
            logoutButton,
            title: "Logout",
            backgroundColor: UIColor(red: 50 / 255, green: 50 / 255, blue: 55 / 255, alpha: 1)
        )
        logoutButton.addAction(
            UIAction { [weak self] _ in self?.logout() },
            for: .touchUpInside
        )
        view.addSubview(logoutButton)

        logoutButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-18)
            make.width.equalTo(195)
            make.height.equalTo(52)
        }
        deactivateButton.snp.makeConstraints { make in
            make.centerX.width.equalTo(logoutButton)
            make.bottom.equalTo(logoutButton.snp.top).offset(-23)
            make.height.equalTo(52)
        }
    }

    private func configureButton(
        _ button: UIButton,
        title: String,
        backgroundColor: UIColor
    ) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = AppFont.barlow(size: 14)
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 26
    }

    private func openBlockedList() {
        guard sessionStore.currentUser?.isGuest == false else {
            presentLoginRequired()
            return
        }
        let page = RunQUIKitBlacklistViewController(
            initialCategory: .blacklist,
            dataStore: dataStore,
            sessionStore: sessionStore,
            includesBlacklist: true
        )
        page.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(page, animated: true)
    }

    private func openLegalDocument(_ document: RunQLegalDocumentViewController.Document) {
        let page = RunQLegalDocumentViewController(document: document)
        page.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(page, animated: true)
    }

    private func clearCache() {
        guard !isClearingCache else { return }
        isClearingCache = true
        showCacheLoading()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            URLCache.shared.removeAllCachedResponses()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard let self else { return }
                self.hideCacheLoading()
                self.isClearingCache = false
                self.showToast("Cache cleared.")
            }
        }
    }

    private func showCacheLoading() {
        guard cacheLoadingView == nil else { return }
        tableView.isUserInteractionEnabled = false
        deactivateButton.isEnabled = false
        logoutButton.isEnabled = false
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.52)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        overlay.addSubview(indicator)
        view.addSubview(overlay)
        overlay.snp.makeConstraints { make in make.edges.equalToSuperview() }
        indicator.snp.makeConstraints { make in make.center.equalToSuperview() }
        cacheLoadingView = overlay
    }

    private func hideCacheLoading() {
        cacheLoadingView?.removeFromSuperview()
        cacheLoadingView = nil
        tableView.isUserInteractionEnabled = true
        deactivateButton.isEnabled = true
        logoutButton.isEnabled = true
    }

    func openAccountDeletion() {
        guard sessionStore.currentUser?.isGuest == false else {
            presentLoginRequired()
            return
        }
        deactivateButton.isHidden = true
        logoutButton.isHidden = true
        let dialog = RunQUIKitDeleteAccountViewController(
            sessionStore: sessionStore
        )
        dialog.onCancel = { [weak self] in
            self?.deactivateButton.isHidden = false
            self?.logoutButton.isHidden = false
        }
        dialog.modalPresentationStyle = .overFullScreen
        present(dialog, animated: false)
    }

    private func presentLoginRequired() {
        guard presentedViewController == nil else { return }
        let dialog = RunQUIKitLoginRequiredViewController()
        dialog.modalPresentationStyle = .overFullScreen
        dialog.onSignIn = { [weak self] in
            guard let self else { return }
            let login = RunQUIKitLoginViewController(
                dataStore: dataStore,
                sessionStore: sessionStore
            )
            login.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(login, animated: true)
        }
        present(dialog, animated: true)
    }

    private func logout() {
        logoutButton.isEnabled = false
        deactivateButton.isEnabled = false
        let loading = UIActivityIndicatorView(style: .large)
        loading.color = .white
        loading.backgroundColor = UIColor.black.withAlphaComponent(0.58)
        loading.startAnimating()
        view.addSubview(loading)
        loading.snp.makeConstraints { make in make.edges.equalToSuperview() }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            sessionStore.relinquishSession()
            var controller: UIViewController? = self
            while let current = controller {
                if let root = current as? RunQRootViewController {
                    root.refreshRoot()
                    return
                }
                controller = current.parent
            }
            loading.removeFromSuperview()
            logoutButton.isEnabled = true
            deactivateButton.isEnabled = true
            showToast("Unable to log out.")
        }
    }

    private func showToast(_ message: String) {
        let toast = UILabel()
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
            make.bottom.equalTo(deactivateButton.snp.top).offset(-20)
            make.width.equalTo(180)
            make.height.equalTo(40)
        }
        UIView.animate(withDuration: 0.2, delay: 1.6, options: .curveEaseIn) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }
}

extension RunQUIKitSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        SettingsRow.allCases.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        72
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RunQSettingsRowCell.reuseIdentifier,
            for: indexPath
        ) as! RunQSettingsRowCell
        let row = SettingsRow(rawValue: indexPath.row)!
        cell.configure(title: row.title, showsSeparator: row != .clearCache)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = SettingsRow(rawValue: indexPath.row) else { return }
        switch row {
        case .blockedList:
            openBlockedList()
        case .privacy:
            openLegalDocument(.privacyPolicy)
        case .userAgreement:
            openLegalDocument(.userAgreement)
        case .clearCache:
            clearCache()
        }
    }
}

private final class RunQSettingsRowCell: UITableViewCell {
    static let reuseIdentifier = "RunQSettingsRowCell"
    private let rowTitleLabel = UILabel()
    private let separator = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        rowTitleLabel.textColor = .white
        rowTitleLabel.font = AppFont.barlow(size: 16)
        rowTitleLabel.numberOfLines = 2
        contentView.addSubview(rowTitleLabel)
        rowTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-60)
        }

        let arrow = UIImageView(
            image: UIImage(named: "runq_vector_continue_glyph")?
                .withRenderingMode(.alwaysOriginal)
        )
        arrow.contentMode = .scaleAspectFit
        contentView.addSubview(arrow)
        arrow.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        separator.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        contentView.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func configure(title: String, showsSeparator: Bool) {
        rowTitleLabel.text = title
        separator.isHidden = !showsSeparator
    }
}

@MainActor
final class RunQUIKitChatboxViewController: UIViewController {
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var rooms: [RunQChatRoomRecord] = []

    init(dataStore: RunQDataStore, sessionStore: CynosureSessionStore) {
        self.dataStore = dataStore
        self.sessionStore = sessionStore
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
        RunQAuroralTabBackdrop.install(in: view)
        configureNavigation()
        configureTable()
        reloadRooms()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadRooms),
            name: .runQChatRoomsDidChange,
            object: dataStore
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadRooms()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    private func configureNavigation() {
        let backButton = UIButton(type: .custom)
        backButton.setImage(UIImage(named: "runq_navigation_back"), for: .normal)
        backButton.accessibilityLabel = "Back"
        backButton.addAction(
            UIAction { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            },
            for: .touchUpInside
        )

        let titleLabel = UILabel()
        titleLabel.text = "CHATBOX"
        titleLabel.textColor = .white
        titleLabel.font = AppFont.passionOne(size: 28)

        let createButton = UIButton(type: .system)
        createButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        createButton.layer.cornerRadius = 20
        createButton.tintColor = .white
        createButton.setImage(
            UIImage(systemName: "plus")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
            ),
            for: .normal
        )
        createButton.accessibilityLabel = "Create chatbox"
        createButton.addAction(
            UIAction { [weak self] _ in self?.openCreator() },
            for: .touchUpInside
        )

        [backButton, titleLabel, createButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 3),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            createButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            createButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            createButton.widthAnchor.constraint(equalToConstant: 40),
            createButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func configureTable() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            RunQChatboxRoomCell.self,
            forCellReuseIdentifier: RunQChatboxRoomCell.reuseIdentifier
        )
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 77),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func reloadRooms() {
        rooms = dataStore.chatRooms(visibleTo: sessionStore.currentUser?.id)
        tableView.reloadData()
    }

    private func openCreator() {
        let creator = RunQUIKitCreateChatboxViewController(
            title: "CREATE MY CHATBOX",
            dataStore: dataStore,
            sessionStore: sessionStore
        )
        navigationController?.pushViewController(creator, animated: true)
    }

    private func openJoinDialog(for room: RunQChatRoomRecord) {
        if room.createdBy == sessionStore.currentUser?.id {
            openChatRoom(room)
            return
        }
        let dialog = RunQUIKitJoinChatboxViewController(
            room: room,
            dataStore: dataStore,
            sessionStore: sessionStore
        )
        dialog.modalPresentationStyle = .overFullScreen
        dialog.modalTransitionStyle = .crossDissolve
        dialog.onJoined = { [weak self] in
            self?.reloadRooms()
            self?.openChatRoom(room)
        }
        present(dialog, animated: true)
    }

    private func openChatRoom(_ room: RunQChatRoomRecord) {
        let controller = RunQChatRoomViewController(
            room: room,
            dataStore: dataStore,
            sessionStore: sessionStore
        )
        navigationController?.pushViewController(controller, animated: true)
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
}

extension RunQUIKitChatboxViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rooms.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RunQChatboxRoomCell.reuseIdentifier,
            for: indexPath
        ) as! RunQChatboxRoomCell
        cell.configure(room: rooms[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        167
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        openJoinDialog(for: rooms[indexPath.row])
    }
}

private final class RunQChatboxRoomCell: UITableViewCell {
    static let reuseIdentifier = "RunQChatboxRoomCell"
    private let card = UIView()
    private let titleLabel = UILabel()
    private let avatarView = UIImageView()
    private let tealBadge = RunQChatboxParticipantBadge(color: UIColor(red: 0, green: 0.75, blue: 0.60, alpha: 1))
    private let orangeBadge = RunQChatboxParticipantBadge(color: UIColor(red: 0.95, green: 0.26, blue: 0.02, alpha: 1))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        card.backgroundColor = UIColor(red: 48 / 255, green: 48 / 255, blue: 52 / 255, alpha: 1)
        card.layer.cornerRadius = 28
        card.clipsToBounds = true
        contentView.addSubview(card)

        titleLabel.textColor = .white
        titleLabel.font = AppFont.passionOne(size: 20)
        titleLabel.numberOfLines = 2
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 16
        [titleLabel, avatarView, tealBadge, orangeBadge].forEach { card.addSubview($0) }

        card.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(151)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-16)
            make.size.equalTo(60)
        }
        orangeBadge.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-16)
            make.width.equalTo(66)
            make.height.equalTo(30)
        }
        tealBadge.snp.makeConstraints { make in
            make.trailing.equalTo(orangeBadge.snp.leading).offset(-12)
            make.centerY.equalTo(orangeBadge)
            make.width.equalTo(66)
            make.height.equalTo(30)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(room: RunQChatRoomRecord) {
        titleLabel.text = room.name
        if let avatarData = room.resolvedAvatarData {
            avatarView.image = UIImage(data: avatarData)
        } else {
            avatarView.image = UIImage(named: room.ownerAvatarAssetName)
        }
        tealBadge.count = room.maleParticipantCount
        orangeBadge.count = room.femaleParticipantCount
    }
}

private final class RunQChatboxParticipantBadge: UIView {
    private let countLabel = UILabel()
    private let iconView = UIImageView()
    var count = 0 { didSet { countLabel.text = "\(count)" } }

    init(color: UIColor) {
        super.init(frame: .zero)
        backgroundColor = UIColor.black.withAlphaComponent(0.16)
        layer.cornerRadius = 15
        iconView.image = UIImage(systemName: "person.fill")?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        countLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        countLabel.font = AppFont.barlow(size: 14)
        addSubview(iconView)
        addSubview(countLabel)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.size.equalTo(18)
        }
        countLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(5)
            make.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

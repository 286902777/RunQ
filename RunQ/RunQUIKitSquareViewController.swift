import SnapKit
import UIKit

@MainActor
final class RunQUIKitSquareViewController: UIViewController {
    private enum Section: Int, CaseIterable {
        case chatbox
        case posts
    }

    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let navigationHeader = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var selectedFeed = 0
    private var rooms: [RunQChatRoomRecord] = []
    private var posts: [RunQPostRecord] = []

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
        view.backgroundColor = UIColor(red: 16 / 255, green: 16 / 255, blue: 15 / 255, alpha: 1)
        configureBackdrop()
        configureNavigation()
        configureTable()
        reloadFeed()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(socialDataDidChange),
            name: .runQSocialDataDidChange,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadFeed()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--square-preview") else {
            return
        }
        tableView.setContentOffset(CGPoint(x: 0, y: 440), animated: false)
        #endif
    }

    private func reloadFeed() {
        let userID = sessionStore.currentUser?.id
        rooms = dataStore.chatRooms(visibleTo: userID)
        reloadPosts()
        tableView.reloadData()
    }

    private func reloadPosts() {
        guard selectedFeed == 1,
              let user = sessionStore.currentUser,
              !user.isGuest else {
            posts = dataStore.feedPosts(visibleTo: sessionStore.currentUser?.id)
            return
        }
        posts = dataStore.followingPosts(for: user.id)
    }

    private func selectFeed(_ index: Int) {
        guard index != selectedFeed else { return }
        if index == 1,
           !runQUIKitRequireAccount(
               from: self,
               dataStore: dataStore,
               sessionStore: sessionStore
           ) {
            tableView.reloadSections(
                IndexSet(integer: Section.posts.rawValue),
                with: .none
            )
            return
        }
        selectedFeed = index
        reloadPosts()
        tableView.reloadSections(
            IndexSet(integer: Section.posts.rawValue),
            with: .none
        )
    }

    @objc private func socialDataDidChange() {
        reloadFeed()
    }

    private func configureBackdrop() {
        RunQAuroralTabBackdrop.install(in: view)
    }

    private func configureNavigation() {
        navigationHeader.backgroundColor = .clear
        view.addSubview(navigationHeader)
        navigationHeader.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top).offset(50)
        }

        let searchButton = UIButton(type: .custom)
        var searchAttributes = AttributeContainer()
        searchAttributes.font = AppFont.barlow(size: 14)
        searchAttributes.foregroundColor = UIColor.white.withAlphaComponent(0.5)
        var searchConfiguration = UIButton.Configuration.plain()
        searchConfiguration.attributedTitle = AttributedString("Search", attributes: searchAttributes)
        searchConfiguration.titleAlignment = .leading
        searchConfiguration.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: 20,
            bottom: 0,
            trailing: 20
        )
        searchButton.configuration = searchConfiguration
        searchButton.contentHorizontalAlignment = .leading
        searchButton.backgroundColor = UIColor(red: 43 / 255, green: 42 / 255, blue: 39 / 255, alpha: 1)
        searchButton.layer.cornerRadius = 20
        searchButton.accessibilityLabel = "Search"
        searchButton.addAction(UIAction { [weak self] _ in self?.openSearch() }, for: .touchUpInside)
        navigationHeader.addSubview(searchButton)

        let notifications = UIButton(type: .custom)
        notifications.setImage(UIImage(named: "runq_home_notifications"), for: .normal)
        notifications.accessibilityLabel = "Notifications"
        notifications.addAction(UIAction { [weak self] _ in self?.openMessages() }, for: .touchUpInside)
        navigationHeader.addSubview(notifications)

        let add = UIButton(type: .custom)
        add.setImage(UIImage(named: "runq_square_add"), for: .normal)
        add.accessibilityLabel = "Create post"
        add.addAction(UIAction { [weak self] _ in self?.openPublisher() }, for: .touchUpInside)
        navigationHeader.addSubview(add)

        searchButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-4)
            make.height.equalTo(40)
        }
        notifications.snp.makeConstraints { make in
            make.leading.equalTo(searchButton.snp.trailing).offset(16)
            make.centerY.equalTo(searchButton)
            make.size.equalTo(40)
        }
        add.snp.makeConstraints { make in
            make.leading.equalTo(notifications.snp.trailing).offset(16)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(searchButton)
            make.size.equalTo(40)
        }
    }

    private func configureTable() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.sectionHeaderTopPadding = 0
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(RunQSquareRoomCell.self, forCellReuseIdentifier: RunQSquareRoomCell.reuseIdentifier)
        tableView.register(RunQSquarePostCell.self, forCellReuseIdentifier: RunQSquarePostCell.reuseIdentifier)
        tableView.register(RunQSquareChatboxHeaderView.self, forHeaderFooterViewReuseIdentifier: RunQSquareChatboxHeaderView.reuseIdentifier)
        tableView.register(RunQSquareFeedHeaderView.self, forHeaderFooterViewReuseIdentifier: RunQSquareFeedHeaderView.reuseIdentifier)
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(navigationHeader.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func openChatbox() {
        let page = RunQUIKitChatboxViewController(
            dataStore: dataStore,
            sessionStore: sessionStore
        )
        page.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(page, animated: true)
    }

    private func openSearch() {
        let page = RunQUIKitSearchViewController(
            title: "SEARCH",
            dataStore: dataStore,
            sessionStore: sessionStore
        )
        page.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(page, animated: true)
    }

    private func openMessages() {
        navigationController?.pushViewController(
            RunQEpistolaryPagerViewController(
                dataStore: dataStore,
                sessionStore: sessionStore
            ),
            animated: true
        )
    }

    private func openPublisher() {
        let page = RunQUIKitPublishViewController(
            dataStore: dataStore,
            sessionStore: sessionStore
        )
        page.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(page, animated: true)
    }

    private func openActivityDetail(_ post: RunQPostRecord) {
        let page = RunQUIKitActivityDetailViewController(
            post: post,
            dataStore: dataStore,
            sessionStore: sessionStore
        )
        navigationController?.pushViewController(page, animated: true)
    }

    private func openUserProfile(_ userID: String) {
        guard userID != sessionStore.currentUser?.id,
              dataStore.user(id: userID) != nil else { return }
        let page = RunQUIKitOtherProfileViewController(
            title: "PROFILE",
            dataStore: dataStore,
            sessionStore: sessionStore,
            userID: userID
        )
        navigationController?.pushViewController(page, animated: true)
    }

    private func showReport(for post: RunQPostRecord?) {
        guard let post,
              let currentUserID = sessionStore.currentUser?.id,
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

    private func showSquareToast(_ message: String) {
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
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(40)
            make.width.greaterThanOrEqualTo(180)
        }
        UIView.animate(withDuration: 0.2, delay: 1.6, options: .curveEaseIn) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }
}

extension RunQUIKitSquareViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .chatbox:
            return rooms.count
        case .posts:
            return posts.count
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == Section.chatbox.rawValue ? 42 : 54
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == Section.chatbox.rawValue {
            return indexPath.row == 0 ? 163 : 151
        }
        return 438
    }

    func tableView(
        _ tableView: UITableView,
        viewForHeaderInSection section: Int
    ) -> UIView? {
        if section == Section.chatbox.rawValue {
            guard let header = tableView.dequeueReusableHeaderFooterView(
                withIdentifier: RunQSquareChatboxHeaderView.reuseIdentifier
            ) as? RunQSquareChatboxHeaderView else { return nil }
            header.onMore = { [weak self] in self?.openChatbox() }
            return header
        }
        guard let header = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: RunQSquareFeedHeaderView.reuseIdentifier
        ) as? RunQSquareFeedHeaderView else { return nil }
        header.updateSelection(selectedFeed)
        header.onSelection = { [weak self] index in
            self?.selectFeed(index)
        }
        return header
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == Section.chatbox.rawValue {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: RunQSquareRoomCell.reuseIdentifier,
                for: indexPath
            ) as! RunQSquareRoomCell
            cell.configure(room: rooms[indexPath.row])
            return cell
        }

        let cell = tableView.dequeueReusableCell(
            withIdentifier: RunQSquarePostCell.reuseIdentifier,
            for: indexPath
        ) as! RunQSquarePostCell
        let post = posts.indices.contains(indexPath.row)
            ? posts[indexPath.row]
            : nil
        let canModerate = post?.authorID != sessionStore.currentUser?.id
        let isLiked = post.map { post in
            guard let userID = sessionStore.currentUser?.id else { return false }
            return dataStore.isPostLiked(postID: post.id, userID: userID)
        } ?? false
        cell.configure(
            post: post,
            canModerate: canModerate,
            isLiked: isLiked
        )
        cell.onReport = canModerate
            ? { [weak self] in self?.showReport(for: post) }
            : nil
        cell.onShare = nil
        cell.onAvatar = { [weak self] in
            guard let post else { return }
            self?.openUserProfile(post.authorID)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == Section.chatbox.rawValue {
            guard rooms.indices.contains(indexPath.row) else { return }
            let room = rooms[indexPath.row]
            if room.createdBy == sessionStore.currentUser?.id {
                openChatRoom(room)
                return
            }
            let dialog = RunQUIKitJoinChatboxViewController(
                room: room,
                dataStore: dataStore,
                sessionStore: sessionStore
            )
            dialog.onJoined = { [weak self] in self?.openChatRoom(room) }
            dialog.modalPresentationStyle = .overFullScreen
            dialog.modalTransitionStyle = .crossDissolve
            present(dialog, animated: true)
            return
        }
        guard posts.indices.contains(indexPath.row) else { return }
        openActivityDetail(posts[indexPath.row])
    }

    private func openChatRoom(_ room: RunQChatRoomRecord) {
        let controller = RunQChatRoomViewController(
            room: room,
            dataStore: dataStore,
            sessionStore: sessionStore
        )
        navigationController?.pushViewController(controller, animated: true)
    }
}

private final class RunQSquareChatboxHeaderView: UITableViewHeaderFooterView {
    static let reuseIdentifier = "RunQSquareChatboxHeaderView"
    var onMore: (() -> Void)?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        backgroundView = UIView()
        backgroundView?.backgroundColor = .clear

        let mark = UIImageView(image: UIImage(named: "runq_square_chatbox_mark"))
        let title = UILabel()
        title.text = "CHATBOX"
        title.textColor = .white
        title.font = AppFont.passionOne(size: 20)
        let more = UIButton(type: .custom)
        var moreAttributes = AttributeContainer()
        moreAttributes.font = AppFont.barlow(size: 16)
        moreAttributes.foregroundColor = .white
        var moreConfiguration = UIButton.Configuration.plain()
        moreConfiguration.attributedTitle = AttributedString("MORE", attributes: moreAttributes)
        moreConfiguration.image = UIImage(named: "runq_vector_continue_glyph")
        moreConfiguration.imagePlacement = .trailing
        moreConfiguration.imagePadding = 10
        moreConfiguration.contentInsets = .zero
        more.configuration = moreConfiguration
        more.addAction(UIAction { [weak self] _ in self?.onMore?() }, for: .touchUpInside)
        contentView.addSubview(mark)
        contentView.addSubview(title)
        contentView.addSubview(more)

        mark.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.size.equalTo(20)
        }
        title.snp.makeConstraints { make in
            make.leading.equalTo(mark.snp.trailing).offset(4)
            make.centerY.equalTo(mark)
        }
        more.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.height.equalTo(36)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}

private final class RunQSquareRoomCell: UITableViewCell {
    static let reuseIdentifier = "RunQSquareRoomCell"
    private let titleLabel = UILabel()
    private let avatar = UIImageView()
    private let maleParticipantCountLabel = UILabel()
    private let femaleParticipantCountLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        let card = UIImageView(image: UIImage(named: "runq_square_buddy_card_background"))
        card.contentMode = .scaleToFill
        card.isUserInteractionEnabled = true
        contentView.addSubview(card)
        card.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(151)
        }

        titleLabel.textColor = .white
        titleLabel.font = AppFont.passionOne(size: 20)
        titleLabel.numberOfLines = 2
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(17)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }

        avatar.image = UIImage(named: "runq_square_buddy_avatar")
        avatar.contentMode = .scaleAspectFill
        avatar.layer.cornerRadius = 12
        avatar.clipsToBounds = true
        card.addSubview(avatar)
        avatar.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview().inset(16)
            make.size.equalTo(58)
        }

        let teal = participantBadge(
            iconName: "runq_square_participant_teal",
            countLabel: maleParticipantCountLabel
        )
        let orange = participantBadge(
            iconName: "runq_square_participant_orange",
            countLabel: femaleParticipantCountLabel
        )
        card.addSubview(teal)
        card.addSubview(orange)
        orange.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview().inset(16)
            make.width.equalTo(48)
            make.height.equalTo(28)
        }
        teal.snp.makeConstraints { make in
            make.trailing.equalTo(orange.snp.leading).offset(-12)
            make.centerY.equalTo(orange)
            make.width.height.equalTo(orange)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func configure(room: RunQChatRoomRecord) {
        titleLabel.text = room.name
        avatar.image = room.resolvedAvatarData.flatMap(UIImage.init(data:))
            ?? UIImage(named: room.ownerAvatarAssetName)
        maleParticipantCountLabel.text = "\(room.maleParticipantCount)"
        femaleParticipantCountLabel.text = "\(room.femaleParticipantCount)"
    }

    private func participantBadge(iconName: String, countLabel: UILabel) -> UIView {
        let badge = UIView()
        badge.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        badge.layer.cornerRadius = 14
        let icon = UIImageView(image: UIImage(named: iconName))
        countLabel.textColor = .white
        countLabel.font = AppFont.barlow(size: 14)
        badge.addSubview(icon)
        badge.addSubview(countLabel)
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(7)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
        countLabel.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(4)
            make.centerY.equalToSuperview()
        }
        return badge
    }
}

private final class RunQSquareFeedHeaderView: UITableViewHeaderFooterView {
    static let reuseIdentifier = "RunQSquareFeedHeaderView"
    var onSelection: ((Int) -> Void)?
    private let squareStack = UIStackView()
    private let focusLabel = UILabel()
    private let indicator = UIImageView(image: UIImage(named: "runq_square_section_indicator"))
    private var selectedIndex = 0

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        backgroundView = UIView()
        backgroundView?.backgroundColor = UIColor(red: 16 / 255, green: 16 / 255, blue: 15 / 255, alpha: 1)

        let mark = UIImageView(image: UIImage(named: "runq_square_section_mark"))
        let squareLabel = UILabel()
        squareLabel.text = "SQUARE"
        squareLabel.textColor = .white
        squareLabel.font = AppFont.passionOne(size: 20)
        squareStack.axis = .horizontal
        squareStack.alignment = .center
        squareStack.spacing = 4
        squareStack.addArrangedSubview(mark)
        squareStack.addArrangedSubview(squareLabel)
        mark.snp.makeConstraints { make in make.size.equalTo(20) }

        focusLabel.text = "FOCUS ON"
        focusLabel.textColor = UIColor.white.withAlphaComponent(0.62)
        focusLabel.font = AppFont.barlow(size: 16)
        let squareButton = UIButton(type: .custom)
        squareButton.addAction(UIAction { [weak self] _ in self?.select(0) }, for: .touchUpInside)
        let focusButton = UIButton(type: .custom)
        focusButton.addAction(UIAction { [weak self] _ in self?.select(1) }, for: .touchUpInside)
        let track = UIView()
        track.backgroundColor = UIColor.white.withAlphaComponent(0.34)
        indicator.contentMode = .scaleToFill
        contentView.addSubview(squareStack)
        contentView.addSubview(focusLabel)
        contentView.addSubview(track)
        contentView.addSubview(indicator)
        contentView.addSubview(squareButton)
        contentView.addSubview(focusButton)

        squareStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(8)
        }
        focusLabel.snp.makeConstraints { make in
            make.leading.equalTo(squareStack.snp.trailing).offset(28)
            make.centerY.equalTo(squareStack)
        }
        track.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().offset(-2)
            make.height.equalTo(2)
        }
        squareButton.snp.makeConstraints { make in
            make.edges.equalTo(squareStack).inset(-8)
        }
        focusButton.snp.makeConstraints { make in
            make.edges.equalTo(focusLabel).inset(-8)
        }
        updateSelection(0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func updateSelection(_ index: Int) {
        selectedIndex = index
        focusLabel.textColor = index == 1 ? .white : UIColor.white.withAlphaComponent(0.62)
        indicator.snp.remakeConstraints { make in
            let selectedView: UIView = index == 0 ? squareStack : focusLabel
            make.centerX.equalTo(selectedView)
            make.width.equalTo(selectedView)
            make.bottom.equalToSuperview().offset(-1)
            make.height.equalTo(3)
        }
    }

    private func select(_ index: Int) {
        guard selectedIndex != index else { return }
        updateSelection(index)
        onSelection?(index)
    }
}

final class RunQSquarePostCell: UITableViewCell,
    UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    static let reuseIdentifier = "RunQSquarePostCell"
    var onReport: (() -> Void)?
    var onShare: (() -> Void)? {
        didSet { shareButton.isUserInteractionEnabled = onShare != nil }
    }
    var onAvatar: (() -> Void)?
    private let reportButton = UIButton(type: .custom)
    private let shareButton = UIButton(type: .custom)
    private let authorLabel = UILabel()
    private let avatar = UIImageView()
    private let avatarButton = UIButton(type: .custom)
    private let dateLabel = UILabel()
    private let messageLabel = UILabel()
    private let firstTags = UIStackView()
    private let secondTags = UIStackView()
    private let photoLayout = UICollectionViewFlowLayout()
    private lazy var photos = UICollectionView(
        frame: .zero,
        collectionViewLayout: photoLayout
    )
    private var photoItems: [UIImage] = []
    private let likeIconView = UIImageView()
    private let likeCountLabel = UILabel()
    private let commentCountLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        let card = UIImageView(image: UIImage(named: "runq_square_post_card_background"))
        card.contentMode = .scaleToFill
        card.isUserInteractionEnabled = true
        contentView.addSubview(card)
        card.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(422)
        }

        avatar.image = UIImage(named: "runq_square_author_avatar")
        avatar.contentMode = .scaleAspectFill
        avatar.layer.cornerRadius = 20
        avatar.clipsToBounds = true
        card.addSubview(avatar)
        avatar.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(16)
            make.size.equalTo(40)
        }
        avatarButton.accessibilityLabel = "Open author profile"
        avatarButton.addAction(
            UIAction { [weak self] _ in self?.onAvatar?() },
            for: .touchUpInside
        )
        card.addSubview(avatarButton)
        avatarButton.snp.makeConstraints { make in make.edges.equalTo(avatar) }

        reportButton.setImage(UIImage(named: "runq_square_report"), for: .normal)
        reportButton.accessibilityLabel = "Report"
        reportButton.addAction(UIAction { [weak self] _ in self?.onReport?() }, for: .touchUpInside)
        card.addSubview(reportButton)
        reportButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-16)
            make.size.equalTo(32)
        }

        shareButton.setImage(UIImage(named: "runq_square_share_news"), for: .normal)
        shareButton.accessibilityLabel = "Share news"
        shareButton.titleLabel?.font = AppFont.barlow(size: 15)
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.isUserInteractionEnabled = false
        shareButton.addAction(
            UIAction { [weak self] _ in self?.onShare?() },
            for: .touchUpInside
        )
        card.addSubview(shareButton)
        shareButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(63)
            make.trailing.equalToSuperview().offset(-16)
            make.width.equalTo(148)
            make.height.equalTo(40)
        }

        authorLabel.textColor = .white
        authorLabel.font = AppFont.barlow(size: 15)
        card.addSubview(authorLabel)
        authorLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(64)
            make.leading.equalToSuperview().offset(16)
        }

        dateLabel.textColor = UIColor.white.withAlphaComponent(0.56)
        dateLabel.font = AppFont.barlow(size: 12)
        card.addSubview(dateLabel)
        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(authorLabel.snp.bottom).offset(4)
            make.leading.equalTo(authorLabel)
        }

        messageLabel.textColor = .white
        messageLabel.font = AppFont.barlow(size: 14)
        messageLabel.numberOfLines = 2
        card.addSubview(messageLabel)
        messageLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(108)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }

        configureTagStack(firstTags)
        configureTagStack(secondTags)
        card.addSubview(firstTags)
        card.addSubview(secondTags)
        firstTags.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(158)
            make.leading.equalToSuperview().offset(16)
            make.height.equalTo(28)
        }
        secondTags.snp.makeConstraints { make in
            make.top.equalTo(firstTags.snp.bottom).offset(6)
            make.leading.equalTo(firstTags)
            make.height.equalTo(28)
        }

        photoLayout.scrollDirection = .horizontal
        photoLayout.minimumLineSpacing = 5
        photoLayout.minimumInteritemSpacing = 5
        photos.backgroundColor = .clear
        photos.isScrollEnabled = false
        photos.showsHorizontalScrollIndicator = false
        photos.dataSource = self
        photos.delegate = self
        photos.register(
            RunQSquarePostPhotoCell.self,
            forCellWithReuseIdentifier: RunQSquarePostPhotoCell.reuseIdentifier
        )
        card.addSubview(photos)
        photos.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(224)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(98)
        }

        let like = metricPill(
            iconName: "runq_home_like_idle",
            label: likeCountLabel,
            iconView: likeIconView
        )
        let comments = metricPill(iconName: "runq_square_comment", label: commentCountLabel)
        card.addSubview(like)
        card.addSubview(comments)
        like.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(32)
            make.top.equalToSuperview().offset(335)
            make.width.equalTo(110)
            make.height.equalTo(40)
        }
        comments.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-32)
            make.centerY.width.height.equalTo(like)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        photoLayout.invalidateLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onReport = nil
        onShare = nil
        onAvatar = nil
        authorLabel.text = nil
        avatar.image = nil
        dateLabel.text = nil
        messageLabel.text = nil
        updateTags([])
        photoItems = []
        photos.reloadData()
        likeCountLabel.text = nil
        commentCountLabel.text = nil
        likeIconView.image = UIImage(named: "runq_home_like_idle")
        reportButton.isHidden = true
        reportButton.isUserInteractionEnabled = false
        updatePostType(.news)
    }

    func configure(post: RunQPostRecord?, canModerate: Bool, isLiked: Bool) {
        reportButton.isHidden = !canModerate || post == nil
        reportButton.isUserInteractionEnabled = canModerate && post != nil
        guard let post else { return }
        authorLabel.text = "@\(post.authorName.uppercased())"
        avatar.image = UIImage(named: post.authorAvatarAssetName)
        dateLabel.text = Self.dateFormatter.string(from: post.createdAt)
        messageLabel.text = post.text
        updateTags(post.tags)
        photoItems = post.imageDataItems.prefix(3).compactMap(UIImage.init(data:))
        if photoItems.isEmpty,
           let fallbackImage = UIImage(named: post.imageAssetName) {
            photoItems = [fallbackImage]
        }
        photoLayout.invalidateLayout()
        photos.reloadData()
        likeCountLabel.text = "\(post.likeCount)"
        likeIconView.image = UIImage(
            named: isLiked ? "runq_home_like_selected" : "runq_home_like_idle"
        )
        commentCountLabel.text = "\(post.commentCount)"
        updatePostType(post.type)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        photoItems.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RunQSquarePostPhotoCell.reuseIdentifier,
            for: indexPath
        ) as! RunQSquarePostPhotoCell
        cell.configure(image: photoItems[indexPath.item])
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let side = floor(collectionView.bounds.height)
        return CGSize(width: side, height: side)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM,d   HH:mm:ss"
        return formatter
    }()

    private func updatePostType(_ type: RunQPostType) {
        switch type {
        case .news:
            shareButton.backgroundColor = .clear
            shareButton.layer.cornerRadius = 0
            shareButton.setTitle(nil, for: .normal)
            shareButton.setImage(
                UIImage(named: "runq_square_share_news"),
                for: .normal
            )
            shareButton.accessibilityLabel = "Share news"
        case .buddy:
            shareButton.setImage(nil, for: .normal)
            shareButton.backgroundColor = UIColor(
                red: 1,
                green: 91 / 255,
                blue: 25 / 255,
                alpha: 1
            )
            shareButton.layer.cornerRadius = 12
            shareButton.setTitle("SEEK BUDDY", for: .normal)
            shareButton.accessibilityLabel = "Seek buddy"
        }
    }

    private func configureTagStack(_ row: UIStackView) {
        row.axis = .horizontal
        row.spacing = 8
    }

    private func updateTags(_ tags: [String]) {
        [firstTags, secondTags].forEach { row in
            row.arrangedSubviews.forEach {
                row.removeArrangedSubview($0)
                $0.removeFromSuperview()
            }
        }
        for (index, title) in tags.prefix(4).enumerated() {
            let label = UILabel()
            label.text = "  \(title)  "
            label.textColor = UIColor(red: 0.04, green: 0.98, blue: 0.76, alpha: 1)
            label.backgroundColor = UIColor(red: 0.03, green: 0.45, blue: 0.36, alpha: 0.45)
            label.font = AppFont.barlow(size: 12)
            label.layer.cornerRadius = 14
            label.clipsToBounds = true
            (index < 2 ? firstTags : secondTags).addArrangedSubview(label)
        }
    }

    private func metricPill(
        iconName: String,
        label: UILabel,
        iconView: UIImageView? = nil
    ) -> UIView {
        let pill = UIView()
        pill.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        pill.layer.cornerRadius = 20
        let icon = iconView ?? UIImageView()
        icon.image = UIImage(named: iconName)
        label.textColor = .white
        label.font = AppFont.barlow(size: 16)
        pill.addSubview(icon)
        pill.addSubview(label)
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(-4)
            make.centerY.equalToSuperview()
            make.size.equalTo(52)
        }
        label.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(icon.snp.trailing).offset(4)
        }
        return pill
    }
}

private final class RunQSquarePostPhotoCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQSquarePostPhotoCell"

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }

    func configure(image: UIImage) {
        imageView.image = image
    }
}

@MainActor
final class RunQProfilePostListView: UIView, UITableViewDataSource, UITableViewDelegate {
    static let rowHeight: CGFloat = 438

    var onOpenPost: ((RunQPostRecord) -> Void)?
    var onOpenAuthor: ((String) -> Void)?
    var onReportPost: ((RunQPostRecord) -> Void)?
    var onSharePost: ((RunQPostRecord) -> Void)?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private var posts: [RunQPostRecord] = []
    private var currentUserID: String?
    private var displaysLikedState = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            RunQSquarePostCell.self,
            forCellReuseIdentifier: RunQSquarePostCell.reuseIdentifier
        )

        emptyLabel.textAlignment = .center
        emptyLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        emptyLabel.font = AppFont.barlow(size: 14)

        addSubview(tableView)
        addSubview(emptyLabel)
        tableView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(20)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    var requiredHeight: CGFloat {
        posts.isEmpty ? 96 : CGFloat(posts.count) * Self.rowHeight
    }

    func update(
        posts: [RunQPostRecord],
        currentUserID: String?,
        emptyMessage: String,
        displaysLikedState: Bool = false
    ) {
        self.posts = posts
        self.currentUserID = currentUserID
        self.displaysLikedState = displaysLikedState
        emptyLabel.text = emptyMessage
        emptyLabel.isHidden = !posts.isEmpty
        tableView.isHidden = posts.isEmpty
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        posts.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let post = posts[indexPath.row]
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RunQSquarePostCell.reuseIdentifier,
            for: indexPath
        ) as! RunQSquarePostCell
        cell.configure(
            post: post,
            canModerate: post.authorID != currentUserID,
            isLiked: displaysLikedState
        )
        cell.onAvatar = { [weak self] in self?.onOpenAuthor?(post.authorID) }
        cell.onReport = post.authorID != currentUserID
            ? { [weak self] in self?.onReportPost?(post) }
            : nil
        cell.onShare = { [weak self] in self?.onSharePost?(post) }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        Self.rowHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onOpenPost?(posts[indexPath.row])
    }
}

import SnapKit
import UIKit

private enum RunQEpistolaryDestination {
    case room(String)
    case direct(String)
    case profile(String)
}

private struct RunQEpistolaryItem {
    let title: String
    let preview: String
    let time: String
    let avatarAssetName: String
    let avatarData: Data?
    let destination: RunQEpistolaryDestination
}

@MainActor
final class RunQEpistolaryPagerViewController: UIViewController {
    enum InitialPage {
        case chats
        case notifications
    }

    private enum Page: Int, CaseIterable {
        case chats
        case notifications
    }

    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let navigationHeader = UIView()
    private let chatsButton = UIButton(type: .custom)
    private let notificationsButton = UIButton(type: .custom)
    private let indicatorView = UIImageView(
        image: UIImage(named: "runq_square_section_indicator")?
            .resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 9))
    )
    private let pager = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal
    )
    private let chatsPage: RunQEpistolaryListViewController
    private let notificationsPage: RunQEpistolaryListViewController
    private var selectedPage: Page
    private var isPagingProgrammatically = false

    init(
        dataStore: RunQDataStore,
        sessionStore: CynosureSessionStore,
        initialPage: InitialPage = .chats
    ) {
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        selectedPage = initialPage == .notifications ? .notifications : .chats
        chatsPage = RunQEpistolaryListViewController(items: [])
        notificationsPage = RunQEpistolaryListViewController(items: [])
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        chatsPage.onSelect = { [weak self] item in self?.open(item.destination) }
        notificationsPage.onSelect = { [weak self] item in self?.open(item.destination) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .runQUIKitBackground
        configureHeader()
        configurePager()
        updateSelection(animated: false)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(socialDataDidChange),
            name: .runQSocialDataDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(socialDataDidChange),
            name: .runQReservationsDidChange,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadChatItems()
        reloadNotificationItems()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    private var pages: [RunQEpistolaryListViewController] {
        [chatsPage, notificationsPage]
    }

    private func configureHeader() {
        let backButton = UIButton(type: .custom)
        backButton.setImage(UIImage(named: "runq_navigation_back"), for: .normal)
        backButton.accessibilityLabel = "Back"
        backButton.addAction(
            UIAction { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            },
            for: .touchUpInside
        )

        chatsButton.accessibilityLabel = "Chats"
        notificationsButton.accessibilityLabel = "Notifications"
        chatsButton.titleLabel?.numberOfLines = 1
        notificationsButton.titleLabel?.numberOfLines = 1
        chatsButton.titleLabel?.lineBreakMode = .byClipping
        notificationsButton.titleLabel?.lineBreakMode = .byClipping
        chatsButton.addAction(
            UIAction { [weak self] _ in self?.select(.chats) },
            for: .touchUpInside
        )
        notificationsButton.addAction(
            UIAction { [weak self] _ in self?.select(.notifications) },
            for: .touchUpInside
        )

        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.28)
        indicatorView.contentMode = .scaleToFill

        view.addSubview(navigationHeader)
        [backButton, chatsButton, notificationsButton, divider, indicatorView].forEach(
            navigationHeader.addSubview
        )

        navigationHeader.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top).offset(104)
        }
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(3)
            make.size.equalTo(44)
        }
        chatsButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalTo(divider.snp.top)
            make.height.equalTo(44)
        }
        notificationsButton.snp.makeConstraints { make in
            make.leading.equalTo(chatsButton.snp.trailing).offset(18)
            make.bottom.equalTo(chatsButton)
            make.height.equalTo(chatsButton)
            make.trailing.lessThanOrEqualToSuperview().inset(20)
        }
        divider.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(2)
        }
        indicatorView.snp.makeConstraints { make in
            make.leading.equalTo(chatsButton)
            make.bottom.equalToSuperview()
            make.width.equalTo(chatsButton)
            make.height.equalTo(3)
        }
    }

    private func configurePager() {
        addChild(pager)
        view.addSubview(pager.view)
        pager.view.backgroundColor = .clear
        pager.view.snp.makeConstraints { make in
            make.top.equalTo(navigationHeader.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        pager.didMove(toParent: self)
        pager.dataSource = self
        pager.delegate = self
        pager.setViewControllers(
            [pages[selectedPage.rawValue]],
            direction: .forward,
            animated: false
        )
    }

    private func select(_ page: Page) {
        guard page != selectedPage, !isPagingProgrammatically else { return }
        let direction: UIPageViewController.NavigationDirection = page.rawValue > selectedPage.rawValue
            ? .forward
            : .reverse
        selectedPage = page
        isPagingProgrammatically = true
        pager.setViewControllers(
            [pages[page.rawValue]],
            direction: direction,
            animated: true
        ) { [weak self] _ in
            self?.isPagingProgrammatically = false
        }
        updateSelection(animated: true)
    }

    private func updateSelection(animated: Bool) {
        configureTabButton(chatsButton, title: "CHATS", isSelected: selectedPage == .chats, showsIcon: true)
        configureTabButton(
            notificationsButton,
            title: "NOTIFICATIONS",
            isSelected: selectedPage == .notifications,
            showsIcon: false
        )
        indicatorView.snp.remakeConstraints { make in
            make.leading.equalTo(selectedPage == .chats ? chatsButton : notificationsButton)
            make.bottom.equalToSuperview()
            make.width.equalTo(selectedPage == .chats ? chatsButton : notificationsButton)
            make.height.equalTo(3)
        }
        guard animated else { return }
        UIView.animate(withDuration: 0.24) {
            self.navigationHeader.layoutIfNeeded()
        }
    }

    private func configureTabButton(
        _ button: UIButton,
        title: String,
        isSelected: Bool,
        showsIcon: Bool
    ) {
        var attributes = AttributeContainer()
        attributes.font = isSelected
            ? AppFont.passionOne(size: 18)
            : AppFont.barlow(size: 16)
        attributes.foregroundColor = isSelected ? .white : UIColor.white.withAlphaComponent(0.72)
        var configuration = UIButton.Configuration.plain()
        configuration.attributedTitle = AttributedString(title, attributes: attributes)
        configuration.contentInsets = .zero
        configuration.imagePadding = 6
        configuration.image = showsIcon
            ? UIImage(named: "runq_campaniform_messages_selected")
            : nil
        button.configuration = configuration
        button.contentHorizontalAlignment = .leading
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.lineBreakMode = .byClipping
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func open(_ destination: RunQEpistolaryDestination) {
        switch destination {
        case .room(let roomID):
            let currentUserID = sessionStore.currentUser?.id
            guard let room = dataStore.chatRooms(visibleTo: currentUserID)
                .first(where: { $0.id == roomID }) else {
                RunQToastPresenter.show("This chat is unavailable.", on: view)
                return
            }
            if room.createdBy == currentUserID {
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
            dialog.onJoined = { [weak self] in self?.openChatRoom(room) }
            present(dialog, animated: true)
        case .direct(let peerID):
            guard peerID != sessionStore.currentUser?.id,
                  dataStore.isUserVisible(peerID, to: sessionStore.currentUser?.id),
                  let peer = dataStore.user(id: peerID) else {
                RunQToastPresenter.show("This chat is unavailable.", on: view)
                return
            }
            navigationController?.pushViewController(
                RunQDirectChatViewController(
                    peer: peer,
                    dataStore: dataStore,
                    sessionStore: sessionStore
                ),
                animated: true
            )
        case .profile(let userID):
            guard userID != sessionStore.currentUser?.id,
                  dataStore.isUserVisible(userID, to: sessionStore.currentUser?.id),
                  dataStore.user(id: userID) != nil else {
                RunQToastPresenter.show("This profile is unavailable.", on: view)
                return
            }
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
    }

    private func openChatRoom(_ room: RunQChatRoomRecord) {
        navigationController?.pushViewController(
            RunQChatRoomViewController(
                room: room,
                dataStore: dataStore,
                sessionStore: sessionStore
            ),
            animated: true
        )
    }

    private func reloadChatItems() {
        let userID = sessionStore.currentUser?.id
        var items = dataStore.chatRooms(visibleTo: userID).map { room in
            let latestMessage = dataStore.chatMessages(
                roomID: room.id,
                visibleTo: userID
            ).last
            return RunQEpistolaryItem(
                title: room.name,
                preview: latestMessage.map {
                    $0.audioData == nil ? $0.text : "[Voice]"
                } ?? "No messages yet.",
                time: latestMessage.map { Self.timeText(for: $0.createdAt) } ?? "",
                avatarAssetName: room.ownerAvatarAssetName,
                avatarData: room.resolvedAvatarData,
                destination: .room(room.id)
            )
        }
        if let userID = sessionStore.currentUser?.id {
            items.append(contentsOf: dataStore.directConversations(userID: userID).map {
                RunQEpistolaryItem(
                    title: $0.peer.username.uppercased(),
                    preview: $0.preview,
                    time: Self.timeText(for: $0.createdAt),
                    avatarAssetName: $0.peer.avatarAssetName,
                    avatarData: dataStore.profileDetails(for: $0.peer.id).avatarData,
                    destination: .direct($0.peer.id)
                )
            })
        }
        chatsPage.update(items: items)
    }

    private func reloadNotificationItems() {
        let userID = sessionStore.currentUser?.id
        let visibleRooms = dataStore.chatRooms(visibleTo: userID)
        var items: [RunQEpistolaryItem] = []
        if let userID {
            items = dataStore.reservations(for: userID).compactMap { reservation in
                let isRequester = reservation.requesterID == userID
                let peerID = isRequester
                    ? reservation.targetUserID
                    : reservation.requesterID
                guard dataStore.isUserVisible(peerID, to: userID),
                      let peer = dataStore.user(id: peerID) else { return nil }
                let role = isRequester ? "SENT TO" : "FROM"
                let activity = reservation.activity.uppercased()
                let people = reservation.attendance == 4
                    ? "4+ PEOPLE"
                    : "\(reservation.attendance) PEOPLE"
                return RunQEpistolaryItem(
                    title: "RESERVATION \(role) \(peer.username.uppercased())",
                    preview: "\(activity) · \(people) · \(Self.dateText(for: reservation.startDate))",
                    time: Self.timeText(for: reservation.createdAt),
                    avatarAssetName: peer.avatarAssetName,
                    avatarData: dataStore.profileDetails(for: peerID).avatarData,
                    destination: .profile(peerID)
                )
            }
        }
        items.append(contentsOf: Self.notificationItems.compactMap { item -> RunQEpistolaryItem? in
            switch item.destination {
            case .direct(let peerID), .profile(let peerID):
                guard dataStore.isUserVisible(peerID, to: userID),
                      let user = dataStore.user(id: peerID) else { return nil }
                return RunQEpistolaryItem(
                    title: item.title,
                    preview: item.preview,
                    time: item.time,
                    avatarAssetName: user.avatarAssetName,
                    avatarData: dataStore.profileDetails(for: peerID).avatarData,
                    destination: item.destination
                )
            case .room(let roomID):
                guard let room = visibleRooms.first(where: { $0.id == roomID }) else {
                    return nil
                }
                return RunQEpistolaryItem(
                    title: item.title,
                    preview: item.preview,
                    time: item.time,
                    avatarAssetName: room.ownerAvatarAssetName,
                    avatarData: room.resolvedAvatarData,
                    destination: item.destination
                )
            }
        })
        notificationsPage.update(items: items)
    }

    @objc private func socialDataDidChange() {
        reloadChatItems()
        reloadNotificationItems()
    }

    private static func timeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }

    private static func dateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date).uppercased()
    }

    private static let notificationItems = [
        RunQEpistolaryItem(
            title: "LUNA LIKED YOUR POST",
            preview: "Your climbing update received a new like.",
            time: "9:32",
            avatarAssetName: "",
            avatarData: nil,
            destination: .profile("seed-user-4")
        ),
        RunQEpistolaryItem(
            title: "KIMI STARTED FOLLOWING YOU",
            preview: "You have a new follower.",
            time: "9:32",
            avatarAssetName: "",
            avatarData: nil,
            destination: .profile("seed-user-5")
        )
    ]
}

extension RunQEpistolaryPagerViewController: UIPageViewControllerDataSource,
    UIPageViewControllerDelegate {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let index = pages.firstIndex(where: { $0 === viewController }), index > 0 else {
            return nil
        }
        return pages[index - 1]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let index = pages.firstIndex(where: { $0 === viewController }), index + 1 < pages.count else {
            return nil
        }
        return pages[index + 1]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let visible = pageViewController.viewControllers?.first,
              let index = pages.firstIndex(where: { $0 === visible }),
              let page = Page(rawValue: index) else { return }
        selectedPage = page
        updateSelection(animated: true)
    }
}

@MainActor
private final class RunQEpistolaryListViewController: UIViewController {
    var onSelect: ((RunQEpistolaryItem) -> Void)?
    private var items: [RunQEpistolaryItem]
    private let tableView = UITableView(frame: .zero, style: .plain)

    init(items: [RunQEpistolaryItem]) {
        self.items = items
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func update(items: [RunQEpistolaryItem]) {
        self.items = items
        guard isViewLoaded else { return }
        tableView.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 24, right: 0)
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            RunQEpistolaryCell.self,
            forCellReuseIdentifier: RunQEpistolaryCell.reuseIdentifier
        )
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension RunQEpistolaryListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        80
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RunQEpistolaryCell.reuseIdentifier,
            for: indexPath
        ) as! RunQEpistolaryCell
        cell.configure(items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect?(items[indexPath.row])
    }
}

private final class RunQEpistolaryCell: UITableViewCell {
    static let reuseIdentifier = "RunQEpistolaryCell"

    private let cardView = UIView()
    private let avatarView = UIImageView()
    private let titleLabel = UILabel()
    private let previewLabel = UILabel()
    private let timeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        cardView.backgroundColor = UIColor(red: 48 / 255, green: 48 / 255, blue: 51 / 255, alpha: 1)
        cardView.layer.cornerRadius = 16
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 20
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        titleLabel.font = AppFont.barlow(size: 14)
        titleLabel.lineBreakMode = .byTruncatingTail
        previewLabel.textColor = UIColor.white.withAlphaComponent(0.54)
        previewLabel.font = AppFont.barlow(size: 12)
        previewLabel.lineBreakMode = .byTruncatingTail
        timeLabel.textColor = UIColor.white.withAlphaComponent(0.50)
        timeLabel.font = AppFont.barlow(size: 12)
        timeLabel.textAlignment = .right

        contentView.addSubview(cardView)
        [avatarView, titleLabel, previewLabel, timeLabel].forEach(cardView.addSubview)
        cardView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(16)
        }
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(21)
            make.top.equalToSuperview().offset(11)
            make.size.equalTo(40)
        }
        timeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20)
            make.width.equalTo(42)
            make.height.equalTo(18)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(15)
            make.trailing.equalTo(timeLabel.snp.leading).offset(-10)
            make.height.equalTo(20)
        }
        previewLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().inset(20)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.height.equalTo(18)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func configure(_ item: RunQEpistolaryItem) {
        avatarView.image = item.avatarData.flatMap(UIImage.init(data:))
            ?? UIImage(named: item.avatarAssetName)
        titleLabel.text = item.title
        previewLabel.text = item.preview
        timeLabel.text = item.time
        titleLabel.snp.remakeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(15)
            make.trailing.equalTo(timeLabel.snp.leading).offset(-10)
            make.top.equalToSuperview().offset(11)
            make.height.equalTo(20)
        }
        previewLabel.snp.remakeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().inset(20)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.height.equalTo(18)
        }
        timeLabel.snp.remakeConstraints { make in
            make.trailing.equalToSuperview().inset(20)
            make.centerY.equalTo(titleLabel)
            make.width.equalTo(42)
            make.height.equalTo(18)
        }
    }
}

import SnapKit
import UIKit

@MainActor
final class RunQUIKitActivityDetailViewController: UIViewController {
    private let post: RunQPostRecord
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let navigationHeader = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let composer = UIView()
    private let commentField = UITextField()
    private let sendButton = UIButton(type: .custom)
    private let likeButton = UIButton(type: .custom)
    private var composerBottomConstraint: Constraint?
    private var comments: [RunQCommentRecord] = []
    private var isLiked = false
    private var isSending = false

    init(post: RunQPostRecord, dataStore: RunQDataStore, sessionStore: CynosureSessionStore) {
        self.post = post
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .runQUIKitBackground
        RunQAuroralTabBackdrop.install(in: view)
        configureNavigation()
        configureComposer()
        configureTable()
        configureKeyboard()
        reloadLikeState()
        reloadComments()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let header = tableView.tableHeaderView,
              abs(header.frame.width - tableView.bounds.width) > 0.5 else {
            return
        }
        header.frame.size.width = tableView.bounds.width
        tableView.tableHeaderView = header
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func configureNavigation() {
        view.addSubview(navigationHeader)
        navigationHeader.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top).offset(56)
        }

        let back = UIButton(type: .custom)
        back.setImage(UIImage(named: "runq_navigation_back"), for: .normal)
        back.accessibilityLabel = "Back"
        back.addAction(UIAction { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }, for: .touchUpInside)

        let title = UILabel()
        title.text = "SHARE NEWS"
        title.textColor = .white
        title.font = AppFont.passionOne(size: 27)
        title.textAlignment = .center

        let report = UIButton(type: .custom)
        report.setImage(UIImage(named: "runq_square_report"), for: .normal)
        report.accessibilityLabel = "Report"
        let canReport = post.authorID != sessionStore.currentUser?.id
        report.isHidden = !canReport
        report.isUserInteractionEnabled = canReport
        if canReport {
            report.addAction(
                UIAction { [weak self] _ in self?.showReport() },
                for: .touchUpInside
            )
        }

        [back, title, report].forEach(navigationHeader.addSubview)
        back.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-6)
            make.size.equalTo(44)
        }
        title.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(back)
        }
        report.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(back)
            make.size.equalTo(44)
        }
    }

    private func configureTable() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.keyboardDismissMode = .interactive
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            RunQActivityCommentCell.self,
            forCellReuseIdentifier: RunQActivityCommentCell.reuseIdentifier
        )
        let header = RunQActivityDetailHeaderView(
            post: post,
            currentUserID: sessionStore.currentUser?.id,
            dataStore: dataStore,
            onFollow: { [weak self] in self?.toggleFollowing() },
            onAvatar: { [weak self] in
                guard let self else { return }
                openUserProfile(self.post.authorID)
            }
        )
        header.frame = CGRect(
            x: 0,
            y: 0,
            width: view.bounds.width,
            height: RunQActivityDetailHeaderView.height
        )
        tableView.tableHeaderView = header
        view.insertSubview(tableView, belowSubview: navigationHeader)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(navigationHeader.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(composer.snp.top).offset(-10)
        }
    }

    private func configureComposer() {
        view.addSubview(composer)
        composer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(54)
            composerBottomConstraint = make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-12).constraint
        }

        likeButton.setImage(UIImage(named: "runq_home_like_idle"), for: .normal)
        likeButton.accessibilityLabel = "Like"
        likeButton.addAction(UIAction { [weak self] _ in self?.toggleLike() }, for: .touchUpInside)

        let fieldBackdrop = UIView()
        fieldBackdrop.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        fieldBackdrop.layer.cornerRadius = 27
        commentField.attributedPlaceholder = NSAttributedString(
            string: "Say something",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.52)]
        )
        commentField.textColor = .white
        commentField.font = AppFont.barlow(size: 15)
        commentField.returnKeyType = .send
        commentField.delegate = self
        commentField.accessibilityLabel = "Comment"
        sendButton.setImage(UIImage(named: "runq_activity_comment_send"), for: .normal)
        sendButton.accessibilityLabel = "Send comment"
        sendButton.addAction(UIAction { [weak self] _ in self?.submitComment() }, for: .touchUpInside)

        composer.addSubview(likeButton)
        composer.addSubview(fieldBackdrop)
        fieldBackdrop.addSubview(commentField)
        fieldBackdrop.addSubview(sendButton)
        likeButton.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(54)
        }
        fieldBackdrop.snp.makeConstraints { make in
            make.leading.equalTo(likeButton.snp.trailing).offset(7)
            make.trailing.top.bottom.equalToSuperview()
        }
        sendButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.size.equalTo(54)
        }
        commentField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalTo(sendButton.snp.leading).offset(-8)
            make.top.bottom.equalToSuperview()
        }
    }

    private func configureKeyboard() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameChanged(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private func reloadComments() {
        comments = dataStore.comments(
            for: post.id,
            visibleTo: sessionStore.currentUser?.id
        )
        (tableView.tableHeaderView as? RunQActivityDetailHeaderView)?
            .setCommentCount(max(post.commentCount, comments.count))
        tableView.reloadData()
    }

    private func toggleFollowing() {
        guard requireAccount() else { return }
        guard let currentUserID = sessionStore.currentUser?.id,
              currentUserID != post.authorID else { return }
        let follows = dataStore.isFollowing(sourceUserID: currentUserID, targetUserID: post.authorID)
        do {
            try dataStore.setFollowing(
                sourceUserID: currentUserID,
                targetUserID: post.authorID,
                isFollowing: !follows
            )
            (tableView.tableHeaderView as? RunQActivityDetailHeaderView)?.setFollowing(!follows)
        } catch {
            showToast("Unable to update this user.")
        }
    }

    private func openUserProfile(_ userID: String) {
        guard requireAccount() else { return }
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

    private func toggleLike() {
        guard requireAccount(),
              let userID = sessionStore.currentUser?.id else { return }
        let newValue = !isLiked
        do {
            try dataStore.setPostLiked(
                postID: post.id,
                userID: userID,
                isLiked: newValue
            )
            isLiked = newValue
            updateLikeAppearance()
        } catch {
            showToast("Unable to update this post.")
        }
    }

    private func reloadLikeState() {
        guard let userID = sessionStore.currentUser?.id else {
            isLiked = false
            updateLikeAppearance()
            return
        }
        isLiked = dataStore.isPostLiked(postID: post.id, userID: userID)
        updateLikeAppearance()
    }

    private func updateLikeAppearance() {
        likeButton.setImage(
            UIImage(named: isLiked ? "runq_home_like_selected" : "runq_home_like_idle"),
            for: .normal
        )
        likeButton.accessibilityValue = isLiked ? "Liked" : "Not liked"
    }

    private func submitComment() {
        guard !isSending else { return }
        guard requireAccount() else { return }
        let text = commentField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return }
        guard let userID = sessionStore.currentUser?.id else { return }
        isSending = true
        sendButton.isUserInteractionEnabled = false
        defer {
            isSending = false
            sendButton.isUserInteractionEnabled = true
        }
        do {
            try dataStore.addComment(postID: post.id, authorID: userID, text: text)
            commentField.text = nil
            dismissKeyboard()
            reloadComments()
            tableView.scrollToRow(
                at: IndexPath(row: comments.count - 1, section: 0),
                at: .bottom,
                animated: true
            )
        } catch {
            showToast("Unable to send this comment.")
        }
    }

    private func showReport() {
        guard requireAccount() else { return }
        guard post.authorID != sessionStore.currentUser?.id else { return }
        let dialog = RunQUIKitReportViewController()
        dialog.modalPresentationStyle = .overFullScreen
        dialog.onBlock = { [weak self] in
            guard let self, let userID = sessionStore.currentUser?.id else { return }
            do {
                try dataStore.setBlocked(
                    sourceUserID: userID,
                    targetUserID: post.authorID,
                    isBlocked: true
                )
                RunQToastPresenter.show(
                    "Added to blocked list.",
                    on: navigationController?.view ?? view
                )
                navigationController?.popViewController(animated: true)
            } catch {
                showToast("Unable to block this user.")
            }
        }
        present(dialog, animated: true)
    }

    @discardableResult
    private func requireAccount() -> Bool {
        runQUIKitRequireAccount(
            from: self,
            dataStore: dataStore,
            sessionStore: sessionStore
        )
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
            make.bottom.equalTo(composer.snp.top).offset(-12)
            make.height.equalTo(40)
            make.width.greaterThanOrEqualTo(180)
        }
        UIView.animate(withDuration: 0.2, delay: 1.6, options: .curveEaseIn) {
            toast.alpha = 0
        } completion: { _ in toast.removeFromSuperview() }
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let info = notification.userInfo,
              let endFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardFrame = view.convert(endFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
        let offset = -max(12, overlap - view.safeAreaInsets.bottom + 8)
        composerBottomConstraint?.update(offset: offset)
        let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curve << 16)
        ) {
            self.view.layoutIfNeeded()
        }
    }
}

extension RunQUIKitActivityDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        comments.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 78 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RunQActivityCommentCell.reuseIdentifier,
            for: indexPath
        ) as! RunQActivityCommentCell
        let comment = comments[indexPath.row]
        cell.configure(comment)
        cell.onAvatar = { [weak self] in
            guard let authorID = comment.authorID else { return }
            self?.openUserProfile(authorID)
        }
        return cell
    }
}

extension RunQUIKitActivityDetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submitComment()
        return false
    }
}

private final class RunQActivityDetailHeaderView: UIView,
    UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    static let height: CGFloat = 553
    static let imageCornerRadius: CGFloat = 12

    private let followButton = UIButton(type: .custom)
    private let commentCountLabel = UILabel()
    private let images: [UIImage]
    private let imageLayout = UICollectionViewFlowLayout()
    private lazy var imagePager = UICollectionView(
        frame: .zero,
        collectionViewLayout: imageLayout
    )
    private let pageControl = UIPageControl()

    init(
        post: RunQPostRecord,
        currentUserID: String?,
        dataStore: RunQDataStore,
        onFollow: @escaping () -> Void,
        onAvatar: @escaping () -> Void
    ) {
        let dataImages = post.imageDataItems.compactMap(UIImage.init(data:))
        if dataImages.isEmpty,
           let fallbackImage = UIImage(named: post.imageAssetName) {
            images = [fallbackImage]
        } else {
            images = dataImages
        }
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: Self.height))
        backgroundColor = .clear

        let avatar = UIImageView(image: UIImage(named: post.authorAvatarAssetName))
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 20
        let avatarButton = UIButton(type: .custom)
        avatarButton.accessibilityLabel = "Open author profile"
        avatarButton.isHidden = currentUserID == post.authorID
        avatarButton.addAction(
            UIAction { _ in onAvatar() },
            for: .touchUpInside
        )

        let author = UILabel()
        author.text = "@\(post.authorName.uppercased())"
        author.textColor = .white
        author.font = AppFont.barlow(size: 15)

        let date = UILabel()
        date.text = Self.postDateFormatter.string(from: post.createdAt)
        date.textColor = UIColor.white.withAlphaComponent(0.55)
        date.font = AppFont.barlow(size: 13)

        followButton.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        followButton.layer.cornerRadius = 16
        followButton.titleLabel?.font = AppFont.barlow(size: 14)
        followButton.setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .normal)
        followButton.addAction(UIAction { _ in onFollow() }, for: .touchUpInside)
        let isOwnPost = currentUserID == post.authorID
        followButton.isHidden = isOwnPost
        followButton.isUserInteractionEnabled = !isOwnPost
        setFollowing(
            currentUserID.map {
                dataStore.isFollowing(sourceUserID: $0, targetUserID: post.authorID)
            } ?? false
        )

        let message = UILabel()
        message.text = post.text
        message.textColor = .white
        message.font = AppFont.barlow(size: 14)
        message.numberOfLines = 2

        let tags = UIStackView()
        tags.axis = .horizontal
        tags.spacing = 8
        tags.distribution = .fill
        let tagTitles = post.tags.isEmpty
            ? ["#SurfingBuddies", "#OceanVibes", "#RidingTheWaves"]
            : Array(post.tags.prefix(3))
        tagTitles.forEach { tags.addArrangedSubview(Self.tagLabel($0)) }

        imageLayout.scrollDirection = .horizontal
        imageLayout.minimumLineSpacing = 0
        imageLayout.minimumInteritemSpacing = 0
        imagePager.backgroundColor = .clear
        imagePager.isPagingEnabled = true
        imagePager.decelerationRate = .fast
        imagePager.showsHorizontalScrollIndicator = false
        imagePager.contentInsetAdjustmentBehavior = .never
        imagePager.clipsToBounds = true
        imagePager.layer.cornerRadius = Self.imageCornerRadius
        imagePager.dataSource = self
        imagePager.delegate = self
        imagePager.register(
            RunQActivityDetailImageCell.self,
            forCellWithReuseIdentifier: RunQActivityDetailImageCell.reuseIdentifier
        )

        pageControl.numberOfPages = images.count
        pageControl.currentPage = 0
        pageControl.hidesForSinglePage = true
        pageControl.isHidden = images.count <= 1
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.45)
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.addAction(
            UIAction { [weak self] _ in self?.showSelectedPage() },
            for: .valueChanged
        )

        let commentTitle = UILabel()
        commentTitle.text = "COMMENT"
        commentTitle.textColor = .white
        commentTitle.font = AppFont.passionOne(size: 19)
        commentCountLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        commentCountLabel.font = AppFont.barlow(size: 15)

        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.28)
        let indicator = UIView()
        indicator.backgroundColor = UIColor(red: 1, green: 88 / 255, blue: 24 / 255, alpha: 1)
        indicator.layer.cornerRadius = 1.5

        [avatar, avatarButton, author, date, followButton, message, tags, imagePager, pageControl,
         commentTitle, commentCountLabel, divider, indicator].forEach(addSubview)
        avatar.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(20)
            make.size.equalTo(40)
        }
        avatarButton.snp.makeConstraints { make in make.edges.equalTo(avatar) }
        author.snp.makeConstraints { make in
            make.leading.equalTo(avatar.snp.trailing).offset(16)
            make.top.equalTo(avatar).offset(4)
        }
        date.snp.makeConstraints { make in
            make.leading.equalTo(author)
            make.top.equalTo(author.snp.bottom).offset(4)
        }
        followButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(avatar)
            make.width.equalTo(96)
            make.height.equalTo(32)
        }
        message.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(84)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        tags.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(139)
            make.leading.equalToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
            make.height.equalTo(28)
        }
        imagePager.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(179)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(314)
        }
        pageControl.snp.makeConstraints { make in
            make.centerX.equalTo(imagePager)
            make.bottom.equalTo(imagePager).offset(-4)
            make.height.equalTo(20)
        }
        commentTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalTo(imagePager.snp.bottom).offset(22)
        }
        commentCountLabel.snp.makeConstraints { make in
            make.leading.equalTo(commentTitle.snp.trailing).offset(16)
            make.centerY.equalTo(commentTitle)
        }
        divider.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
        indicator.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalTo(divider)
            make.width.equalTo(80)
            make.height.equalTo(3)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func setFollowing(_ isFollowing: Bool) {
        var attributes = AttributeContainer()
        attributes.font = AppFont.barlow(size: 14)
        attributes.foregroundColor = UIColor.white.withAlphaComponent(0.6)
        var configuration = UIButton.Configuration.plain()
        configuration.image = isFollowing ? nil : UIImage(named: "runq_activity_follow_add")
        configuration.attributedTitle = AttributedString(
            isFollowing ? "Following" : "Follow",
            attributes: attributes
        )
        configuration.imagePadding = 10
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: isFollowing ? 12 : 8,
            bottom: 0,
            trailing: 12
        )
        followButton.configuration = configuration
    }

    func setCommentCount(_ count: Int) {
        commentCountLabel.text = "(\(count))"
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        images.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RunQActivityDetailImageCell.reuseIdentifier,
            for: indexPath
        ) as! RunQActivityDetailImageCell
        cell.configure(image: images[indexPath.item])
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        collectionView.bounds.size
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === imagePager, scrollView.bounds.width > 0 else { return }
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        pageControl.currentPage = min(max(page, 0), max(images.count - 1, 0))
    }

    private func showSelectedPage() {
        guard images.indices.contains(pageControl.currentPage) else { return }
        imagePager.scrollToItem(
            at: IndexPath(item: pageControl.currentPage, section: 0),
            at: .centeredHorizontally,
            animated: true
        )
    }

    private static func tagLabel(_ title: String) -> UILabel {
        let label = RunQUIKitInsetLabel()
        label.textInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        label.text = title
        label.textColor = UIColor(red: 0.04, green: 0.98, blue: 0.76, alpha: 1)
        label.backgroundColor = UIColor(red: 0.03, green: 0.45, blue: 0.36, alpha: 0.45)
        label.font = AppFont.barlow(size: 12)
        label.textAlignment = .center
        label.layer.cornerRadius = 14
        label.clipsToBounds = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private static let postDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM,d   HH:mm:ss"
        return formatter
    }()
}

private final class RunQActivityDetailImageCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQActivityDetailImageCell"

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = RunQActivityDetailHeaderView.imageCornerRadius
        contentView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = RunQActivityDetailHeaderView.imageCornerRadius
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

private final class RunQActivityCommentCell: UITableViewCell {
    static let reuseIdentifier = "RunQActivityCommentCell"
    var onAvatar: (() -> Void)?
    private let avatar = UIImageView()
    private let author = UILabel()
    private let message = UILabel()
    private let time = UILabel()
    private let avatarButton = UIButton(type: .custom)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 20
        author.textColor = .white
        author.font = AppFont.barlow(size: 15)
        message.textColor = UIColor.white.withAlphaComponent(0.55)
        message.font = AppFont.barlow(size: 13)
        message.lineBreakMode = .byTruncatingTail
        time.textColor = UIColor.white.withAlphaComponent(0.55)
        time.font = AppFont.barlow(size: 13)
        time.textAlignment = .right
        avatarButton.accessibilityLabel = "Open commenter profile"
        avatarButton.addAction(
            UIAction { [weak self] _ in self?.onAvatar?() },
            for: .touchUpInside
        )
        [avatar, avatarButton, author, message, time].forEach(contentView.addSubview)
        avatar.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(14)
            make.size.equalTo(40)
        }
        avatarButton.snp.makeConstraints { make in make.edges.equalTo(avatar) }
        author.snp.makeConstraints { make in
            make.leading.equalTo(avatar.snp.trailing).offset(16)
            make.top.equalTo(avatar).offset(2)
            make.trailing.lessThanOrEqualTo(time.snp.leading).offset(-8)
        }
        message.snp.makeConstraints { make in
            make.leading.equalTo(author)
            make.top.equalTo(author.snp.bottom).offset(6)
            make.trailing.equalTo(time.snp.leading).offset(-12)
        }
        time.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(avatar)
            make.width.equalTo(46)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func prepareForReuse() {
        super.prepareForReuse()
        onAvatar = nil
    }

    func configure(_ comment: RunQCommentRecord) {
        avatar.image = UIImage(named: comment.authorAvatarAssetName)
        author.text = comment.authorName.uppercased()
        message.text = comment.text
        time.text = Self.timeFormatter.string(from: comment.createdAt)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "H:mm"
        return formatter
    }()
}

@preconcurrency import AVFoundation
import SnapKit
import UIKit

@MainActor
private final class RunQVideoFirstFrameProvider {
    static let shared = RunQVideoFirstFrameProvider()

    private let cache = NSCache<NSURL, UIImage>()
    private var pending: [URL: [(UIImage?) -> Void]] = [:]

    func image(for url: URL, completion: @escaping (UIImage?) -> Void) {
        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }
        if pending[url] != nil {
            pending[url]?.append(completion)
            return
        }
        pending[url] = [completion]

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 750, height: 1624)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let requestedTime = NSValue(time: .zero)
        generator.generateCGImagesAsynchronously(forTimes: [requestedTime]) {
            [weak self, generator] _, cgImage, _, result, _ in
            _ = generator
            let image = result == .succeeded
                ? cgImage.map(UIImage.init(cgImage:))
                : nil
            DispatchQueue.main.async {
                self?.finish(url: url, image: image)
            }
        }
    }

    private func finish(url: URL, image: UIImage?) {
        if let image {
            cache.setObject(image, forKey: url as NSURL)
        }
        let completions = pending.removeValue(forKey: url) ?? []
        completions.forEach { $0(image) }
    }
}

@MainActor
final class RunQUIKitReelViewController: UIViewController {
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let layout = UICollectionViewFlowLayout()
    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: layout
    )
    private let nearbyButton = UIButton(type: .custom)
    private let recommendButton = UIButton(type: .custom)
    private var selectedSection: RunQVideoFeedSection = .recommend
    private var reels: [RunQVideoRecord] = []
    private var isPlaybackActive = false
    private var isPlaybackRefreshScheduled = false
    private var delayedPlaybackRetry: DispatchWorkItem?

    init(dataStore: RunQDataStore, sessionStore: CynosureSessionStore) {
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    deinit {
        delayedPlaybackRetry?.cancel()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCollectionView()
        configureSectionSelector()
        reloadReels()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(socialDataDidChange),
            name: .runQSocialDataDidChange,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadReels()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setTabPlaybackActive(true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setTabPlaybackActive(false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scheduleVisiblePlayback()
    }

    @objc private func socialDataDidChange() {
        reloadReels()
        _ = playVisibleReel()
    }

    func setTabPlaybackActive(_ isActive: Bool) {
        isPlaybackActive = isActive
        delayedPlaybackRetry?.cancel()
        delayedPlaybackRetry = nil
        guard isViewLoaded else { return }
        if isActive {
            preparePlaybackSession()
            scheduleVisiblePlayback(remainingAttempts: 6)
            scheduleDelayedPlaybackRetry()
        } else {
            pauseVisibleReels()
        }
    }

    private func scheduleDelayedPlaybackRetry() {
        let retry = DispatchWorkItem { [weak self] in
            guard let self,
                  isPlaybackActive,
                  viewIfLoaded?.window != nil,
                  UIApplication.shared.applicationState == .active else { return }
            let hasPlayingVideo = collectionView.visibleCells
                .compactMap { $0 as? RunQReelCell }
                .contains { $0.isVideoActuallyPlaying }
            guard !hasPlayingVideo else { return }
            _ = playVisibleReel()
        }
        delayedPlaybackRetry = retry
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1,
            execute: retry
        )
    }

    private func preparePlaybackSession() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(
            .ambient,
            mode: .moviePlayback,
            options: [.mixWithOthers]
        )
        try? audioSession.setActive(true)
    }

    private func configureCollectionView() {
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        collectionView.backgroundColor = .black
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            RunQReelCell.self,
            forCellWithReuseIdentifier: RunQReelCell.reuseIdentifier
        )
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func reloadReels() {
        let currentUserID = sessionStore.currentUser?.id
        reels = dataStore.videoFeed(
            section: selectedSection,
            visibleTo: currentUserID
        )
        collectionView.reloadData()
        scheduleVisiblePlayback()
    }

    private func scheduleVisiblePlayback(remainingAttempts: Int = 3) {
        guard isPlaybackActive, !isPlaybackRefreshScheduled else { return }
        isPlaybackRefreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isPlaybackRefreshScheduled = false
            guard isPlaybackActive else { return }
            let didStartPlayback = playVisibleReel()
            guard !didStartPlayback, remainingAttempts > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                [weak self] in
                self?.scheduleVisiblePlayback(
                    remainingAttempts: remainingAttempts - 1
                )
            }
        }
    }

    @discardableResult
    private func playVisibleReel() -> Bool {
        guard viewIfLoaded?.window != nil else { return false }
        collectionView.layoutIfNeeded()
        let visibleCenter = CGPoint(
            x: collectionView.contentOffset.x + collectionView.bounds.midX,
            y: collectionView.contentOffset.y + collectionView.bounds.midY
        )
        let focusedIndexPath = collectionView.indexPathForItem(at: visibleCenter)
            ?? collectionView.indexPathsForVisibleItems.min { lhs, rhs in
                let lhsCenterY = collectionView
                    .layoutAttributesForItem(at: lhs)?.center.y
                    ?? visibleCenter.y
                let rhsCenterY = collectionView
                    .layoutAttributesForItem(at: rhs)?.center.y
                    ?? visibleCenter.y
                return abs(lhsCenterY - visibleCenter.y)
                    < abs(rhsCenterY - visibleCenter.y)
            }
        var didStartPlayback = false
        collectionView.visibleCells.forEach { visibleCell in
            guard let reelCell = visibleCell as? RunQReelCell else { return }
            if collectionView.indexPath(for: reelCell) == focusedIndexPath {
                didStartPlayback = reelCell.playVideo()
            } else {
                reelCell.pauseVideo()
            }
        }
        return didStartPlayback
    }

    private func pauseVisibleReels() {
        collectionView.visibleCells
            .compactMap { $0 as? RunQReelCell }
            .forEach { $0.pauseVideo() }
    }

    private func toggleLike(for videoID: String) {
        guard let user = sessionStore.currentUser,
              !user.isGuest else {
            showToast("Please sign in to like videos.")
            return
        }
        let newValue = !dataStore.isVideoLiked(
            videoID: videoID,
            userID: user.id
        )
        do {
            try dataStore.setVideoLiked(
                videoID: videoID,
                userID: user.id,
                isLiked: newValue
            )
            reloadReels()
        } catch {
            showToast("Unable to update this video.")
        }
    }

    private func configureSectionSelector() {
        configureSectionButton(nearbyButton, section: .nearby)
        configureSectionButton(recommendButton, section: .recommend)
        view.addSubview(nearbyButton)
        view.addSubview(recommendButton)

        nearbyButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(44)
            make.leading.equalToSuperview().offset(20)
            make.height.equalTo(40)
        }
        recommendButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(104)
            make.centerY.height.equalTo(nearbyButton)
        }
        updateSectionSelector()
    }

    private func configureSectionButton(
        _ button: UIButton,
        section: RunQVideoFeedSection
    ) {
        button.setTitle(section.title, for: .normal)
        button.accessibilityLabel = section.title
        button.addAction(UIAction { [weak self] _ in
            self?.selectSection(section)
        }, for: .touchUpInside)
    }

    private func selectSection(_ section: RunQVideoFeedSection) {
        guard selectedSection != section else { return }
        selectedSection = section
        updateSectionSelector()
        reloadReels()
        collectionView.setContentOffset(.zero, animated: false)
    }

    private func updateSectionSelector() {
        let buttons: [(UIButton, RunQVideoFeedSection)] = [
            (nearbyButton, .nearby),
            (recommendButton, .recommend)
        ]
        buttons.forEach { button, section in
            let isSelected = selectedSection == section
            button.setTitleColor(
                isSelected ? .white : UIColor.white.withAlphaComponent(0.56),
                for: .normal
            )
            button.titleLabel?.font = AppFont.barlow(
                size: isSelected ? 16 : 15,
                weight: isSelected ? .medium : .regular
            )
        }
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

    private func showToast(_ message: String) {
        RunQToastPresenter.show(message, on: navigationController?.view ?? view)
    }
}

extension RunQUIKitReelViewController:
    UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        collectionView.bounds.size
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        reels.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RunQReelCell.reuseIdentifier,
            for: indexPath
        ) as! RunQReelCell
        let reel = reels[indexPath.item]
        let currentUserID = sessionStore.currentUser?.id
        let targetUserID = reel.authorID
        let isCurrentUserContent = targetUserID == currentUserID
        let isLiked = currentUserID.map {
            dataStore.isVideoLiked(videoID: reel.id, userID: $0)
        } ?? false
        cell.configure(
            username: "@\(reel.authorName.uppercased())",
            caption: reel.caption,
            likeCount: reel.likeCount,
            commentCount: reel.commentCount,
            mediaFileName: reel.mediaFileName,
            sceneAssetName: reel.fallbackImageAssetName,
            avatarAssetName: reel.authorAvatarAssetName,
            isLiked: isLiked,
            showsReport: !isCurrentUserContent
        )
        cell.onLike = { [weak self] in
            self?.toggleLike(for: reel.id)
        }
        if isCurrentUserContent {
            cell.onReport = nil
        } else {
            cell.onReport = { [weak self] in
                guard let self else { return }
                guard let currentUserID = self.sessionStore.currentUser?.id,
                      targetUserID != currentUserID else { return }
                let controller = RunQUIKitReportViewController()
                controller.modalPresentationStyle = .overFullScreen
                controller.onBlock = { [weak self] in
                    guard let self else { return }
                    do {
                        try self.dataStore.setBlocked(
                            sourceUserID: currentUserID,
                            targetUserID: targetUserID,
                            isBlocked: true
                        )
                        self.showToast("Added to blocked list.")
                    } catch {
                        self.showToast("Unable to block this user.")
                    }
                }
                self.present(controller, animated: true)
            }
        }
        cell.onComments = { [weak self] in
            guard let self else { return }
            let comments = RunQVideoCommentsViewController(
                video: reel,
                dataStore: dataStore,
                sessionStore: sessionStore
            )
            comments.modalPresentationStyle = .overFullScreen
            comments.modalTransitionStyle = .crossDissolve
            comments.onCommentsChanged = { [weak self] in
                self?.reloadReels()
            }
            comments.onOpenProfile = { [weak self, weak comments] userID in
                comments?.dismiss(animated: true) {
                    self?.openUserProfile(userID)
                }
            }
            present(comments, animated: true)
        }
        cell.onAvatar = { [weak self] in
            self?.openUserProfile(targetUserID)
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard viewIfLoaded?.window != nil else { return }
        scheduleVisiblePlayback()
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        (cell as? RunQReelCell)?.pauseVideo()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        _ = playVisibleReel()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        _ = playVisibleReel()
    }
}

private final class RunQReelPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

private final class RunQReelCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQReelCell"

    var onReport: (() -> Void)?
    var onComments: (() -> Void)?
    var onAvatar: (() -> Void)?
    var onLike: (() -> Void)?

    private let sceneView = UIImageView()
    private let playerView = RunQReelPlayerView()
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private let topVeilView = UIImageView(
        image: UIImage(named: "runq_vespertine_reel_bottom_veil")
    )
    private let bottomVeilView = UIImageView(
        image: UIImage(named: "runq_umbriferous_reel_top_veil")
    )
    private let reportButton = UIButton(type: .custom)
    private let likeButton = UIButton(type: .custom)
    private let likeIconView = UIImageView()
    private let likeCountLabel = UILabel()
    private let commentButton = UIButton(type: .custom)
    private let commentIconView = UIImageView(
        image: UIImage(named: "runq_square_comment")
    )
    private let commentCountLabel = UILabel()
    private let avatarView = UIImageView()
    private let avatarButton = UIButton(type: .custom)
    private let followButton = UIButton(type: .custom)
    private let usernameLabel = UILabel()
    private let captionLabel = UILabel()
    private var baseLikeCount = 0
    private var isLiked = false
    private var isFollowing = false
    private var representedMediaFileName: String?
    private var shouldPlayWhenReady = false

    var isVideoActuallyPlaying: Bool {
        guard shouldPlayWhenReady, let queuePlayer else { return false }
        return queuePlayer.timeControlStatus == .playing && queuePlayer.rate > 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViews()
        configureConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onReport = nil
        onComments = nil
        onAvatar = nil
        onLike = nil
        isLiked = false
        isFollowing = false
        followButton.alpha = 1
        queuePlayer?.pause()
        queuePlayer = nil
        playerLooper = nil
        playerView.playerLayer.player = nil
        representedMediaFileName = nil
        shouldPlayWhenReady = false
        sceneView.image = nil
    }

    func configure(
        username: String,
        caption: String,
        likeCount: Int,
        commentCount: Int,
        mediaFileName: String,
        sceneAssetName: String,
        avatarAssetName: String,
        isLiked: Bool,
        showsReport: Bool
    ) {
        representedMediaFileName = mediaFileName
        configureMedia(
            fileName: mediaFileName,
            fallbackAssetName: sceneAssetName
        )
        avatarView.image = UIImage(named: avatarAssetName)
        usernameLabel.text = username
        captionLabel.text = caption
        self.isLiked = isLiked
        baseLikeCount = max(0, likeCount - (isLiked ? 1 : 0))
        likeCountLabel.text = "\(likeCount)"
        commentCountLabel.text = "\(commentCount)"
        reportButton.isHidden = !showsReport
        updateLikeAppearance()
    }

    @discardableResult
    func playVideo() -> Bool {
        shouldPlayWhenReady = true
        guard let queuePlayer else { return false }
        queuePlayer.playImmediately(atRate: 1)
        return true
    }

    func pauseVideo() {
        shouldPlayWhenReady = false
        queuePlayer?.pause()
    }

    private func configureMedia(fileName: String, fallbackAssetName: String) {
        let source = fileName as NSString
        let resource = source.deletingPathExtension
        let fileExtension = source.pathExtension
        guard !resource.isEmpty,
              !fileExtension.isEmpty,
              let url = Bundle.main.url(
                forResource: resource,
                withExtension: fileExtension
              ) else {
            sceneView.image = UIImage(named: fallbackAssetName)
            playerView.playerLayer.player = nil
            return
        }
        sceneView.image = nil
        RunQVideoFirstFrameProvider.shared.image(for: url) { [weak self] image in
            guard let self,
                  representedMediaFileName == fileName else { return }
            sceneView.image = image ?? UIImage(named: fallbackAssetName)
        }
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        queuePlayer = player
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        playerView.playerLayer.player = player
        if shouldPlayWhenReady {
            player.playImmediately(atRate: 1)
        }
    }

    private func configureViews() {
        clipsToBounds = true
        contentView.clipsToBounds = true
        sceneView.contentMode = .scaleAspectFill
        sceneView.clipsToBounds = true
        playerView.isUserInteractionEnabled = false
        playerView.backgroundColor = .clear
        playerView.playerLayer.videoGravity = .resizeAspectFill
        topVeilView.contentMode = .scaleToFill
        bottomVeilView.contentMode = .scaleToFill

        reportButton.setImage(UIImage(named: "runq_square_report"), for: .normal)
        reportButton.accessibilityLabel = "Report"
        reportButton.addAction(UIAction { [weak self] _ in
            self?.onReport?()
        }, for: .touchUpInside)

        likeButton.accessibilityLabel = "Like"
        likeButton.addAction(UIAction { [weak self] _ in
            self?.onLike?()
        }, for: .touchUpInside)

        commentButton.accessibilityLabel = "Comments"
        commentButton.addAction(UIAction { [weak self] _ in
            self?.onComments?()
        }, for: .touchUpInside)

        [likeCountLabel, commentCountLabel].forEach {
            $0.textColor = .white
            $0.textAlignment = .center
            $0.font = AppFont.barlow(size: 15)
        }

        likeIconView.contentMode = .scaleAspectFit
        commentIconView.contentMode = .scaleAspectFit
        likeButton.addSubview(likeIconView)
        commentButton.addSubview(commentIconView)

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 30
        avatarView.layer.borderWidth = 1
        avatarView.layer.borderColor = UIColor.white.cgColor
        avatarButton.accessibilityLabel = "Open author profile"
        avatarButton.addAction(
            UIAction { [weak self] _ in self?.onAvatar?() },
            for: .touchUpInside
        )

        followButton.setImage(UIImage(named: "runq_solaris_reel_follow"), for: .normal)
        followButton.accessibilityLabel = "Follow"
        followButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            isFollowing.toggle()
            followButton.alpha = isFollowing ? 0.55 : 1
        }, for: .touchUpInside)

        usernameLabel.textColor = .white
        usernameLabel.font = AppFont.barlow(size: 15)
        captionLabel.textColor = UIColor.white.withAlphaComponent(0.63)
        captionLabel.font = AppFont.barlow(size: 13)
        captionLabel.numberOfLines = 2

        [sceneView, playerView, topVeilView, bottomVeilView,
         reportButton, likeButton, likeCountLabel,
         commentButton, commentCountLabel, avatarView, avatarButton, followButton,
         usernameLabel, captionLabel].forEach(contentView.addSubview)
    }

    private func configureConstraints() {
        sceneView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(sceneView.snp.width).multipliedBy(812.0 / 375.0)
        }
        playerView.snp.makeConstraints { make in
            make.edges.equalTo(sceneView)
        }
        topVeilView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(topVeilView.snp.width).multipliedBy(98.0 / 375.0)
        }
        bottomVeilView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(714)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(bottomVeilView.snp.width).multipliedBy(136.0 / 375.0)
        }

        reportButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(40)
            make.trailing.equalToSuperview().offset(-10)
            make.size.equalTo(44)
        }

        likeButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(457)
            make.trailing.equalToSuperview().offset(-26)
            make.size.equalTo(40)
        }
        likeIconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-2)
            make.size.equalTo(46)
        }
        likeCountLabel.snp.makeConstraints { make in
            make.top.equalTo(likeButton.snp.bottom).offset(-2)
            make.centerX.equalTo(likeButton)
        }
        commentButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(556)
            make.centerX.equalTo(likeButton)
            make.size.equalTo(40)
        }
        commentIconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(3)
            make.size.equalTo(50)
        }
        commentCountLabel.snp.makeConstraints { make in
            make.top.equalTo(commentButton.snp.bottom).offset(3)
            make.centerX.equalTo(commentButton)
        }

    
        followButton.snp.makeConstraints { make in
            make.centerX.equalTo(avatarView)
            make.centerY.equalTo(avatarView.snp.bottom)
            make.size.equalTo(24)
        }
        usernameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(104)
            make.centerY.equalTo(avatarView)
        }
        captionLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-42)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalTo(captionLabel.snp.top).offset(-24)
            make.size.equalTo(60)
        }
        avatarButton.snp.makeConstraints { make in make.edges.equalTo(avatarView) }
    }

    private func updateLikeAppearance() {
        likeIconView.image = UIImage(
            named: isLiked ? "runq_home_like_selected" : "runq_home_like_idle"
        )
        likeCountLabel.text = "\(baseLikeCount + (isLiked ? 1 : 0))"
    }
}

@MainActor
private final class RunQVideoCommentsViewController: UIViewController,
    UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    var onCommentsChanged: (() -> Void)?
    var onOpenProfile: ((String) -> Void)?

    private let video: RunQVideoRecord
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let sheetView = UIView()
    private let titleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let composerView = UIView()
    private let messageField = UITextField()
    private let sendButton = UIButton(type: .custom)
    private let likeButton = UIButton(type: .custom)
    private var sheetHeightConstraint: Constraint?
    private var composerBottomConstraint: Constraint?
    private var comments: [RunQVideoCommentRecord] = []
    private var isSending = false
    private var isLiked = false

    init(
        video: RunQVideoRecord,
        dataStore: RunQDataStore,
        sessionStore: CynosureSessionStore
    ) {
        self.video = video
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
        configureBackdrop()
        configureSheet()
        configureHeader()
        configureComposer()
        configureTable()
        configureKeyboardHandling()
        reloadComments()
        reloadLikeState()
    }

    private func configureBackdrop() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.68)
        let dismissButton = UIButton(type: .custom)
        dismissButton.accessibilityLabel = "Close comments"
        dismissButton.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }, for: .touchUpInside)
        view.addSubview(dismissButton)
        dismissButton.snp.makeConstraints { make in make.edges.equalToSuperview() }

        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func configureSheet() {
        sheetView.backgroundColor = UIColor(
            red: 53 / 255,
            green: 53 / 255,
            blue: 57 / 255,
            alpha: 1
        )
        sheetView.layer.cornerRadius = 30
        sheetView.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner
        ]
        sheetView.clipsToBounds = true
        view.addSubview(sheetView)
        sheetView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            sheetHeightConstraint = make.height.equalTo(396).constraint
        }

        let grip = UIView()
        grip.backgroundColor = UIColor.white.withAlphaComponent(0.28)
        grip.layer.cornerRadius = 3
        sheetView.addSubview(grip)
        grip.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.centerX.equalToSuperview()
            make.size.equalTo(CGSize(width: 45, height: 6))
        }
    }

    private func configureHeader() {
        titleLabel.textColor = .white
        titleLabel.font = AppFont.barlow(size: 16, weight: .medium)
        sheetView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(28)
            make.leading.equalToSuperview().offset(22)
            make.height.equalTo(24)
        }
    }

    private func configureTable() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.keyboardDismissMode = .interactive
        tableView.rowHeight = 75
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            RunQVideoCommentCell.self,
            forCellReuseIdentifier: RunQVideoCommentCell.reuseIdentifier
        )
        sheetView.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(62)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(composerView.snp.top)
        }
    }

    private func configureComposer() {
        composerView.backgroundColor = UIColor(
            red: 14 / 255,
            green: 14 / 255,
            blue: 14 / 255,
            alpha: 1
        )
        sheetView.addSubview(composerView)
        composerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(106)
            composerBottomConstraint = make.bottom.equalToSuperview().constraint
        }

        likeButton.setImage(
            UIImage(named: "runq_home_like_idle"),
            for: .normal
        )
        likeButton.accessibilityLabel = "Like video"
        likeButton.addAction(UIAction { [weak self] _ in
            self?.toggleLike()
        }, for: .touchUpInside)

        let fieldContainer = UIView()
        fieldContainer.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        fieldContainer.layer.cornerRadius = 26

        messageField.textColor = .white
        messageField.tintColor = .white
        messageField.font = AppFont.barlow(size: 12)
        messageField.returnKeyType = .send
        messageField.delegate = self
        messageField.attributedPlaceholder = NSAttributedString(
            string: "Say something",
            attributes: [
                .foregroundColor: UIColor.white.withAlphaComponent(0.42)
            ]
        )

        sendButton.backgroundColor = UIColor(
            red: 1,
            green: 91 / 255,
            blue: 25 / 255,
            alpha: 1
        )
        sendButton.layer.cornerRadius = 27
        sendButton.setTitle("SEND", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = AppFont.passionOne(size: 17)
        sendButton.addAction(UIAction { [weak self] _ in
            self?.sendComment()
        }, for: .touchUpInside)

        composerView.addSubview(likeButton)
        composerView.addSubview(fieldContainer)
        fieldContainer.addSubview(messageField)
        fieldContainer.addSubview(sendButton)

        likeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(18)
            make.size.equalTo(40)
        }
        fieldContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(80)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalToSuperview().offset(18)
            make.height.equalTo(52)
        }
        sendButton.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            make.width.equalTo(54)
        }
        messageField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalTo(sendButton.snp.leading).offset(-8)
            make.top.bottom.equalToSuperview()
        }
    }

    private func configureKeyboardHandling() {
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
        comments = dataStore.videoComments(
            for: video.id,
            visibleTo: sessionStore.currentUser?.id
        )
        titleLabel.text = "COMMENT   (\(comments.count))"
        tableView.reloadData()
        guard !comments.isEmpty else { return }
        tableView.scrollToRow(
            at: IndexPath(row: comments.count - 1, section: 0),
            at: .bottom,
            animated: false
        )
    }

    private func sendComment() {
        guard !isSending else { return }
        let text = messageField.text?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        guard !text.isEmpty else {
            RunQToastPresenter.show("Please enter a comment.", on: view)
            return
        }
        guard let userID = sessionStore.currentUser?.id,
              sessionStore.currentUser?.isGuest != true else {
            RunQToastPresenter.show("Please sign in first.", on: view)
            return
        }
        isSending = true
        sendButton.isEnabled = false
        do {
            try dataStore.addVideoComment(
                videoID: video.id,
                authorID: userID,
                text: text
            )
            messageField.text = nil
            reloadComments()
            onCommentsChanged?()
            view.endEditing(true)
        } catch {
            RunQToastPresenter.show(
                "The comment could not be sent.",
                on: view
            )
        }
        isSending = false
        sendButton.isEnabled = true
    }

    private func toggleLike() {
        guard let user = sessionStore.currentUser,
              !user.isGuest else {
            RunQToastPresenter.show("Please sign in to like videos.", on: view)
            return
        }
        let newValue = !isLiked
        do {
            try dataStore.setVideoLiked(
                videoID: video.id,
                userID: user.id,
                isLiked: newValue
            )
            isLiked = newValue
            updateLikeAppearance()
            onCommentsChanged?()
        } catch {
            RunQToastPresenter.show("Unable to update this video.", on: view)
        }
    }

    private func reloadLikeState() {
        guard let user = sessionStore.currentUser,
              !user.isGuest else {
            isLiked = false
            updateLikeAppearance()
            return
        }
        isLiked = dataStore.isVideoLiked(videoID: video.id, userID: user.id)
        updateLikeAppearance()
    }

    private func updateLikeAppearance() {
        likeButton.setImage(
            UIImage(
                named: isLiked
                    ? "runq_home_like_selected"
                    : "runq_home_like_idle"
            ),
            for: .normal
        )
        likeButton.accessibilityValue = isLiked ? "Liked" : "Not liked"
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let info = notification.userInfo,
              let frame = info[UIResponder.keyboardFrameEndUserInfoKey]
                as? CGRect else { return }
        let converted = view.convert(frame, from: nil)
        let overlap = max(
            0,
            view.bounds.maxY - converted.minY - view.safeAreaInsets.bottom
        )
        let expandedHeight = min(
            view.bounds.height - 44,
            396 + overlap
        )
        sheetHeightConstraint?.update(offset: expandedHeight)
        composerBottomConstraint?.update(offset: -overlap)
        let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey]
            as? Double ?? 0.25
        let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey]
            as? UInt ?? 7
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curve << 16)
        ) {
            self.view.layoutIfNeeded()
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendComment()
        return false
    }

    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        comments.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RunQVideoCommentCell.reuseIdentifier,
            for: indexPath
        ) as! RunQVideoCommentCell
        let comment = comments[indexPath.row]
        let canOpenProfile = comment.authorID != nil
            && comment.authorID != sessionStore.currentUser?.id
        cell.configure(comment, isAvatarInteractive: canOpenProfile)
        cell.onAvatar = { [weak self] in
            guard let authorID = comment.authorID else { return }
            self?.onOpenProfile?(authorID)
        }
        return cell
    }
}

private final class RunQVideoCommentCell: UITableViewCell {
    static let reuseIdentifier = "RunQVideoCommentCell"

    var onAvatar: (() -> Void)?

    private let avatarView = UIImageView()
    private let avatarButton = UIButton(type: .custom)
    private let authorLabel = UILabel()
    private let messageLabel = UILabel()
    private let timeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 20
        authorLabel.textColor = .white
        authorLabel.font = AppFont.barlow(size: 14)
        messageLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        messageLabel.font = AppFont.barlow(size: 12)
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.numberOfLines = 1
        timeLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        timeLabel.font = AppFont.barlow(size: 11)
        timeLabel.textAlignment = .right

        [avatarView, avatarButton, authorLabel, messageLabel, timeLabel].forEach {
            contentView.addSubview($0)
        }
        avatarButton.accessibilityLabel = "Open profile"
        avatarButton.addAction(UIAction { [weak self] _ in
            self?.onAvatar?()
        }, for: .touchUpInside)
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(10)
            make.size.equalTo(40)
        }
        avatarButton.snp.makeConstraints { make in
            make.edges.equalTo(avatarView)
        }
        authorLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(16)
            make.top.equalTo(avatarView).offset(1)
            make.trailing.lessThanOrEqualTo(timeLabel.snp.leading).offset(-8)
        }
        messageLabel.snp.makeConstraints { make in
            make.leading.equalTo(authorLabel)
            make.top.equalTo(authorLabel.snp.bottom).offset(5)
            make.trailing.equalTo(timeLabel.snp.leading).offset(-10)
        }
        timeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(avatarView)
            make.width.equalTo(44)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onAvatar = nil
        avatarButton.isEnabled = false
        avatarButton.isAccessibilityElement = false
    }

    func configure(
        _ comment: RunQVideoCommentRecord,
        isAvatarInteractive: Bool
    ) {
        avatarView.image = UIImage(named: comment.authorAvatarAssetName)
        authorLabel.text = comment.authorName.uppercased()
        messageLabel.text = comment.text
        timeLabel.text = Self.timeFormatter.string(from: comment.createdAt)
        avatarButton.isEnabled = isAvatarInteractive
        avatarButton.isAccessibilityElement = isAvatarInteractive
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "H:mm"
        return formatter
    }()
}

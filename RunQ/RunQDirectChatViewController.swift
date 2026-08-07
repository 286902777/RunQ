import AVFoundation
import SnapKit
import UIKit

@MainActor
final class RunQDirectChatViewController: UIViewController {
    private let peer: RunQUserRecord
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let messageField = UITextField()
    private let sendButton = UIButton(type: .custom)
    private let composerView = UIView()
    private let recordButton = UIButton(type: .custom)
    private let recordingIndicator = RunQVoiceRecordingIndicatorView()
    private var composerHeightConstraint: Constraint?
    private var composerBottomConstraint: Constraint?
    private var messages: [RunQDirectMessageRecord] = []
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var player: AVAudioPlayer?
    private var playingMessageID: String?
    private var isVoiceMode = false
    private var isRecordPressActive = false
    private var isSending = false

    private lazy var messageCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 18
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 12, right: 20)
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.alwaysBounceVertical = true
        collection.keyboardDismissMode = .interactive
        collection.dataSource = self
        collection.delegate = self
        collection.register(
            RunQDirectMessageCell.self,
            forCellWithReuseIdentifier: RunQDirectMessageCell.reuseIdentifier
        )
        return collection
    }()

    init(
        peer: RunQUserRecord,
        dataStore: RunQDataStore,
        sessionStore: CynosureSessionStore
    ) {
        self.peer = peer
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
        configureComposer()
        configureMessages()
        configureKeyboardHandling()
        reloadMessages(scrollsToBottom: false)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(socialDataDidChange),
            name: .runQSocialDataDidChange,
            object: dataStore
        )
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--direct-chat-voice-preview") {
            DispatchQueue.main.async { [weak self] in self?.toggleVoiceMode() }
        }
        #endif
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard dataStore.isUserVisible(peer.id, to: activeUserID) else {
            navigationController?.popViewController(animated: true)
            return
        }
        reloadMessages(scrollsToBottom: false)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        recordingIndicator.hide(animated: false)
        recorder?.stop()
        player?.stop()
        recordingURL.flatMap { try? FileManager.default.removeItem(at: $0) }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func socialDataDidChange() {
        guard dataStore.isUserVisible(peer.id, to: activeUserID) else {
            view.endEditing(true)
            recordingIndicator.hide(animated: false)
            recorder?.stop()
            player?.stop()
            navigationController?.popViewController(animated: true)
            return
        }
        reloadMessages(scrollsToBottom: false)
    }

    private func configureNavigation() {
        let header = UIView()
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
        titleLabel.text = peer.username.uppercased()
        titleLabel.textColor = .white
        titleLabel.font = AppFont.passionOne(size: 22)

        let reportButton = UIButton(type: .custom)
        reportButton.setImage(UIImage(named: "runq_square_report"), for: .normal)
        reportButton.backgroundColor = UIColor(
            red: 42 / 255,
            green: 45 / 255,
            blue: 42 / 255,
            alpha: 1
        )
        reportButton.layer.cornerRadius = 22
        reportButton.accessibilityLabel = "More"
        let canReport = peer.id != sessionStore.currentUser?.id
        reportButton.isHidden = !canReport
        reportButton.isUserInteractionEnabled = canReport
        if canReport {
            reportButton.addAction(
                UIAction { [weak self] _ in self?.showReport() },
                for: .touchUpInside
            )
        }

        view.addSubview(header)
        [backButton, titleLabel, reportButton].forEach(header.addSubview)
        header.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top).offset(56)
        }
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-6)
            make.size.equalTo(44)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(backButton.snp.trailing).offset(10)
            make.centerY.equalTo(backButton)
        }
        reportButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalTo(backButton)
            make.size.equalTo(44)
        }
    }

    private func configureMessages() {
        view.addSubview(messageCollectionView)
        messageCollectionView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(104)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(composerView.snp.top).offset(-8)
        }
    }

    private func configureComposer() {
        composerView.backgroundColor = .runQUIKitBackground
        view.addSubview(composerView)
        composerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            composerHeightConstraint = make.height.equalTo(86).constraint
            composerBottomConstraint = make.bottom.equalTo(view.safeAreaLayoutGuide).constraint
        }

        let voiceModeButton = UIButton(type: .custom)
        voiceModeButton.setImage(
            UIImage(named: "runq_chatbox_input_microphone")?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        voiceModeButton.accessibilityLabel = "Voice message"
        voiceModeButton.addAction(
            UIAction { [weak self] _ in self?.toggleVoiceMode() },
            for: .touchUpInside
        )

        let fieldContainer = UIView()
        fieldContainer.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        fieldContainer.layer.cornerRadius = 29
        messageField.textColor = .white
        messageField.tintColor = .white
        messageField.font = AppFont.barlow(size: 15)
        messageField.attributedPlaceholder = NSAttributedString(
            string: "Say something",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.48)]
        )
        messageField.returnKeyType = .send
        messageField.delegate = self

        sendButton.backgroundColor = UIColor(
            red: 1,
            green: 91 / 255,
            blue: 25 / 255,
            alpha: 1
        )
        sendButton.layer.cornerRadius = 29
        sendButton.setTitle("SEND", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = AppFont.passionOne(size: 18)
        sendButton.addAction(
            UIAction { [weak self] _ in self?.sendTextMessage() },
            for: .touchUpInside
        )

        recordButton.setBackgroundImage(
            UIImage(named: "runq_ember_affinity_cta"),
            for: .normal
        )
        recordButton.setImage(
            UIImage(named: "runq_chatbox_input_microphone"),
            for: .normal
        )
        recordButton.imageView?.contentMode = .scaleAspectFit
        recordButton.layer.cornerRadius = 46
        recordButton.clipsToBounds = true
        recordButton.accessibilityLabel = "Hold to record"
        recordButton.alpha = 0
        recordButton.isHidden = true
        let holdGesture = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleRecordingGesture(_:))
        )
        holdGesture.minimumPressDuration = 0.15
        holdGesture.cancelsTouchesInView = false
        recordButton.addGestureRecognizer(holdGesture)

        [voiceModeButton, fieldContainer, recordButton].forEach(composerView.addSubview)
        [messageField, sendButton].forEach(fieldContainer.addSubview)
        voiceModeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(8)
            make.size.equalTo(40)
        }
        fieldContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(80)
            make.trailing.equalToSuperview().offset(-15)
            make.top.equalToSuperview().offset(4)
            make.height.equalTo(58)
        }
        sendButton.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
            make.width.equalTo(58)
        }
        messageField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalTo(sendButton.snp.leading).offset(-10)
            make.top.bottom.equalToSuperview()
        }
        recordButton.snp.makeConstraints { make in
            make.top.equalTo(fieldContainer.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
            make.size.equalTo(92)
        }
    }

    private func configureKeyboardHandling() {
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

    private func toggleVoiceMode() {
        setVoiceMode(!isVoiceMode)
    }

    private func setVoiceMode(
        _ isEnabled: Bool,
        endsEditing: Bool = true
    ) {
        guard isVoiceMode != isEnabled else { return }
        if endsEditing {
            view.endEditing(true)
        }
        if !isEnabled {
            isRecordPressActive = false
            finishRecording(sendsMessage: false)
        }
        isVoiceMode = isEnabled
        composerHeightConstraint?.update(offset: isEnabled ? 170 : 86)
        recordButton.isHidden = !isEnabled
        UIView.animate(withDuration: 0.22) {
            self.recordButton.alpha = isEnabled ? 1 : 0
            self.view.layoutIfNeeded()
        }
    }

    private func reloadMessages(scrollsToBottom: Bool) {
        guard let userID = activeUserID else {
            messages = []
            messageCollectionView.reloadData()
            return
        }
        messages = dataStore.directMessages(userID: userID, peerID: peer.id)
        messageCollectionView.reloadData()
        guard scrollsToBottom, !messages.isEmpty else { return }
        messageCollectionView.layoutIfNeeded()
        messageCollectionView.scrollToItem(
            at: IndexPath(item: messages.count - 1, section: 0),
            at: .bottom,
            animated: true
        )
    }

    private var activeUserID: String? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--direct-chat-preview")
            || ProcessInfo.processInfo.arguments.contains("--direct-chat-voice-preview") {
            return "seed-user-1"
        }
        #endif
        return sessionStore.currentUser?.id
    }

    private func sendTextMessage() {
        guard !isSending else { return }
        let text = messageField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            RunQToastPresenter.show("Please enter a message.", on: view)
            return
        }
        guard let userID = sessionStore.currentUser?.id else {
            RunQToastPresenter.show("Please sign in first.", on: view)
            return
        }
        isSending = true
        sendButton.isEnabled = false
        defer {
            isSending = false
            sendButton.isEnabled = true
        }
        do {
            try dataStore.sendDirectMessage(
                senderID: userID,
                receiverID: peer.id,
                text: text
            )
            messageField.text = nil
            view.endEditing(true)
            reloadMessages(scrollsToBottom: true)
        } catch {
            RunQToastPresenter.show("The message could not be sent.", on: view)
        }
    }

    @objc private func handleRecordingGesture(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            isRecordPressActive = true
            requestRecordingPermission()
        case .ended:
            isRecordPressActive = false
            finishRecording(sendsMessage: true)
        case .cancelled, .failed:
            isRecordPressActive = false
            finishRecording(sendsMessage: false)
        default:
            break
        }
    }

    private func requestRecordingPermission() {
        guard sessionStore.currentUser != nil else {
            RunQToastPresenter.show("Please sign in first.", on: view)
            return
        }
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            startRecording()
        case .denied:
            RunQToastPresenter.show("Microphone access is required.", on: view)
        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted, self.isRecordPressActive {
                        self.startRecording()
                    } else {
                        RunQToastPresenter.show("Microphone access is required.", on: self.view)
                    }
                }
            }
        @unknown default:
            RunQToastPresenter.show("Microphone access is unavailable.", on: view)
        }
    }

    private func startRecording() {
        guard recorder == nil, isRecordPressActive else { return }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("runq-voice-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 22_050,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            guard recorder.record() else { throw RunQDirectChatAudioError.recordingFailed }
            self.recorder = recorder
            recordingURL = url
            recordButton.alpha = 0.72
            recordButton.accessibilityLabel = "Recording"
            recordingIndicator.show(in: view)
        } catch {
            recorder = nil
            recordingURL = nil
            recordingIndicator.hide(animated: true)
            RunQToastPresenter.show("Recording could not start.", on: view)
        }
    }

    private func finishRecording(sendsMessage: Bool) {
        recordingIndicator.hide(animated: true)
        guard let recorder, let url = recordingURL else { return }
        let elapsedTime = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        recordingURL = nil
        recordButton.alpha = 1
        recordButton.accessibilityLabel = "Hold to record"
        defer { try? FileManager.default.removeItem(at: url) }
        let duration = (try? AVAudioPlayer(contentsOf: url).duration)
            .flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
            ?? elapsedTime
        guard sendsMessage, duration >= 0.25 else {
            if sendsMessage {
                RunQToastPresenter.show("Hold a little longer to record.", on: view)
            }
            return
        }
        guard let userID = sessionStore.currentUser?.id,
              let audioData = try? Data(contentsOf: url) else {
            RunQToastPresenter.show("The voice message could not be sent.", on: view)
            return
        }
        do {
            try dataStore.sendDirectVoiceMessage(
                senderID: userID,
                receiverID: peer.id,
                audioData: audioData,
                duration: duration
            )
            reloadMessages(scrollsToBottom: true)
        } catch {
            RunQToastPresenter.show("The voice message could not be sent.", on: view)
        }
    }

    private func playVoiceMessage(_ message: RunQDirectMessageRecord) {
        guard let audioData = message.audioData else { return }
        if playingMessageID == message.id {
            player?.stop()
            player = nil
            playingMessageID = nil
            messageCollectionView.reloadData()
            return
        }
        do {
            player?.stop()
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio)
            try audioSession.setActive(true)
            let player = try AVAudioPlayer(data: audioData)
            self.player = player
            playingMessageID = message.id
            player.play()
            messageCollectionView.reloadData()
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration) { [weak self] in
                guard self?.playingMessageID == message.id else { return }
                self?.playingMessageID = nil
                self?.player = nil
                self?.messageCollectionView.reloadData()
            }
        } catch {
            RunQToastPresenter.show("The voice message could not be played.", on: view)
        }
    }

    private func showReport() {
        guard let currentUserID = activeUserID,
              peer.id != currentUserID else { return }
        let report = RunQUIKitReportViewController()
        report.modalPresentationStyle = .overFullScreen
        report.onBlock = { [weak self] in
            guard let self else { return }
            do {
                try dataStore.setBlocked(
                    sourceUserID: currentUserID,
                    targetUserID: peer.id,
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
        present(report, animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let info = notification.userInfo,
              let keyboardFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let frame = view.convert(keyboardFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - frame.minY - view.safeAreaInsets.bottom)
        let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        composerBottomConstraint?.update(offset: -overlap)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curve << 16)
        ) {
            self.view.layoutIfNeeded()
        }
    }
}

extension RunQDirectChatViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if isVoiceMode {
            setVoiceMode(false, endsEditing: false)
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTextMessage()
        return false
    }
}

extension RunQDirectChatViewController: UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        messages.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RunQDirectMessageCell.reuseIdentifier,
            for: indexPath
        ) as! RunQDirectMessageCell
        let message = messages[indexPath.item]
        let isCurrentUser = message.senderID == activeUserID
        cell.configure(
            message: message,
            isCurrentUser: isCurrentUser,
            isPlaying: message.id == playingMessageID
        )
        cell.onAvatar = isCurrentUser ? nil : { [weak self] in
            guard let self else { return }
            navigationController?.popViewController(animated: true)
        }
        cell.onPlay = { [weak self] in self?.playVoiceMessage(message) }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(
            width: collectionView.bounds.width - 40,
            height: RunQDirectMessageCell.height(for: messages[indexPath.item])
        )
    }
}

private final class RunQDirectMessageCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQDirectMessageCell"
    static let messageFont = AppFont.barlow(size: 15)
    var onAvatar: (() -> Void)?
    var onPlay: (() -> Void)?

    private let avatar = UIImageView()
    private let avatarButton = UIButton(type: .custom)
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private let timeLabel = UILabel()
    private let playButton = UIButton(type: .custom)
    private let durationLabel = UILabel()
    private let waveformView = RunQVoiceWaveformView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 16
        avatarButton.accessibilityLabel = "Open message author profile"
        avatarButton.addAction(
            UIAction { [weak self] _ in self?.onAvatar?() },
            for: .touchUpInside
        )
        bubbleView.layer.cornerRadius = 16
        messageLabel.textColor = .white
        messageLabel.font = Self.messageFont
        messageLabel.numberOfLines = 0
        timeLabel.textColor = UIColor.white.withAlphaComponent(0.48)
        timeLabel.font = AppFont.barlow(size: 14)
        playButton.tintColor = .white
        playButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        playButton.layer.cornerRadius = 18
        playButton.addAction(
            UIAction { [weak self] _ in self?.onPlay?() },
            for: .touchUpInside
        )
        durationLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        durationLabel.font = AppFont.barlow(size: 12, weight: .medium)
        durationLabel.textAlignment = .right
        [avatar, avatarButton, bubbleView, timeLabel].forEach(contentView.addSubview)
        [messageLabel, playButton, waveformView, durationLabel].forEach(bubbleView.addSubview)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onAvatar = nil
        onPlay = nil
    }

    func configure(
        message: RunQDirectMessageRecord,
        isCurrentUser: Bool,
        isPlaying: Bool
    ) {
        let isVoice = message.audioData != nil
        avatar.image = UIImage(named: message.senderAvatarAssetName)
        avatar.isHidden = isCurrentUser
        avatarButton.isHidden = isCurrentUser
        bubbleView.backgroundColor = isCurrentUser
            ? UIColor(red: 1, green: 91 / 255, blue: 25 / 255, alpha: 1)
            : UIColor(red: 47 / 255, green: 47 / 255, blue: 52 / 255, alpha: 1)
        messageLabel.text = message.text
        messageLabel.isHidden = isVoice
        [playButton, waveformView, durationLabel].forEach { $0.isHidden = !isVoice }
        playButton.setImage(
            UIImage(
                systemName: isPlaying ? "pause.fill" : "play.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
            ),
            for: .normal
        )
        playButton.accessibilityLabel = isPlaying ? "Pause voice message" : "Play voice message"
        durationLabel.text = Self.voiceDurationText(message.audioDuration)
        waveformView.configure(isPlaying: isPlaying)
        timeLabel.text = Self.timeFormatter.string(from: message.createdAt).lowercased()

        avatar.snp.remakeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalToSuperview()
            make.size.equalTo(32)
        }
        avatarButton.snp.remakeConstraints { make in make.edges.equalTo(avatar) }
        bubbleView.snp.remakeConstraints { make in
            make.top.equalToSuperview()
            make.width.equalTo(isVoice ? 218 : 280)
            if isVoice {
                make.height.equalTo(60)
            }
            if isCurrentUser {
                make.leading.greaterThanOrEqualToSuperview().offset(58)
                make.trailing.equalToSuperview()
            } else {
                make.leading.equalToSuperview().offset(40)
                make.trailing.lessThanOrEqualToSuperview()
            }
        }
        messageLabel.snp.remakeConstraints { make in
            make.edges.equalToSuperview().inset(
                UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
            )
        }
        playButton.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(36)
        }
        waveformView.snp.remakeConstraints { make in
            make.leading.equalTo(playButton.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.width.equalTo(96)
            make.height.equalTo(26)
        }
        durationLabel.snp.remakeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.width.equalTo(48)
        }
        timeLabel.textAlignment = isCurrentUser ? .left : .right
        timeLabel.snp.remakeConstraints { make in
            make.top.equalTo(bubbleView.snp.bottom).offset(8)
            if isCurrentUser {
                make.leading.equalTo(bubbleView)
            } else {
                make.trailing.equalTo(bubbleView)
            }
        }
    }

    static func height(for message: RunQDirectMessageRecord) -> CGFloat {
        guard message.audioData == nil else { return 90 }
        let textHeight = ceil(
            (message.text as NSString).boundingRect(
                with: CGSize(
                    width: 248,
                    height: CGFloat.greatestFiniteMagnitude
                ),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: messageFont],
                context: nil
            ).height
        )
        return max(64, textHeight + 32) + 30
    }

    private static func voiceDurationText(_ duration: TimeInterval) -> String {
        let safeDuration = max(0, duration)
        if safeDuration < 60 {
            return String(format: "%.1fs", safeDuration)
        }
        let minutes = Int(safeDuration) / 60
        let seconds = safeDuration - Double(minutes * 60)
        return String(format: "%d:%04.1f", minutes, seconds)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h: mm a"
        return formatter
    }()
}

final class RunQVoiceWaveformView: UIView {
    private static let heights: [CGFloat] = [
        0.34, 0.58, 0.82, 0.48, 1, 0.68,
        0.42, 0.74, 0.92, 0.54, 0.78, 0.38
    ]
    private let bars = heights.map { _ in UIView() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        bars.forEach {
            $0.layer.cornerRadius = 1.5
            addSubview($0)
        }
        configure(isPlaying: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let step = bounds.width / CGFloat(bars.count)
        let barWidth = min(3, step * 0.46)
        for (index, bar) in bars.enumerated() {
            let height = max(4, bounds.height * Self.heights[index])
            bar.frame = CGRect(
                x: step * CGFloat(index) + (step - barWidth) / 2,
                y: (bounds.height - height) / 2,
                width: barWidth,
                height: height
            )
        }
    }

    func configure(isPlaying: Bool) {
        for (index, bar) in bars.enumerated() {
            let emphasized = isPlaying && index < bars.count / 2
            bar.backgroundColor = UIColor.white.withAlphaComponent(
                emphasized ? 1 : 0.68
            )
        }
    }
}

private enum RunQDirectChatAudioError: Error {
    case recordingFailed
}

import AVFoundation
import SnapKit
import UIKit

@MainActor
final class RunQChatRoomViewController: UIViewController {
    private struct VoiceParticipant {
        let name: String
        let avatarAssetName: String?
        let avatarData: Data?
        let isOpenSeat: Bool
    }

    private enum MessageItem {
        case announcement(String)
        case message(RunQChatMessageRecord)
    }

    private let room: RunQChatRoomRecord
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let messageField = UITextField()
    private let sendButton = UIButton(type: .custom)
    private let recordButton = UIButton(type: .custom)
    private let composerView = UIView()
    private let recordingIndicator = RunQVoiceRecordingIndicatorView()
    private let tealParticipantCountLabel = UILabel()
    private let orangeParticipantCountLabel = UILabel()
    private let speakerAvatar = UIImageView()
    private let speakerNameLabel = UILabel()
    private var composerBottomConstraint: Constraint?
    private var messageItems: [MessageItem] = []
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var player: AVAudioPlayer?
    private var playingMessageID: String?
    private var isRecordPressActive = false
    private var isSending = false

    private var participants: [VoiceParticipant] = []

    private lazy var participantCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 14
        layout.minimumInteritemSpacing = 8
        layout.itemSize = CGSize(width: 76, height: 100)
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.dataSource = self
        view.delegate = self
        view.register(RunQVoiceParticipantCell.self, forCellWithReuseIdentifier: RunQVoiceParticipantCell.reuseIdentifier)
        return view
    }()

    private lazy var messageCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 17
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 8, right: 20)
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        view.dataSource = self
        view.delegate = self
        view.register(RunQChatAnnouncementCell.self, forCellWithReuseIdentifier: RunQChatAnnouncementCell.reuseIdentifier)
        view.register(RunQChatMessageCell.self, forCellWithReuseIdentifier: RunQChatMessageCell.reuseIdentifier)
        view.register(RunQChatVoiceMessageCell.self, forCellWithReuseIdentifier: RunQChatVoiceMessageCell.reuseIdentifier)
        return view
    }()

    init(room: RunQChatRoomRecord, dataStore: RunQDataStore, sessionStore: CynosureSessionStore) {
        self.room = room
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
        reloadParticipants()
        configureBackground()
        configureNavigationAndRoomSummary()
        configureVoiceArea()
        configureComposer()
        configureMessages()
        configureKeyboardHandling()
        reloadMessages()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard dataStore.isUserVisible(
            room.createdBy,
            to: sessionStore.currentUser?.id
        ) else {
            navigationController?.popViewController(animated: true)
            return
        }
        reloadParticipants()
        reloadMessages()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        recordingIndicator.hide(animated: false)
        recorder?.stop()
        recorder = nil
        player?.stop()
        player = nil
        playingMessageID = nil
        recordingURL.flatMap { try? FileManager.default.removeItem(at: $0) }
        recordingURL = nil
        isRecordPressActive = false
        recordButton.alpha = 1
        recordButton.accessibilityLabel = "Hold to record"
    }

    private func configureBackground() {
        let background = RunQChatRoomBackdropView()
        view.addSubview(background)
        background.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func configureNavigationAndRoomSummary() {
        let backButton = UIButton(type: .custom)
        backButton.setImage(UIImage(named: "runq_navigation_back"), for: .normal)
        backButton.accessibilityLabel = "Back"
        backButton.addAction(UIAction { [weak self] _ in self?.navigationController?.popViewController(animated: true) }, for: .touchUpInside)

        let tealBadge = participantBadge(
            assetName: "runq_square_participant_teal",
            countLabel: tealParticipantCountLabel
        )
        let orangeBadge = participantBadge(
            assetName: "runq_square_participant_orange",
            countLabel: orangeParticipantCountLabel
        )
        let reportButton = UIButton(type: .custom)
        reportButton.setImage(UIImage(named: "runq_square_report"), for: .normal)
        reportButton.accessibilityLabel = "More"
        let canReport = room.createdBy != sessionStore.currentUser?.id
        reportButton.isHidden = !canReport
        reportButton.isUserInteractionEnabled = canReport
        if canReport {
            reportButton.addAction(
                UIAction { [weak self] _ in self?.showReportOptions() },
                for: .touchUpInside
            )
        }

        let summary = UIView()
        summary.backgroundColor = UIColor(red: 91 / 255, green: 75 / 255, blue: 159 / 255, alpha: 0.58)
        summary.layer.cornerRadius = 16
        let avatar = makeAvatar(
            assetName: room.ownerAvatarAssetName,
            data: room.resolvedAvatarData
        )
        avatar.layer.cornerRadius = 12
        let titleLabel = UILabel()
        titleLabel.text = room.name.lowercased().capitalized
        titleLabel.textColor = .white
        titleLabel.font = AppFont.barlow(size: 14)
        titleLabel.numberOfLines = 1
        let idLabel = UILabel()
        idLabel.text = "Box ID:  \(room.id)"
        idLabel.textColor = UIColor.white.withAlphaComponent(0.46)
        idLabel.font = AppFont.barlow(size: 11)

        [backButton, tealBadge, orangeBadge, reportButton, summary].forEach(view.addSubview)
        [avatar, titleLabel, idLabel].forEach(summary.addSubview)

        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(18)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(5)
            make.size.equalTo(44)
        }
        if canReport {
            reportButton.snp.makeConstraints { make in
                make.trailing.equalToSuperview().inset(17)
                make.centerY.equalTo(backButton)
                make.size.equalTo(36)
            }
            orangeBadge.snp.makeConstraints { make in
                make.trailing.equalTo(reportButton.snp.leading).offset(-10)
                make.centerY.equalTo(backButton)
                make.size.equalTo(CGSize(width: 50, height: 30))
            }
        } else {
            orangeBadge.snp.makeConstraints { make in
                make.trailing.equalToSuperview().inset(17)
                make.centerY.equalTo(backButton)
                make.size.equalTo(CGSize(width: 50, height: 30))
            }
        }
        tealBadge.snp.makeConstraints { make in
            make.trailing.equalTo(orangeBadge.snp.leading).offset(-10)
            make.centerY.equalTo(backButton)
            make.size.equalTo(CGSize(width: 50, height: 30))
        }
        summary.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(54)
            make.width.equalTo(227)
            make.height.equalTo(56)
        }
        avatar.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.size.equalTo(40)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatar.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(8)
            make.top.equalToSuperview().offset(10)
        }
        idLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(1)
        }
    }

    private func configureVoiceArea() {
        let owner = dataStore.user(id: room.createdBy)
            ?? dataStore.chatRoomMembers(
                roomID: room.id,
                visibleTo: sessionStore.currentUser?.id
            ).first
        speakerAvatar.image = owner.flatMap { user in
            dataStore.profileDetails(for: user.id).avatarData.flatMap(UIImage.init(data:))
                ?? UIImage(named: user.avatarAssetName)
        }
        speakerAvatar.contentMode = .scaleAspectFill
        speakerAvatar.clipsToBounds = true
        speakerAvatar.layer.cornerRadius = 35
        speakerAvatar.layer.borderWidth = 2
        speakerAvatar.layer.borderColor = UIColor(red: 1, green: 91 / 255, blue: 25 / 255, alpha: 1).cgColor
        let microphone = UIImageView(image: UIImage(named: "runq_chatbox_speaker_microphone"))
        microphone.contentMode = .scaleAspectFit
        speakerNameLabel.text = owner?.username ?? "Host"
        speakerNameLabel.textColor = .white
        speakerNameLabel.font = AppFont.barlow(size: 16)
        speakerNameLabel.textAlignment = .center

        [speakerAvatar, microphone, speakerNameLabel, participantCollectionView].forEach(view.addSubview)
        speakerAvatar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(128)
            make.centerX.equalToSuperview()
            make.size.equalTo(70)
        }
        microphone.snp.makeConstraints { make in
            make.trailing.equalTo(speakerAvatar).offset(1)
            make.bottom.equalTo(speakerAvatar).offset(1)
            make.size.equalTo(20)
        }
        speakerNameLabel.snp.makeConstraints { make in
            make.top.equalTo(speakerAvatar.snp.bottom).offset(13)
            make.centerX.equalToSuperview()
        }
        participantCollectionView.snp.makeConstraints { make in
            make.top.equalTo(speakerNameLabel.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(210)
        }
    }

    private func configureMessages() {
        view.addSubview(messageCollectionView)
        messageCollectionView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(474)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(composerView.snp.top).offset(-6)
        }
    }

    private func configureComposer() {
        composerView.backgroundColor = UIColor(red: 14 / 255, green: 14 / 255, blue: 17 / 255, alpha: 0.94)
        view.addSubview(composerView)
        composerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(70)
            composerBottomConstraint = make.bottom.equalTo(view.safeAreaLayoutGuide).constraint
        }

        let fieldContainer = UIView()
        fieldContainer.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        fieldContainer.layer.cornerRadius = 25
        messageField.textColor = .white
        messageField.tintColor = .white
        messageField.font = AppFont.barlow(size: 12)
        messageField.attributedPlaceholder = NSAttributedString(
            string: "Say something",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.42)]
        )
        messageField.returnKeyType = .send
        messageField.delegate = self

        sendButton.backgroundColor = UIColor(red: 1, green: 91 / 255, blue: 25 / 255, alpha: 1)
        sendButton.layer.cornerRadius = 25
        sendButton.setTitle("SEND", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = AppFont.passionOne(size: 17)
        sendButton.addAction(UIAction { [weak self] _ in self?.sendMessage() }, for: .touchUpInside)

        recordButton.setImage(UIImage(named: "runq_chatbox_input_microphone"), for: .normal)
        recordButton.accessibilityLabel = "Hold to record"
        let holdGesture = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleRecordingGesture(_:))
        )
        holdGesture.minimumPressDuration = 0.15
        holdGesture.cancelsTouchesInView = false
        recordButton.addGestureRecognizer(holdGesture)

        [fieldContainer, recordButton].forEach(composerView.addSubview)
        fieldContainer.addSubview(messageField)
        fieldContainer.addSubview(sendButton)
        fieldContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(4)
            make.height.equalTo(52)
            make.trailing.equalTo(recordButton.snp.leading).offset(-18)
        }
        recordButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20)
            make.centerY.equalTo(fieldContainer)
            make.size.equalTo(40)
        }
        sendButton.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
            make.width.equalTo(54)
        }
        messageField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(19)
            make.trailing.equalTo(sendButton.snp.leading).offset(-8)
            make.top.bottom.equalToSuperview()
        }
    }

    private func configureKeyboardHandling() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameChanged(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameChanged(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func participantBadge(assetName: String, countLabel: UILabel) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        view.layer.cornerRadius = 15
        let icon = UIImageView(image: UIImage(named: assetName))
        icon.contentMode = .scaleAspectFit
        countLabel.textColor = .white
        countLabel.font = AppFont.barlow(size: 12)
        [icon, countLabel].forEach(view.addSubview)
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.size.equalTo(14)
        }
        countLabel.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(5)
            make.centerY.equalToSuperview()
        }
        return view
    }

    private func reloadParticipants() {
        let members = dataStore.chatRoomMembers(
            roomID: room.id,
            visibleTo: sessionStore.currentUser?.id
        )
        participants = members.prefix(8).map { member in
            VoiceParticipant(
                name: member.username,
                avatarAssetName: member.avatarAssetName,
                avatarData: dataStore.profileDetails(for: member.id).avatarData,
                isOpenSeat: false
            )
        }
        let openSeatCount = max(
            0,
            min(8, room.participantLimit) - participants.count
        )
        participants.append(contentsOf: (0..<openSeatCount).map { _ in
            VoiceParticipant(
                name: "Sit down",
                avatarAssetName: nil,
                avatarData: nil,
                isOpenSeat: true
            )
        })
        tealParticipantCountLabel.text = "\(members.filter { $0.gender.lowercased() == "male" }.count)"
        orangeParticipantCountLabel.text = "\(members.filter { $0.gender.lowercased() == "female" }.count)"
        participantCollectionView.reloadData()
    }

    private func makeAvatar(assetName: String, data: Data?) -> UIImageView {
        let view = UIImageView(image: data.flatMap(UIImage.init(data:)) ?? UIImage(named: assetName))
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }

    private func reloadMessages() {
        messageItems = [
            .announcement("\"Welcome to the ChatBox! Join the conversation and connect with others. Let's chat and create a lively community together!\"")
        ]
        messageItems.append(contentsOf: dataStore.chatMessages(
            roomID: room.id,
            visibleTo: sessionStore.currentUser?.id
        ).map(MessageItem.message))
        messageCollectionView.reloadData()
        DispatchQueue.main.async { [weak self] in self?.scrollToLatestMessage() }
    }

    private func sendMessage() {
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
        do {
            try dataStore.sendChatMessage(roomID: room.id, authorID: userID, text: text)
            messageField.text = nil
            reloadMessages()
            view.endEditing(true)
        } catch {
            RunQToastPresenter.show("The message could not be sent.", on: view)
        }
        isSending = false
        sendButton.isEnabled = true
    }

    @objc private func handleRecordingGesture(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            isRecordPressActive = true
            view.endEditing(true)
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
                    } else if !granted {
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
            try audioSession.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker]
            )
            try audioSession.setActive(true)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("runq-room-voice-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 22_050,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            guard recorder.record() else { throw RunQChatRoomAudioError.recordingFailed }
            self.recorder = recorder
            recordingURL = url
            recordButton.alpha = 0.55
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
            try dataStore.sendChatVoiceMessage(
                roomID: room.id,
                authorID: userID,
                audioData: audioData,
                duration: duration
            )
            reloadMessages()
        } catch {
            RunQToastPresenter.show("The voice message could not be sent.", on: view)
        }
    }

    private func playVoiceMessage(_ message: RunQChatMessageRecord) {
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

    private func scrollToLatestMessage() {
        guard !messageItems.isEmpty else { return }
        messageCollectionView.scrollToItem(at: IndexPath(item: messageItems.count - 1, section: 0), at: .bottom, animated: false)
    }

    private func showReportOptions() {
        guard let currentUserID = sessionStore.currentUser?.id,
              room.createdBy != currentUserID else { return }
        let report = RunQUIKitReportViewController()
        report.modalPresentationStyle = .overFullScreen
        report.onBlock = { [weak self] in
            guard let self else { return }
            do {
                try dataStore.setBlocked(
                    sourceUserID: currentUserID,
                    targetUserID: room.createdBy,
                    isBlocked: true
                )
                RunQToastPresenter.show(
                    "Added to blocked list.",
                    on: navigationController?.view ?? view
                )
                navigationController?.popViewController(animated: true)
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
              let keyboardFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let converted = view.window?.convert(keyboardFrame, to: view)
            ?? view.convert(keyboardFrame, from: nil)
        let coveredHeight = converted.intersects(view.bounds)
            ? view.bounds.intersection(converted).height
            : 0
        let overlap = max(0, coveredHeight - view.safeAreaInsets.bottom)
        let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        composerBottomConstraint?.update(offset: -overlap)
        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curve << 16)) {
            self.view.layoutIfNeeded()
        } completion: { _ in
            if overlap > 0 {
                self.scrollToLatestMessage()
            }
        }
    }
}

extension RunQChatRoomViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendMessage()
        return false
    }

    private func openUserProfile(_ userID: String) {
        guard userID != sessionStore.currentUser?.id,
              dataStore.isUserVisible(userID, to: sessionStore.currentUser?.id),
              dataStore.user(id: userID) != nil else { return }
        let page = RunQUIKitOtherProfileViewController(
            title: "PROFILE",
            dataStore: dataStore,
            sessionStore: sessionStore,
            userID: userID
        )
        navigationController?.pushViewController(page, animated: true)
    }
}

extension RunQChatRoomViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard let touchedView = touch.view else { return true }
        return !touchedView.isDescendant(of: composerView)
    }
}

extension RunQChatRoomViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        collectionView === participantCollectionView ? participants.count : messageItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView === participantCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RunQVoiceParticipantCell.reuseIdentifier, for: indexPath) as! RunQVoiceParticipantCell
            let participant = participants[indexPath.item]
            cell.configure(
                name: participant.name,
                avatarAssetName: participant.avatarAssetName,
                avatarData: participant.avatarData,
                isOpenSeat: participant.isOpenSeat
            )
            return cell
        }
        switch messageItems[indexPath.item] {
        case .announcement(let text):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RunQChatAnnouncementCell.reuseIdentifier, for: indexPath) as! RunQChatAnnouncementCell
            cell.configure(text: text)
            return cell
        case .message(let message):
            if message.audioData != nil {
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: RunQChatVoiceMessageCell.reuseIdentifier,
                    for: indexPath
                ) as! RunQChatVoiceMessageCell
                let isCurrentUser = message.authorID == sessionStore.currentUser?.id
                cell.configure(
                    message: message,
                    isCurrentUser: isCurrentUser,
                    isPlaying: message.id == playingMessageID
                )
                cell.onAvatar = isCurrentUser ? nil : { [weak self] in
                    self?.openUserProfile(message.authorID)
                }
                cell.onPlay = { [weak self] in self?.playVoiceMessage(message) }
                return cell
            }
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RunQChatMessageCell.reuseIdentifier, for: indexPath) as! RunQChatMessageCell
            let isCurrentUser = message.authorID == sessionStore.currentUser?.id
            cell.configure(message: message, isCurrentUser: isCurrentUser)
            cell.onAvatar = isCurrentUser ? nil : { [weak self] in
                self?.openUserProfile(message.authorID)
            }
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView === participantCollectionView { return CGSize(width: 76, height: 100) }
        switch messageItems[indexPath.item] {
        case .announcement:
            return CGSize(width: collectionView.bounds.width - 40, height: 92)
        case .message(let message):
            if message.audioData != nil {
                return CGSize(width: collectionView.bounds.width - 40, height: 78)
            }
            let textWidth = min(245, max(104, (message.text as NSString).size(withAttributes: [.font: AppFont.barlow(size: 11)]).width + 38))
            return CGSize(width: collectionView.bounds.width - 40, height: 64 + max(0, textWidth > 220 ? 16 : 0))
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard collectionView === participantCollectionView, participants[indexPath.item].isOpenSeat else { return }
        RunQToastPresenter.show("You are now seated.", on: view)
    }
}

private final class RunQChatVoiceMessageCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQChatVoiceMessageCell"
    var onAvatar: (() -> Void)?
    var onPlay: (() -> Void)?

    private let avatar = UIImageView()
    private let avatarButton = UIButton(type: .custom)
    private let authorLabel = UILabel()
    private let bubbleView = UIView()
    private let playButton = UIButton(type: .custom)
    private let waveformView = RunQVoiceWaveformView()
    private let durationLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 11
        avatarButton.accessibilityLabel = "Open message author profile"
        avatarButton.addAction(
            UIAction { [weak self] _ in self?.onAvatar?() },
            for: .touchUpInside
        )
        authorLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        authorLabel.font = AppFont.barlow(size: 11)
        bubbleView.layer.cornerRadius = 16
        playButton.tintColor = .white
        playButton.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        playButton.layer.cornerRadius = 15
        playButton.addAction(
            UIAction { [weak self] _ in self?.onPlay?() },
            for: .touchUpInside
        )
        durationLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        durationLabel.font = AppFont.barlow(size: 11, weight: .medium)
        durationLabel.textAlignment = .right
        [avatar, avatarButton, authorLabel, bubbleView].forEach(contentView.addSubview)
        [playButton, waveformView, durationLabel].forEach(bubbleView.addSubview)
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
        message: RunQChatMessageRecord,
        isCurrentUser: Bool,
        isPlaying: Bool
    ) {
        avatar.image = UIImage(named: message.authorAvatarAssetName)
        authorLabel.text = "@\(message.authorName.uppercased())"
        authorLabel.textAlignment = isCurrentUser ? .right : .left
        bubbleView.backgroundColor = isCurrentUser
            ? UIColor(red: 1, green: 91 / 255, blue: 25 / 255, alpha: 1)
            : UIColor.white.withAlphaComponent(0.22)
        playButton.setImage(
            UIImage(
                systemName: isPlaying ? "pause.fill" : "play.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            ),
            for: .normal
        )
        playButton.accessibilityLabel = isPlaying
            ? "Pause voice message"
            : "Play voice message"
        waveformView.configure(isPlaying: isPlaying)
        durationLabel.text = Self.durationText(message.audioDuration)

        avatar.snp.remakeConstraints { make in
            make.top.equalToSuperview()
            make.size.equalTo(22)
            isCurrentUser ? make.trailing.equalToSuperview() : make.leading.equalToSuperview()
        }
        avatarButton.isHidden = isCurrentUser
        avatarButton.snp.remakeConstraints { $0.edges.equalTo(avatar) }
        authorLabel.snp.remakeConstraints { make in
            make.centerY.equalTo(avatar)
            if isCurrentUser {
                make.trailing.equalTo(avatar.snp.leading).offset(-8)
            } else {
                make.leading.equalTo(avatar.snp.trailing).offset(8)
            }
        }
        bubbleView.snp.remakeConstraints { make in
            make.top.equalTo(avatar.snp.bottom).offset(7)
            make.width.equalTo(210)
            make.height.equalTo(44)
            isCurrentUser ? make.trailing.equalToSuperview() : make.leading.equalToSuperview()
        }
        playButton.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(7)
            make.centerY.equalToSuperview()
            make.size.equalTo(30)
        }
        waveformView.snp.remakeConstraints { make in
            make.leading.equalTo(playButton.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.width.equalTo(94)
            make.height.equalTo(22)
        }
        durationLabel.snp.remakeConstraints { make in
            make.trailing.equalToSuperview().inset(10)
            make.centerY.equalToSuperview()
            make.width.equalTo(48)
        }
    }

    private static func durationText(_ duration: TimeInterval) -> String {
        let safeDuration = max(0, duration)
        if safeDuration < 60 {
            return String(format: "%.1fs", safeDuration)
        }
        let minutes = Int(safeDuration) / 60
        let seconds = safeDuration - Double(minutes * 60)
        return String(format: "%d:%04.1f", minutes, seconds)
    }
}

private final class RunQVoiceParticipantCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQVoiceParticipantCell"
    private let avatar = UIImageView()
    private let nameLabel = UILabel()
    private let microphone = UIImageView(image: UIImage(named: "runq_chatbox_speaker_microphone"))
    private let plusLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 29
        avatar.layer.borderWidth = 1.5
        avatar.layer.borderColor = UIColor(red: 1, green: 91 / 255, blue: 25 / 255, alpha: 1).cgColor
        nameLabel.textColor = .white
        nameLabel.font = AppFont.barlow(size: 15)
        nameLabel.textAlignment = .center
        microphone.contentMode = .scaleAspectFit
        plusLabel.text = "+"
        plusLabel.textAlignment = .center
        plusLabel.textColor = .white
        plusLabel.font = AppFont.barlow(size: 34, weight: .medium)
        plusLabel.backgroundColor = UIColor.white.withAlphaComponent(0.24)
        plusLabel.layer.cornerRadius = 29
        plusLabel.clipsToBounds = true
        [avatar, plusLabel, microphone, nameLabel].forEach(contentView.addSubview)
        avatar.snp.makeConstraints { make in make.top.centerX.equalToSuperview(); make.size.equalTo(58) }
        plusLabel.snp.makeConstraints { make in make.top.centerX.equalToSuperview(); make.size.equalTo(58) }
        microphone.snp.makeConstraints { make in make.trailing.equalTo(avatar).offset(1); make.bottom.equalTo(avatar).offset(1); make.size.equalTo(20) }
        nameLabel.snp.makeConstraints { make in make.top.equalTo(avatar.snp.bottom).offset(12); make.centerX.equalToSuperview(); make.width.equalTo(76) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(
        name: String,
        avatarAssetName: String?,
        avatarData: Data?,
        isOpenSeat: Bool
    ) {
        nameLabel.text = name
        avatar.image = avatarData.flatMap(UIImage.init(data:))
            ?? avatarAssetName.flatMap(UIImage.init(named:))
        avatar.isHidden = isOpenSeat
        microphone.isHidden = isOpenSeat
        plusLabel.isHidden = !isOpenSeat
    }
}

private final class RunQChatAnnouncementCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQChatAnnouncementCell"
    private let bubble = UIImageView(image: UIImage(named: "runq_chatbox_message_bubble"))
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        bubble.contentMode = .scaleToFill
        label.textColor = .white
        label.font = AppFont.barlow(size: 14)
        label.numberOfLines = 4
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        contentView.addSubview(bubble)
        bubble.addSubview(label)
        bubble.snp.makeConstraints { $0.edges.equalToSuperview() }
        label.snp.makeConstraints { make in make.edges.equalToSuperview().inset(UIEdgeInsets(top: 13, left: 12, bottom: 10, right: 12)) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func configure(text: String) { label.text = text }
}

private final class RunQChatMessageCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQChatMessageCell"
    var onAvatar: (() -> Void)?
    private let avatar = UIImageView()
    private let authorLabel = UILabel()
    private let bubble = UILabel()
    private let avatarButton = UIButton(type: .custom)

    override init(frame: CGRect) {
        super.init(frame: frame)
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 11
        authorLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        authorLabel.font = AppFont.barlow(size: 11)
        bubble.textColor = UIColor.white.withAlphaComponent(0.72)
        bubble.font = AppFont.barlow(size: 11)
        bubble.numberOfLines = 0
        bubble.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        bubble.layer.cornerRadius = 16
        bubble.clipsToBounds = true
        avatarButton.accessibilityLabel = "Open message author profile"
        avatarButton.addAction(
            UIAction { [weak self] _ in self?.onAvatar?() },
            for: .touchUpInside
        )
        [avatar, avatarButton, authorLabel, bubble].forEach(contentView.addSubview)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func prepareForReuse() {
        super.prepareForReuse()
        onAvatar = nil
    }

    func configure(message: RunQChatMessageRecord, isCurrentUser: Bool) {
        avatar.image = UIImage(named: message.authorAvatarAssetName)
        authorLabel.text = "@\(message.authorName.uppercased())"
        bubble.text = "   \(message.text)   "
        avatar.snp.remakeConstraints { make in
            make.top.equalToSuperview()
            make.size.equalTo(22)
            isCurrentUser ? make.trailing.equalToSuperview() : make.leading.equalToSuperview()
        }
        avatarButton.isHidden = isCurrentUser
        avatarButton.snp.remakeConstraints { make in make.edges.equalTo(avatar) }
        authorLabel.textAlignment = isCurrentUser ? .right : .left
        authorLabel.snp.remakeConstraints { make in
            make.centerY.equalTo(avatar)
            isCurrentUser ? make.trailing.equalTo(avatar.snp.leading).offset(-8) : make.leading.equalTo(avatar.snp.trailing).offset(8)
        }
        bubble.snp.remakeConstraints { make in
            make.top.equalTo(avatar.snp.bottom).offset(7)
            make.height.greaterThanOrEqualTo(33)
            isCurrentUser ? make.trailing.equalToSuperview() : make.leading.equalToSuperview()
            make.width.lessThanOrEqualTo(245)
        }
    }
}

private final class RunQChatRoomBackdropView: UIView {
    private let gradient = CAGradientLayer()
    private let grid = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.colors = [
            UIColor(red: 12 / 255, green: 20 / 255, blue: 58 / 255, alpha: 1).cgColor,
            UIColor(red: 51 / 255, green: 22 / 255, blue: 101 / 255, alpha: 1).cgColor,
            UIColor(red: 12 / 255, green: 18 / 255, blue: 47 / 255, alpha: 1).cgColor,
            UIColor(red: 14 / 255, green: 14 / 255, blue: 17 / 255, alpha: 1).cgColor
        ]
        gradient.locations = [0, 0.34, 0.72, 1]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradient)
        grid.strokeColor = UIColor(red: 100 / 255, green: 77 / 255, blue: 190 / 255, alpha: 0.11).cgColor
        grid.lineWidth = 1
        layer.addSublayer(grid)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        grid.frame = bounds
        let path = UIBezierPath()
        let horizon: CGFloat = 150
        let vanishing = CGPoint(x: bounds.midX, y: horizon)
        stride(from: -bounds.width, through: bounds.width * 2, by: 38).forEach { x in
            path.move(to: vanishing)
            path.addLine(to: CGPoint(x: x, y: bounds.height))
        }
        var y = horizon
        var gap: CGFloat = 10
        while y < bounds.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: bounds.width, y: y))
            y += gap
            gap *= 1.12
        }
        grid.path = path.cgPath
    }
}

private enum RunQChatRoomAudioError: Error {
    case recordingFailed
}

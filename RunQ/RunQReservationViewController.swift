import UIKit
import SnapKit

@MainActor
final class RunQReservationViewController: UIViewController {
    private enum Activity: String {
        case ski
        case other

        var title: String { rawValue.uppercased() }
    }

    private let targetUserID: String
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let sheetView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let locationField = UITextField()
    private let sendButton = UIButton(type: .custom)
    private let startDateField = UITextField()
    private let endDateField = UITextField()
    private let startDatePicker = UIDatePicker()
    private let endDatePicker = UIDatePicker()
    private var activityButtons: [Activity: UIButton] = [:]
    private var attendanceButtons: [UIButton] = []
    private var selectedActivity: Activity = .other
    private var selectedAttendance: Int?
    private var loadingView: UIView?
    private weak var activeField: UIView?

    init(
        targetUserID: String,
        dataStore: RunQDataStore,
        sessionStore: CynosureSessionStore
    ) {
        self.targetUserID = targetUserID
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
        configureView()
        observeKeyboard()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureView() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.64)
        sheetView.backgroundColor = UIColor(
            red: 49 / 255,
            green: 49 / 255,
            blue: 53 / 255,
            alpha: 1
        )
        sheetView.layer.cornerRadius = 28
        sheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetView.clipsToBounds = true
        scrollView.keyboardDismissMode = .interactive

        view.addSubview(sheetView)
        sheetView.addSubview(scrollView)
        scrollView.addSubview(contentView)
        sheetView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(562).priority(.high)
            make.top.greaterThanOrEqualTo(view.safeAreaLayoutGuide).offset(116)
        }
        scrollView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.height.equalTo(562)
        }

        let handle = UIView()
        handle.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        handle.layer.cornerRadius = 3
        contentView.addSubview(handle)
        handle.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.centerX.equalToSuperview()
            make.width.equalTo(45)
            make.height.equalTo(6)
        }

        let titleLabel = makeLabel(
            "\"WHAT YOU WANT TO DO WITH YOUR BUDDY?\"",
            size: 16,
            weight: .semibold
        )
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(43)
            make.leading.equalToSuperview().offset(20)
        }

        let skiButton = makeChoiceButton(title: Activity.ski.title)
        let otherButton = makeChoiceButton(title: Activity.other.title)
        activityButtons = [.ski: skiButton, .other: otherButton]
        skiButton.addAction(
            UIAction { [weak self] _ in self?.selectActivity(.ski) },
            for: .touchUpInside
        )
        otherButton.addAction(
            UIAction { [weak self] _ in self?.selectActivity(.other) },
            for: .touchUpInside
        )
        contentView.addSubview(skiButton)
        contentView.addSubview(otherButton)
        skiButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(77)
            make.leading.equalToSuperview().offset(20)
            make.width.equalTo(99)
            make.height.equalTo(41)
        }
        otherButton.snp.makeConstraints { make in
            make.top.width.height.equalTo(skiButton)
            make.leading.equalTo(skiButton.snp.trailing).offset(27)
        }
        selectActivity(.other)

        addDateSection()
        addAttendanceSection()
        addLocationSection()
        addSendButton()

        let dismissTap = UITapGestureRecognizer(
            target: self,
            action: #selector(backgroundTapped(_:))
        )
        dismissTap.delegate = self
        view.addGestureRecognizer(dismissTap)
        updateDateLabels()
    }

    private func addDateSection() {
        let dateLabel = makeLabel("RESERVATION DATE", size: 16, weight: .medium)
        contentView.addSubview(dateLabel)
        dateLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(144)
            make.leading.equalToSuperview().offset(20)
        }

        configureDateField(startDateField, picker: startDatePicker)
        configureDateField(endDateField, picker: endDatePicker)
        let dashLabel = makeLabel("—", size: 16)
        dashLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        contentView.addSubview(startDateField)
        contentView.addSubview(dashLabel)
        contentView.addSubview(endDateField)
        startDateField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(177)
            make.leading.equalToSuperview().offset(20)
            make.width.equalTo(99)
            make.height.equalTo(40)
        }
        dashLabel.snp.makeConstraints { make in
            make.centerY.equalTo(startDateField)
            make.leading.equalTo(startDateField.snp.trailing).offset(8)
        }
        endDateField.snp.makeConstraints { make in
            make.centerY.width.height.equalTo(startDateField)
            make.leading.equalTo(dashLabel.snp.trailing).offset(8)
        }
    }

    private func addAttendanceSection() {
        let label = makeLabel("ATTENDANCE", size: 16, weight: .medium)
        contentView.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(244)
            make.leading.equalToSuperview().offset(20)
        }

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 15
        for (index, title) in ["1", "2", "3", "4+"].enumerated() {
            let button = makeChoiceButton(title: title)
            button.tag = index + 1
            button.addAction(
                UIAction { [weak self, weak button] _ in
                    guard let button else { return }
                    self?.selectAttendance(button.tag)
                },
                for: .touchUpInside
            )
            button.snp.makeConstraints { make in
                make.width.equalTo(62)
                make.height.equalTo(40)
            }
            attendanceButtons.append(button)
            stack.addArrangedSubview(button)
        }
        contentView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(277)
            make.leading.equalToSuperview().offset(20)
        }
    }

    private func addLocationSection() {
        let label = makeLabel("LOCATION(OPTIONAL)", size: 16, weight: .medium)
        contentView.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(344)
            make.leading.equalToSuperview().offset(20)
        }

        locationField.backgroundColor = UIColor.white.withAlphaComponent(0.17)
        locationField.layer.cornerRadius = 16
        locationField.textColor = .white
        locationField.font = AppFont.barlow(size: 12)
        locationField.attributedPlaceholder = NSAttributedString(
            string: "Black Stone Park",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.46)]
        )
        locationField.returnKeyType = .done
        locationField.delegate = self
        locationField.leftView = UIView(
            frame: CGRect(x: 0, y: 0, width: 20, height: 1)
        )
        locationField.leftViewMode = .always
        contentView.addSubview(locationField)
        locationField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(376)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(54)
        }
    }

    private func addSendButton() {
        sendButton.setBackgroundImage(
            UIImage(named: "runq_ember_affinity_cta"),
            for: .normal
        )
        sendButton.setTitle("Send reservation", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = AppFont.barlow(size: 15)
        sendButton.accessibilityLabel = "Send reservation"
        sendButton.addAction(
            UIAction { [weak self] _ in self?.sendReservation() },
            for: .touchUpInside
        )
        contentView.addSubview(sendButton)
        sendButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-52)
            make.width.equalTo(195)
            make.height.equalTo(52)
        }
    }

    private func makeLabel(
        _ text: String,
        size: CGFloat,
        weight: UIFont.Weight = .regular
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = AppFont.barlow(size: size, weight: weight)
        return label
    }

    private func makeChoiceButton(title: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        button.layer.cornerRadius = 14
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = AppFont.barlow(size: 15)
        return button
    }

    private func configureDateField(_ field: UITextField, picker: UIDatePicker) {
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.minimumDate = Calendar.current.startOfDay(for: Date())
        picker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        field.inputView = picker
        field.inputAccessoryView = dateToolbar()
        field.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        field.layer.cornerRadius = 14
        field.textColor = UIColor.white.withAlphaComponent(0.74)
        field.font = AppFont.barlow(size: 14)
        field.textAlignment = .center
        field.tintColor = .clear
        field.delegate = self
    }

    private func dateToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(
                title: "Done",
                style: .done,
                target: self,
                action: #selector(finishEditing)
            )
        ]
        return toolbar
    }

    private func selectActivity(_ activity: Activity) {
        selectedActivity = activity
        activityButtons.forEach { key, button in
            styleSelection(button, selected: key == activity)
        }
    }

    private func selectAttendance(_ value: Int) {
        selectedAttendance = value
        attendanceButtons.forEach {
            styleSelection($0, selected: $0.tag == value)
        }
    }

    private func styleSelection(_ button: UIButton, selected: Bool) {
        button.layer.borderWidth = selected ? 1 : 0
        button.layer.borderColor = UIColor(
            red: 28 / 255,
            green: 239 / 255,
            blue: 202 / 255,
            alpha: 1
        ).cgColor
    }

    @objc private func dateChanged() {
        if endDatePicker.date < startDatePicker.date {
            endDatePicker.setDate(startDatePicker.date, animated: true)
        }
        endDatePicker.minimumDate = startDatePicker.date
        updateDateLabels()
    }

    private func updateDateLabels() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM,dd"
        startDateField.text = formatter.string(from: startDatePicker.date).uppercased()
        endDateField.text = formatter.string(from: endDatePicker.date).uppercased()
    }

    @objc private func finishEditing() {
        view.endEditing(true)
    }

    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: view)
        if activeField != nil {
            view.endEditing(true)
        } else if !sheetView.frame.contains(point) {
            dismiss(animated: true)
        }
    }

    private func sendReservation() {
        guard loadingView == nil else { return }
        guard let requesterID = sessionStore.currentUser?.id else {
            showToast("Please sign in first.")
            return
        }
        guard requesterID != targetUserID else {
            showToast("You cannot reserve yourself.")
            return
        }
        guard let attendance = selectedAttendance else {
            showToast("Please select attendance.")
            return
        }
        guard endDatePicker.date >= startDatePicker.date else {
            showToast("Please select a valid date range.")
            return
        }

        view.endEditing(true)
        showLoading()
        let record = RunQReservationRecord(
            id: UUID().uuidString.lowercased(),
            requesterID: requesterID,
            targetUserID: targetUserID,
            activity: selectedActivity.rawValue,
            startDate: Calendar.current.startOfDay(for: startDatePicker.date),
            endDate: Calendar.current.startOfDay(for: endDatePicker.date),
            attendance: attendance,
            location: locationField.text?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? "",
            createdAt: Date()
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            do {
                try dataStore.createReservation(record)
                hideLoading()
                showSuccessAndClose()
            } catch {
                hideLoading()
                showToast("Unable to send this reservation.")
            }
        }
    }

    private func showLoading() {
        sendButton.isEnabled = false
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        overlay.addSubview(indicator)
        view.addSubview(overlay)
        overlay.snp.makeConstraints { make in make.edges.equalToSuperview() }
        indicator.snp.makeConstraints { make in make.center.equalToSuperview() }
        loadingView = overlay
    }

    private func hideLoading() {
        loadingView?.removeFromSuperview()
        loadingView = nil
        sendButton.isEnabled = true
    }

    private func showSuccessAndClose() {
        guard let presenter = presentingViewController else {
            dismiss(animated: true)
            return
        }
        showToast("Reservation sent.", on: presenter.view)
        dismiss(animated: true)
    }

    private func showToast(_ message: String, on host: UIView? = nil) {
        let hostView: UIView = host ?? view
        let toast = RunQUIKitInsetLabel()
        toast.text = message
        toast.textInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
        toast.textColor = .white
        toast.textAlignment = .center
        toast.font = AppFont.barlow(size: 13)
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.94)
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        hostView.addSubview(toast)
        toast.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(hostView.safeAreaLayoutGuide).offset(-24)
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
        }
        UIView.animate(withDuration: 0.2, delay: 1.6, options: .curveEaseIn) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let info = notification.userInfo,
              let endFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let frame = view.convert(endFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - frame.minY)
        let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curve << 16)
        ) {
            self.scrollView.contentInset.bottom = overlap
            self.scrollView.verticalScrollIndicatorInsets.bottom = overlap
        }
        if overlap > 0, let activeField {
            let rect = activeField.convert(activeField.bounds, to: scrollView)
            scrollView.scrollRectToVisible(
                rect.insetBy(dx: 0, dy: -18),
                animated: true
            )
        }
    }
}

extension RunQReservationViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeField = textField
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if activeField === textField { activeField = nil }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension RunQReservationViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        !(touch.view is UIControl)
    }
}

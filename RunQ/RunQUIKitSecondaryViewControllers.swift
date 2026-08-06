import PhotosUI
import SnapKit
import StoreKit
import UIKit

@MainActor
class RunQUIKitSecondaryViewController: UIViewController {
    let pageTitle: String
    let dataStore: RunQDataStore?
    let sessionStore: CynosureSessionStore?
    let scrollView = UIScrollView()
    let stack = UIStackView()
    private var feedbackLoadingView: UIView?

    init(title: String, dataStore: RunQDataStore? = nil, sessionStore: CynosureSessionStore? = nil) {
        pageTitle = title; self.dataStore = dataStore; self.sessionStore = sessionStore; super.init(nibName: nil, bundle: nil); hidesBottomBarWhenPushed = true
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .runQUIKitBackground
        RunQAuroralTabBackdrop.install(in: view)
        configureKeyboardHandling()
        let back = UIButton(type: .system)
        back.setImage(UIImage(named: "runq_navigation_back"), for: .normal)
        back.tintColor = .white
        back.addAction(UIAction { [weak self] _ in self?.navigationController?.popViewController(animated: true) }, for: .touchUpInside)
        back.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(back)
        let title = runQUIKitLabel(pageTitle, size: 27, weight: .bold)
        title.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(title)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView); scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), back.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 3), back.widthAnchor.constraint(equalToConstant: 44), back.heightAnchor.constraint(equalToConstant: 44),
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor), title.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            scrollView.topAnchor.constraint(equalTo: back.bottomAnchor, constant: 8), scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor), scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor), scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8), stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20), stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24), stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }

    func addField(_ title: String, placeholder: String, secure: Bool = false) -> UITextField {
        let label = runQUIKitLabel(title, size: 13); stack.addArrangedSubview(label)
        let field = runQUIKitTextField(placeholder: placeholder, secure: secure)
        field.inputAccessoryView = doneToolbar()
        field.heightAnchor.constraint(equalToConstant: 48).isActive = true
        stack.addArrangedSubview(field)
        return field
    }

    @discardableResult
    func addActionRow(_ title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system); button.setTitle(title, for: .normal); button.setTitleColor(.white, for: .normal); button.contentHorizontalAlignment = .left; button.backgroundColor = UIColor(white: 1, alpha: 0.16); button.layer.cornerRadius = 16; button.addAction(UIAction { _ in action() }, for: .touchUpInside); button.heightAnchor.constraint(equalToConstant: 56).isActive = true; stack.addArrangedSubview(button)
        return button
    }

    @discardableResult
    func showSecondaryLoading() -> Bool {
        guard feedbackLoadingView == nil else { return false }
        view.endEditing(true)
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.48)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        overlay.addSubview(indicator)
        view.addSubview(overlay)
        overlay.snp.makeConstraints { make in make.edges.equalToSuperview() }
        indicator.snp.makeConstraints { make in make.center.equalToSuperview() }
        feedbackLoadingView = overlay
        return true
    }

    func hideSecondaryLoading() {
        feedbackLoadingView?.removeFromSuperview()
        feedbackLoadingView = nil
    }

    func showSecondaryToast(_ message: String) {
        let toast = RunQUIKitInsetLabel()
        toast.text = message
        toast.textInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
        toast.textColor = .white
        toast.textAlignment = .center
        toast.numberOfLines = 0
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.94)
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        view.addSubview(toast)
        toast.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-24)
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
        }
        UIView.animate(withDuration: 0.2, delay: 1.6, options: .curveEaseIn) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }

    private func configureKeyboardHandling() {
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
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

    private func doneToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(
                title: "Done",
                style: .done,
                target: self,
                action: #selector(dismissKeyboard)
            )
        ]
        return toolbar
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let info = notification.userInfo,
              let endFrame = info[
                UIResponder.keyboardFrameEndUserInfoKey
              ] as? CGRect else {
            return
        }
        let frame = view.convert(endFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - frame.minY)
        let lift = max(0, overlap - view.safeAreaInsets.bottom)
        let duration = info[
            UIResponder.keyboardAnimationDurationUserInfoKey
        ] as? Double ?? 0.25
        UIView.animate(withDuration: duration) {
            self.scrollView.transform = CGAffineTransform(
                translationX: 0,
                y: -lift
            )
        }
    }
}

@MainActor
final class RunQUIKitWalletViewController: UIViewController {
    private struct WalletPackage {
        let productID: String
        let coins: Int
        let price: String
    }
    //        'lvbsvhxcgcrvesor', //0.99
    //        'dxismgcwewhrtezo', //4.99
    //        'khtxlcejaxmqcsra', //9.99
    //        'yadwwvxspgxwlndb', //19.99
    //        'qnrcuelbtiuflyky', //49.99
    //        'ymohxnvpkqxutvab', //99.99
    private static let packageCatalog = [
        WalletPackage(
            productID: "lvbsvhxcgcrvesor",
            coins: 400,
            price: "$0.99"
        ),
        WalletPackage(
            productID: "dxismgcwewhrtezo",
            coins: 2450,
            price: "$4.99"
        ),
        WalletPackage(
            productID: "khtxlcejaxmqcsra",
            coins: 4900,
            price: "$9.99"
        ),
        WalletPackage(
            productID: "yadwwvxspgxwlndb",
            coins: 9800,
            price: "$19.99"
        ),
        WalletPackage(
            productID: "qnrcuelbtiuflyky",
            coins: 24500,
            price: "$49.99"
        ),
        WalletPackage(
            productID: "ymohxnvpkqxutvab",
            coins: 49000,
            price: "$99.99"
        ),//test
//        WalletPackage(
//            productID: "rubvqicltnpwayoa",
//            coins: 400,
//            price: "$0.99"
//        ),
//        WalletPackage(
//            productID: "piqdicnntezedkyf",
//            coins: 800,
//            price: "$1.99"
//        ),
//        WalletPackage(
//            productID: "ddaxdvsxpmpnnzuu",
//            coins: 2450,
//            price: "$4.99"
//        ),
//        WalletPackage(
//            productID: "eqetdpxvnrfsjskx",
//            coins: 4900,
//            price: "$9.99"
//        ),
//        WalletPackage(
//            productID: "mvjiwnvcmzwjzgzv",
//            coins: 6400,
//            price: "$12.99"
//        ),
//        WalletPackage(
//            productID: "ergjyulgcgqrahcp",
//            coins: 9800,
//            price: "$19.99"
//        ),
//        WalletPackage(
//            productID: "jyasongdujlaxdbv",
//            coins: 17400,
//            price: "$39.99"
//        ),
//        WalletPackage(
//            productID: "ulamjxqxbwflqnya",
//            coins: 24500,
//            price: "$49.99"
//        ),
//        WalletPackage(
//            productID: "vhljnpleyhykkzxq",
//            coins: 34500,
//            price: "$69.99"
//        ),
//        WalletPackage(
//            productID: "kiddcrzdapzdmztr",
//            coins: 49000,
//            price: "$99.99"
//        )
    ]

    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let navigationHeader = UIView()
    private let balanceLabel = UILabel()
    private let topUpButton = UIButton(type: .custom)
    private let collectionView: UICollectionView
    private let packages: [WalletPackage]
    private var selectedIndex = 0
    private var isPurchasing = false
    private var loadingView: UIView?

    init(title: String, dataStore: RunQDataStore, sessionStore: CynosureSessionStore) {
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        packages = Self.packageCatalog
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 23
        layout.minimumLineSpacing = 16
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
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
        configureBottomArtwork()
        configureNavigation()
        configureBalance()
        configurePackages()
        configureTopUpButton()
        reloadBalance()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(walletBalanceChanged(_:)),
            name: .runQWalletBalanceDidChange,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadBalance()
    }

    private func configureBottomArtwork() {
        let artwork = UIImageView(image: UIImage(named: "runq_velutinous_wallet_zenith"))
        artwork.contentMode = .scaleToFill
        view.addSubview(artwork)
        artwork.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(136)
        }
    }

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
        title.text = "MY WALLET"
        title.textColor = .white
        title.font = AppFont.passionOne(size: 22)
        title.textAlignment = .center
        navigationHeader.addSubview(back)
        navigationHeader.addSubview(title)
        back.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-6)
            make.size.equalTo(44)
        }
        title.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(back)
        }
    }

    private func configureBalance() {
        let card = UIImageView(image: UIImage(named: "runq_chryselephantine_wallet_balance"))
        card.contentMode = .scaleToFill
        view.addSubview(card)
        card.snp.makeConstraints { make in
            make.top.equalTo(navigationHeader.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(131)
        }
        balanceLabel.textColor = .white
        balanceLabel.font = AppFont.passionOne(size: 28)
        card.addSubview(balanceLabel)
        balanceLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(37)
            make.top.equalToSuperview().offset(67)
        }
    }

    private func configurePackages() {
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 116, right: 20)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            RunQWalletPackageCell.self,
            forCellWithReuseIdentifier: RunQWalletPackageCell.reuseIdentifier
        )
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(navigationHeader.snp.bottom).offset(176)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func configureTopUpButton() {
        topUpButton.setBackgroundImage(
            UIImage(named: "runq_ember_affinity_cta"),
            for: .normal
        )
        topUpButton.setTitle("Top-up", for: .normal)
        topUpButton.setTitleColor(.white, for: .normal)
        topUpButton.titleLabel?.font = AppFont.barlow(size: 15)
        topUpButton.accessibilityLabel = "Top up wallet"
        topUpButton.addAction(
            UIAction { [weak self] _ in self?.topUp() },
            for: .touchUpInside
        )
        view.addSubview(topUpButton)
        topUpButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-18)
            make.width.equalTo(195)
            make.height.equalTo(52)
        }
    }

    private func reloadBalance() {
        guard let userID = sessionStore.currentUser?.id else {
            balanceLabel.text = "0"
            return
        }
        let balance = (try? RunQChrysalBalanceVault.shared.balance(
            userID: userID
        )) ?? 0
        balanceLabel.text = "\(balance)"
    }

    private func topUp() {
        guard !isPurchasing else { return }
        guard let userID = sessionStore.currentUser?.id else {
            showToast("Please sign in first.")
            return
        }
        guard packages.indices.contains(selectedIndex) else {
            showToast("No wallet packages are available.")
            return
        }
        let package = packages[selectedIndex]
        isPurchasing = true
        showLoading()

        Task { [weak self] in
            guard let self else { return }
            defer {
                hideLoading()
                isPurchasing = false
            }
            do {
                let products = try await Product.products(for: [package.productID])
                guard let product = products.first(where: {
                    $0.id == package.productID
                }) else {
                    showToast("This package is currently unavailable.")
                    return
                }

                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    guard case .verified(let transaction) = verification,
                          transaction.productID == package.productID else {
                        showToast("The purchase could not be verified.")
                        return
                    }
                    let updatedBalance = try RunQChrysalBalanceVault.shared.apply(
                        delta: package.coins,
                        userID: userID,
                        dataStore: dataStore
                    )
                    balanceLabel.text = "\(updatedBalance)"
                    await transaction.finish()
                    showToast("Coins added successfully.")
                case .pending:
                    showToast("The purchase is pending approval.")
                case .userCancelled:
                    break
                @unknown default:
                    showToast("The purchase could not be completed.")
                }
            } catch {
                showToast(purchaseMessage(for: error))
            }
        }
    }

    private func showLoading() {
        guard loadingView == nil else { return }
        topUpButton.isEnabled = false
        collectionView.isUserInteractionEnabled = false
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
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
        topUpButton.isEnabled = true
        collectionView.isUserInteractionEnabled = true
    }

    private func purchaseMessage(for error: Error) -> String {
        if let balanceError = error as? RunQBalanceVaultError {
            switch balanceError {
            case .insufficientBalance:
                return "Your coin balance is too low."
            case .invalidBalance, .secureStorageFailure:
                return "Unable to update your coin balance."
            }
        }
        return "The purchase could not be completed."
    }

    @objc private func walletBalanceChanged(_ notification: Notification) {
        guard let changedUserID = notification.userInfo?["userID"] as? String,
              changedUserID == sessionStore.currentUser?.id else { return }
        if let updatedBalance = notification.userInfo?["balance"] as? Int {
            balanceLabel.text = "\(updatedBalance)"
        } else {
            reloadBalance()
        }
    }

    private func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.textAlignment = .center
        toast.textColor = .white
        toast.font = AppFont.barlow(size: 13)
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.92)
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        view.addSubview(toast)
        toast.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-82)
            make.height.equalTo(40)
            make.width.equalTo(330)
        }
        UIView.animate(withDuration: 0.2, delay: 1.6, options: .curveEaseIn) {
            toast.alpha = 0
        } completion: { _ in toast.removeFromSuperview() }
    }
}

extension RunQUIKitWalletViewController: UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        packages.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RunQWalletPackageCell.reuseIdentifier,
            for: indexPath
        ) as! RunQWalletPackageCell
        let package = packages[indexPath.item]
        cell.configure(
            coins: package.coins,
            price: package.price,
            isSelected: indexPath.item == selectedIndex
        )
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard selectedIndex != indexPath.item else { return }
        let previousIndex = selectedIndex
        selectedIndex = indexPath.item
        collectionView.reloadItems(
            at: [IndexPath(item: previousIndex, section: 0), indexPath]
        )
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else {
            return CGSize(width: collectionView.bounds.width, height: 97)
        }
        let insets = collectionView.adjustedContentInset
        let availableWidth = collectionView.bounds.width
            - insets.left
            - insets.right
            - layout.minimumInteritemSpacing
        return CGSize(width: floor(max(0, availableWidth) / 2), height: 97)
    }
}

private final class RunQWalletPackageCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQWalletPackageCell"
    private let coinsLabel = UILabel()
    private let priceLabel = UILabel()
    private let selectionImage = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor(red: 47 / 255, green: 47 / 255, blue: 51 / 255, alpha: 1)
        contentView.layer.cornerRadius = 22
        contentView.clipsToBounds = true
        coinsLabel.textColor = .white
        coinsLabel.font = AppFont.barlow(size: 23, weight: .semibold)
        priceLabel.textColor = UIColor.white.withAlphaComponent(0.52)
        priceLabel.font = AppFont.barlow(size: 15)
        selectionImage.contentMode = .scaleAspectFit
        contentView.addSubview(coinsLabel)
        contentView.addSubview(priceLabel)
        contentView.addSubview(selectionImage)
        coinsLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(21)
        }
        priceLabel.snp.makeConstraints { make in
            make.leading.equalTo(coinsLabel)
            make.top.equalTo(coinsLabel.snp.bottom).offset(8)
        }
        selectionImage.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview().offset(18)
            make.size.equalTo(20)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(coins: Int, price: String, isSelected: Bool) {
        coinsLabel.text = "\(coins)"
        priceLabel.text = price
        selectionImage.image = UIImage(
            named: isSelected
                ? "runq_glaucous_wallet_choice_selected"
                : "runq_cinerous_wallet_choice_idle"
        )
        contentView.layer.borderWidth = isSelected ? 1 : 0
        contentView.layer.borderColor = UIColor(
            red: 0,
            green: 239 / 255,
            blue: 190 / 255,
            alpha: 1
        ).cgColor
    }
}

@MainActor
final class RunQUIKitEditProfileViewController: UIViewController {
    private enum GenderSelection {
        case male
        case female
    }

    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let navigationHeader = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let avatarView = UIImageView()
    private let nameField = UITextField()
    private let birthdayField = UITextField()
    private let locationField = UITextField()
    private let biographyView = UITextView()
    private let biographyPlaceholder = UILabel()
    private let maleButton = UIButton(type: .custom)
    private let femaleButton = UIButton(type: .custom)
    private let saveButton = UIButton(type: .custom)
    private var avatarData: Data?
    private var selectedGender: GenderSelection?
    private var loadingView: UIView?

    init(title: String, dataStore: RunQDataStore, sessionStore: CynosureSessionStore) {
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
        configureContent()
        configureKeyboard()
        loadProfile()
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
        navigationHeader.addSubview(back)
        back.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-6)
            make.size.equalTo(44)
        }
    }

    private func configureContent() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.contentInsetAdjustmentBehavior = .never
        view.insertSubview(scrollView, belowSubview: navigationHeader)
        view.addSubview(saveButton)
        scrollView.addSubview(contentView)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(navigationHeader.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(saveButton.snp.top).offset(-12)
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.height.greaterThanOrEqualTo(scrollView.frameLayoutGuide)
        }

        avatarView.image = UIImage(named: "runq_ai_chat_avatar")
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 35
        avatarView.isUserInteractionEnabled = true
        avatarView.accessibilityLabel = "Profile photo"
        avatarView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(selectAvatar))
        )

        let refresh = UIButton(type: .custom)
        refresh.backgroundColor = .white
        refresh.layer.cornerRadius = 10.5
        refresh.clipsToBounds = true
        refresh.setImage(UIImage(named: "runq_profile_avatar_refresh"), for: .normal)
        refresh.accessibilityLabel = "Change profile photo"
        refresh.addAction(UIAction { [weak self] _ in self?.selectAvatar() }, for: .touchUpInside)

        let nameLabel = formLabel("NAME:")
        let birthdayLabel = formLabel("BIRTHDAY:")
        let locationLabel = formLabel("LOCATION:")
        let biographyLabel = formLabel("SIGN:")
        let genderLabel = formLabel("GENDER:")
        configureField(nameField, placeholder: "Ace", returnKey: .next)
        configureField(birthdayField, placeholder: "2001-07-03", returnKey: .next)
        birthdayField.keyboardType = .numbersAndPunctuation
        configureField(locationField, placeholder: "Please enter", returnKey: .next)
        configureBiography()
        configureGenderButtons()

        saveButton.setBackgroundImage(UIImage(named: "runq_ember_affinity_cta"), for: .normal)
        saveButton.setTitle("OK", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = AppFont.passionOne(size: 17)
        saveButton.accessibilityLabel = "Save profile"
        saveButton.addAction(UIAction { [weak self] _ in self?.saveProfile() }, for: .touchUpInside)

        [avatarView, refresh, nameLabel, nameField, birthdayLabel, birthdayField,
         locationLabel, locationField, biographyLabel, biographyView, genderLabel,
         maleButton, femaleButton].forEach {
            contentView.addSubview($0)
        }
        avatarView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(13)
            make.centerX.equalToSuperview()
            make.size.equalTo(70)
        }
        refresh.snp.makeConstraints { make in
            make.centerX.equalTo(avatarView)
            make.centerY.equalTo(avatarView.snp.bottom)
            make.size.equalTo(21)
        }
        nameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(125)
            make.leading.equalToSuperview().offset(20)
        }
        nameField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(149)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(48)
        }
        birthdayLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(222)
            make.leading.equalTo(nameLabel)
        }
        birthdayField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(246)
            make.leading.trailing.height.equalTo(nameField)
        }
        locationLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(319)
            make.leading.equalTo(nameLabel)
        }
        locationField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(343)
            make.leading.trailing.height.equalTo(nameField)
        }
        biographyLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(416)
            make.leading.equalTo(nameLabel)
        }
        biographyView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(440)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(view.bounds.height < 840 ? 96 : 127)
        }
        genderLabel.snp.makeConstraints { make in
            make.top.equalTo(biographyView.snp.bottom).offset(22)
            make.leading.equalTo(nameLabel)
        }
        maleButton.snp.makeConstraints { make in
            make.top.equalTo(genderLabel.snp.bottom).offset(14)
            make.leading.equalTo(nameLabel)
            make.size.equalTo(CGSize(width: 75, height: 28))
        }
        femaleButton.snp.makeConstraints { make in
            make.centerY.equalTo(maleButton)
            make.leading.equalTo(maleButton.snp.trailing).offset(15)
            make.size.equalTo(CGSize(width: 88, height: 28))
            make.bottom.lessThanOrEqualToSuperview().inset(10)
        }
        saveButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(195)
            make.height.equalTo(52)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(8)
        }
    }

    private func formLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = AppFont.barlow(size: 13)
        return label
    }

    private func configureField(
        _ field: UITextField,
        placeholder: String,
        returnKey: UIReturnKeyType
    ) {
        field.backgroundColor = UIColor(red: 83 / 255, green: 84 / 255, blue: 88 / 255, alpha: 1)
        field.layer.cornerRadius = 16
        field.textColor = .white
        field.font = AppFont.barlow(size: 13)
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.55)]
        )
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        field.rightViewMode = .always
        field.returnKeyType = returnKey
        field.inputAccessoryView = doneToolbar()
        field.delegate = self
    }

    private func configureBiography() {
        biographyView.backgroundColor = UIColor(red: 83 / 255, green: 84 / 255, blue: 88 / 255, alpha: 1)
        biographyView.layer.cornerRadius = 16
        biographyView.textColor = .white
        biographyView.font = AppFont.barlow(size: 13)
        biographyView.textContainerInset = UIEdgeInsets(top: 15, left: 12, bottom: 12, right: 12)
        biographyView.returnKeyType = .done
        biographyView.inputAccessoryView = doneToolbar()
        biographyView.delegate = self
        biographyPlaceholder.text = "Introduce yourself!"
        biographyPlaceholder.textColor = UIColor.white.withAlphaComponent(0.55)
        biographyPlaceholder.font = AppFont.barlow(size: 13)
        biographyView.addSubview(biographyPlaceholder)
        biographyPlaceholder.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(15)
            make.leading.equalToSuperview().offset(16)
        }
    }

    private func configureGenderButtons() {
        maleButton.setImage(
            UIImage(named: "runq_profile_gender_male_idle"),
            for: .normal
        )
        maleButton.setImage(
            UIImage(named: "runq_profile_gender_male_selected"),
            for: .selected
        )
        maleButton.accessibilityLabel = "Male"
        maleButton.addAction(
            UIAction { [weak self] _ in self?.selectGender(.male) },
            for: .touchUpInside
        )

        femaleButton.setImage(
            UIImage(named: "runq_profile_gender_female_idle"),
            for: .normal
        )
        femaleButton.setImage(
            UIImage(named: "runq_profile_gender_female_selected"),
            for: .selected
        )
        femaleButton.accessibilityLabel = "Female"
        femaleButton.addAction(
            UIAction { [weak self] _ in self?.selectGender(.female) },
            for: .touchUpInside
        )
    }

    private func selectGender(_ selection: GenderSelection) {
        selectedGender = selection
        maleButton.isSelected = selection == .male
        femaleButton.isSelected = selection == .female
    }

    private func loadProfile() {
        sessionStore.refreshCurrentUser()
        guard let user = sessionStore.currentUser else { return }
        let details = dataStore.profileDetails(for: user.id)
        nameField.text = user.username
        birthdayField.text = details.birthday
        locationField.text = details.location
        biographyView.text = user.biography
        biographyPlaceholder.isHidden = !user.biography.isEmpty
        avatarData = details.avatarData
        if let avatarData, let image = UIImage(data: avatarData) {
            avatarView.image = image
        } else {
            avatarView.image = UIImage(named: user.avatarAssetName)
                ?? UIImage(named: "runq_profile_default_avatar")
        }
        switch user.gender.lowercased() {
        case "male":
            selectGender(.male)
        case "female":
            selectGender(.female)
        default:
            selectedGender = nil
            maleButton.isSelected = false
            femaleButton.isSelected = false
        }
    }

    private func saveProfile() {
        guard loadingView == nil else { return }
        guard let user = sessionStore.currentUser else {
            showToast("Please sign in first.")
            return
        }
        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else {
            showToast("Please enter your name.")
            return
        }
        showLoading()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            do {
                _ = try dataStore.updateProfile(
                    userID: user.id,
                    name: name,
                    gender: selectedGender == .female ? "female" : "male",
                    birthday: birthdayField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    location: locationField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    biography: biographyView.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    avatarData: avatarData
                )
                sessionStore.refreshCurrentUser()
                hideLoading()
                RunQToastPresenter.show(
                    "Profile saved.",
                    on: navigationController?.view ?? view
                )
                navigationController?.popViewController(animated: true)
            } catch {
                hideLoading()
                showToast("Unable to save your profile.")
            }
        }
    }

    @objc private func selectAvatar() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
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

    private func doneToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(
                title: "Done",
                style: .done,
                target: self,
                action: #selector(dismissKeyboard)
            )
        ]
        return toolbar
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let info = notification.userInfo,
              let endFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
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
        if overlap > 0, let responder = view.runQFirstResponder {
            let rect = responder.convert(responder.bounds, to: scrollView)
            scrollView.scrollRectToVisible(rect.insetBy(dx: 0, dy: -18), animated: true)
        }
    }

    private func showLoading() {
        guard loadingView == nil else { return }
        saveButton.isEnabled = false
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.42)
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
        saveButton.isEnabled = true
    }

    private func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.textAlignment = .center
        toast.textColor = .white
        toast.font = AppFont.barlow(size: 13)
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.92)
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
        } completion: { _ in toast.removeFromSuperview() }
    }
}

extension RunQUIKitEditProfileViewController: UITextFieldDelegate, UITextViewDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case nameField:
            birthdayField.becomeFirstResponder()
        case birthdayField:
            locationField.becomeFirstResponder()
        default:
            biographyView.becomeFirstResponder()
        }
        return false
    }

    func textViewDidChange(_ textView: UITextView) {
        biographyPlaceholder.isHidden = !textView.text.isEmpty
    }
}

extension RunQUIKitEditProfileViewController: PHPickerViewControllerDelegate {
    nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        Task { @MainActor in picker.dismiss(animated: true) }
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                avatarView.image = image
                avatarData = image.jpegData(compressionQuality: 0.88)
            }
        }
    }
}

@MainActor
final class RunQUIKitPublishViewController: UIViewController {
    private static let maximumTagCount = 5

    private struct PublishPayload {
        let authorID: String
        let text: String
        let tags: [String]
        let imageDataItems: [Data]
        let type: RunQPostType
    }

    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let detailView = UITextView()
    private let placeholderLabel = UILabel()
    private let newsButton = RunQPublishTypeButton(title: "SHARE NEWS")
    private let buddyButton = RunQPublishTypeButton(title: "SEEK BUDDY")
    private let newsIndicator = RunQPublishSelectionIndicator()
    private let buddyIndicator = RunQPublishSelectionIndicator()
    private let photosStack = UIStackView()
    private let tagScrollView = UIScrollView()
    private let tagsStack = UIStackView()
    private let postButton = UIButton(type: .custom)
    private var publishType: RunQPostType = .news
    private var photos: [UIImage] = []
    private var tags = ["#SurfingBuddies"]
    private var loadingView: UIView?

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
        configureForm()
        configureKeyboardHandling()
        updateTypeSelection()
        rebuildPhotos()
        rebuildTags()
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

        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 3),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func configureForm() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        let typeLabel = formLabel("TYPE:")
        let detailLabel = formLabel("DETAIL:")
        let avatarLabel = formLabel("AVATAR:")

        newsButton.addAction(
            UIAction { [weak self] _ in self?.selectType(.news) },
            for: .touchUpInside
        )
        buddyButton.addAction(
            UIAction { [weak self] _ in self?.selectType(.buddy) },
            for: .touchUpInside
        )

        detailView.backgroundColor = UIColor(red: 79 / 255, green: 79 / 255, blue: 81 / 255, alpha: 1)
        detailView.layer.cornerRadius = 16
        detailView.textColor = .white
        detailView.tintColor = .white
        detailView.font = AppFont.barlow(size: 14)
        detailView.textContainerInset = UIEdgeInsets(top: 15, left: 11, bottom: 12, right: 11)
        detailView.delegate = self
        detailView.returnKeyType = .done
        detailView.inputAccessoryView = doneToolbar()

        placeholderLabel.text = "Please enter"
        placeholderLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        placeholderLabel.font = AppFont.barlow(size: 14)
        detailView.addSubview(placeholderLabel)

        photosStack.axis = .horizontal
        photosStack.spacing = 10
        photosStack.alignment = .center

        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.2)

        tagsStack.axis = .horizontal
        tagsStack.spacing = 12
        tagsStack.alignment = .center
        tagScrollView.showsHorizontalScrollIndicator = false
        tagScrollView.alwaysBounceHorizontal = true
        tagScrollView.keyboardDismissMode = .interactive
        tagScrollView.addSubview(tagsStack)
        tagsStack.translatesAutoresizingMaskIntoConstraints = false

        postButton.setBackgroundImage(UIImage(named: "runq_ember_affinity_cta"), for: .normal)
        postButton.setTitle("POST", for: .normal)
        postButton.setTitleColor(.white, for: .normal)
        postButton.titleLabel?.font = AppFont.barlow(size: 15)
        postButton.accessibilityLabel = "Publish post"
        postButton.addAction(
            UIAction { [weak self] _ in self?.publish() },
            for: .touchUpInside
        )

        [typeLabel, newsButton, buddyButton, newsIndicator, buddyIndicator,
         detailLabel, detailView, avatarLabel, photosStack, divider, tagScrollView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        postButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(postButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 112),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: postButton.topAnchor, constant: -12),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 542),

            typeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            typeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            newsButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 42),
            newsButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            newsButton.widthAnchor.constraint(equalToConstant: 148),
            newsButton.heightAnchor.constraint(equalToConstant: 40),
            buddyButton.topAnchor.constraint(equalTo: newsButton.topAnchor),
            buddyButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 182),
            buddyButton.widthAnchor.constraint(equalToConstant: 148),
            buddyButton.heightAnchor.constraint(equalToConstant: 40),
            newsIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 94),
            newsIndicator.centerXAnchor.constraint(equalTo: newsButton.centerXAnchor),
            newsIndicator.widthAnchor.constraint(equalToConstant: 16),
            newsIndicator.heightAnchor.constraint(equalToConstant: 16),
            buddyIndicator.topAnchor.constraint(equalTo: newsIndicator.topAnchor),
            buddyIndicator.centerXAnchor.constraint(equalTo: buddyButton.centerXAnchor),
            buddyIndicator.widthAnchor.constraint(equalToConstant: 16),
            buddyIndicator.heightAnchor.constraint(equalToConstant: 16),

            detailLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 131),
            detailLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            detailView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 160),
            detailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            detailView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            detailView.heightAnchor.constraint(equalToConstant: 152),
            placeholderLabel.topAnchor.constraint(equalTo: detailView.topAnchor, constant: 17),
            placeholderLabel.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: 16),

            avatarLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 335),
            avatarLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            photosStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 365),
            photosStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            photosStack.heightAnchor.constraint(equalToConstant: 98),
            divider.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 487),
            divider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            divider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            divider.heightAnchor.constraint(equalToConstant: 2),
            tagScrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 503),
            tagScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tagScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            tagScrollView.heightAnchor.constraint(equalToConstant: 28),
            tagScrollView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),
            tagsStack.topAnchor.constraint(equalTo: tagScrollView.contentLayoutGuide.topAnchor),
            tagsStack.leadingAnchor.constraint(equalTo: tagScrollView.contentLayoutGuide.leadingAnchor),
            tagsStack.trailingAnchor.constraint(equalTo: tagScrollView.contentLayoutGuide.trailingAnchor),
            tagsStack.bottomAnchor.constraint(equalTo: tagScrollView.contentLayoutGuide.bottomAnchor),
            tagsStack.heightAnchor.constraint(equalTo: tagScrollView.frameLayoutGuide.heightAnchor),

            postButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            postButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            postButton.widthAnchor.constraint(equalToConstant: 195),
            postButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    private func formLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = UIColor.white.withAlphaComponent(0.86)
        label.font = AppFont.barlow(size: 13)
        return label
    }

    private func selectType(_ type: RunQPostType) {
        publishType = type
        updateTypeSelection()
    }

    private func updateTypeSelection() {
        let isNews = publishType == .news
        newsButton.setSelected(isNews, useNewsArtwork: true)
        buddyButton.setSelected(!isNews, useNewsArtwork: false)
        newsIndicator.isSelected = isNews
        buddyIndicator.isSelected = !isNews
    }

    private func rebuildPhotos() {
        photosStack.arrangedSubviews.forEach {
            photosStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for (index, image) in photos.prefix(3).enumerated() {
            let tile = RunQPublishPhotoTile(image: image)
            tile.onRemove = { [weak self] in
                guard let self, photos.indices.contains(index) else { return }
                photos.remove(at: index)
                rebuildPhotos()
            }
            photosStack.addArrangedSubview(tile)
            tile.widthAnchor.constraint(equalToConstant: 96).isActive = true
            tile.heightAnchor.constraint(equalToConstant: 98).isActive = true
        }
        if photos.count < 3 {
            let addButton = RunQPublishAddPhotoButton()
            addButton.setImage(UIImage(named: "runq_publish_add"), for: .normal)
            addButton.accessibilityLabel = "Add photo"
            addButton.addAction(
                UIAction { [weak self] _ in self?.pickPhotos() },
                for: .touchUpInside
            )
            photosStack.addArrangedSubview(addButton)
            addButton.widthAnchor.constraint(equalToConstant: 99).isActive = true
            addButton.heightAnchor.constraint(equalToConstant: 98).isActive = true
        }
    }

    private func rebuildTags() {
        tagsStack.arrangedSubviews.forEach {
            tagsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for (index, tag) in tags.prefix(Self.maximumTagCount).enumerated() {
            let chip = RunQPublishTagChip(text: tag)
            chip.onRemove = { [weak self] in
                guard let self, tags.indices.contains(index) else { return }
                tags.remove(at: index)
                rebuildTags()
            }
            tagsStack.addArrangedSubview(chip)
        }
        if tags.count < Self.maximumTagCount {
            let addTag = UIButton(type: .custom)
            addTag.setBackgroundImage(UIImage(named: "runq_publish_tag_plate"), for: .normal)
            addTag.accessibilityLabel = "Add tag"
            addTag.addAction(
                UIAction { [weak self] _ in self?.beginAddingTag() },
                for: .touchUpInside
            )
            tagsStack.addArrangedSubview(addTag)
            addTag.widthAnchor.constraint(equalToConstant: 86).isActive = true
            addTag.heightAnchor.constraint(equalToConstant: 27).isActive = true
        }
    }

    private func beginAddingTag() {
        guard tags.count < Self.maximumTagCount else {
            showToast("You can add up to five tags.")
            return
        }
        let field = UITextField()
        field.backgroundColor = UIColor(red: 10 / 255, green: 64 / 255, blue: 54 / 255, alpha: 1)
        field.layer.cornerRadius = 13.5
        field.textColor = .white
        field.tintColor = .white
        field.font = AppFont.barlow(size: 12)
        field.placeholder = "#Tag"
        field.attributedPlaceholder = NSAttributedString(
            string: "#Tag",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.45)]
        )
        field.textAlignment = .center
        field.returnKeyType = .done
        field.inputAccessoryView = doneToolbar()
        field.delegate = self
        field.accessibilityIdentifier = "publishTagField"
        field.text = "#"
        tagsStack.insertArrangedSubview(field, at: max(0, tagsStack.arrangedSubviews.count - 1))
        field.widthAnchor.constraint(equalToConstant: 120).isActive = true
        field.heightAnchor.constraint(equalToConstant: 27).isActive = true
        field.becomeFirstResponder()
    }

    private func commitTag(from field: UITextField) {
        guard field.accessibilityIdentifier == "publishTagField" else { return }
        field.accessibilityIdentifier = nil
        let value = (field.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty, tags.count < Self.maximumTagCount {
            let tag = "#\(value)"
            if !tags.contains(where: {
                $0.caseInsensitiveCompare(tag) == .orderedSame
            }) {
                tags.append(tag)
            }
        }
        rebuildTags()
    }

    private func pickPhotos() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = max(1, 3 - photos.count)
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func publish() {
        guard loadingView == nil else { return }
        let text = detailView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            showToast("Please enter post details.")
            return
        }
        guard let currentUser = sessionStore.currentUser,
              !currentUser.isGuest else {
            presentLoginRequired()
            return
        }
        let payload = PublishPayload(
            authorID: currentUser.id,
            text: text,
            tags: tags,
            imageDataItems: photos.prefix(3).compactMap {
                $0.jpegData(compressionQuality: 0.88)
            },
            type: publishType
        )
        performPublish(payload)
    }

    private func performPublish(_ payload: PublishPayload) {
        guard loadingView == nil else { return }
        showLoading()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            do {
                try dataStore.createPost(
                    authorID: payload.authorID,
                    text: payload.text,
                    tags: payload.tags,
                    imageDataItems: payload.imageDataItems,
                    type: payload.type
                )
                hideLoading()
                RunQToastPresenter.show(
                    "Published successfully.",
                    on: navigationController?.view ?? view
                )
                navigationController?.popViewController(animated: true)
            } catch {
                hideLoading()
                showToast("Unable to publish. Please try again.")
            }
        }
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

    private func doneToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(
                title: "Done",
                style: .done,
                target: self,
                action: #selector(dismissKeyboard)
            )
        ]
        return toolbar
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let info = notification.userInfo,
              let endFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardFrame = view.convert(endFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
        let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveValue = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curveValue << 16)
        ) {
            self.scrollView.contentInset.bottom = overlap
            self.scrollView.verticalScrollIndicatorInsets.bottom = overlap
        }
        if overlap > 0, let responder = view.runQFirstResponder {
            let rect = responder.convert(responder.bounds, to: scrollView)
            scrollView.scrollRectToVisible(rect.insetBy(dx: 0, dy: -18), animated: true)
        }
    }

    private func showLoading() {
        guard loadingView == nil else { return }
        postButton.isEnabled = false
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        overlay.addSubview(indicator)
        view.addSubview(overlay)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        indicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            indicator.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])
        loadingView = overlay
    }

    private func hideLoading() {
        loadingView?.removeFromSuperview()
        loadingView = nil
        postButton.isEnabled = true
    }

    private func showToast(_ message: String) {
        let toast = RunQUIKitInsetLabel()
        toast.text = message
        toast.textInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
        toast.textColor = .white
        toast.textAlignment = .center
        toast.font = AppFont.barlow(size: 13)
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.92)
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: postButton.topAnchor, constant: -16),
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

extension RunQUIKitPublishViewController: UITextViewDelegate, UITextFieldDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        commitTag(from: textField)
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        commitTag(from: textField)
    }
}

extension RunQUIKitPublishViewController: PHPickerViewControllerDelegate {
    nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        Task { @MainActor in
            picker.dismiss(animated: true)
        }
        for result in results where result.itemProvider.canLoadObject(ofClass: UIImage.self) {
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                Task { @MainActor [weak self] in
                    guard let self, self.photos.count < 3 else { return }
                    self.photos.append(image)
                    self.rebuildPhotos()
                }
            }
        }
    }
}

@MainActor
private final class RunQPublishTypeButton: UIButton {
    private let titleOverlay = UILabel()
    private let backgroundArtwork = UIImageView()
    private var titleLeadingConstraint: NSLayoutConstraint!
    private var titleTrailingConstraint: NSLayoutConstraint!

    init(title: String) {
        super.init(frame: .zero)
        backgroundArtwork.contentMode = .scaleToFill
        backgroundArtwork.image = UIImage(named: "runq_publish_type_plate")
        titleOverlay.text = title
        titleOverlay.textAlignment = .center
        titleOverlay.font = AppFont.barlow(size: 13)
        titleOverlay.textColor = UIColor.white.withAlphaComponent(0.45)
        [backgroundArtwork, titleOverlay].forEach {
            $0.isUserInteractionEnabled = false
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        let isNewsButton = title == "SHARE NEWS"
        titleLeadingConstraint = titleOverlay.leadingAnchor.constraint(
            equalTo: leadingAnchor,
            constant: isNewsButton ? 39 : 5
        )
        titleTrailingConstraint = titleOverlay.trailingAnchor.constraint(
            equalTo: trailingAnchor,
            constant: -5
        )
        NSLayoutConstraint.activate([
            backgroundArtwork.topAnchor.constraint(equalTo: topAnchor),
            backgroundArtwork.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundArtwork.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundArtwork.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleLeadingConstraint,
            titleTrailingConstraint,
            titleOverlay.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func setSelected(_ selected: Bool, useNewsArtwork: Bool) {
        let showsNewsArtwork = selected && useNewsArtwork
        let showsBuddyArtwork = !selected && !useNewsArtwork
        if showsNewsArtwork {
            backgroundArtwork.image = UIImage(named: "runq_square_share_news")
        } else if showsBuddyArtwork {
            backgroundArtwork.image = UIImage(named: "runq_publish_type_plate")
        } else {
            backgroundArtwork.image = nil
        }
        titleOverlay.isHidden = showsNewsArtwork || showsBuddyArtwork
        titleOverlay.backgroundColor = .clear
        titleOverlay.textColor = selected
            ? .white
            : UIColor.white.withAlphaComponent(0.45)
        let usesDrawnPlate = !showsNewsArtwork && !showsBuddyArtwork
        backgroundColor = selected && !useNewsArtwork
            ? UIColor(red: 1, green: 98 / 255, blue: 25 / 255, alpha: 1)
            : usesDrawnPlate ? UIColor.white.withAlphaComponent(0.28) : .clear
        layer.cornerRadius = usesDrawnPlate ? 12 : 0
    }
}

@MainActor
private final class RunQPublishSelectionIndicator: UIView {
    private let dot = UIView()
    var isSelected = false { didSet { updateAppearance() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 8
        backgroundColor = UIColor.white.withAlphaComponent(0.28)
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dot)
        NSLayoutConstraint.activate([
            dot.centerXAnchor.constraint(equalTo: centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10)
        ])
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    private func updateAppearance() {
        dot.backgroundColor = isSelected
            ? UIColor(red: 29 / 255, green: 238 / 255, blue: 203 / 255, alpha: 1)
            : .clear
    }
}

@MainActor
private final class RunQPublishPhotoTile: UIView {
    var onRemove: (() -> Void)?

    init(image: UIImage) {
        super.init(frame: .zero)
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        let remove = UIButton(type: .custom)
        remove.setImage(UIImage(named: "runq_publish_remove_photo"), for: .normal)
        remove.accessibilityLabel = "Remove photo"
        remove.addAction(UIAction { [weak self] _ in self?.onRemove?() }, for: .touchUpInside)
        [imageView, remove].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            remove.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            remove.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            remove.widthAnchor.constraint(equalToConstant: 24),
            remove.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

@MainActor
private final class RunQPublishAddPhotoButton: UIButton {
    private let dashLayer = CAShapeLayer()

    init() {
        super.init(frame: .zero)
        backgroundColor = UIColor(red: 76 / 255, green: 76 / 255, blue: 78 / 255, alpha: 1)
        layer.cornerRadius = 14
        clipsToBounds = true
        dashLayer.fillColor = UIColor.clear.cgColor
        dashLayer.strokeColor = UIColor.white.withAlphaComponent(0.55).cgColor
        dashLayer.lineWidth = 2
        dashLayer.lineDashPattern = [7, 5]
        layer.addSublayer(dashLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func layoutSubviews() {
        super.layoutSubviews()
        dashLayer.frame = bounds
        dashLayer.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1),
            cornerRadius: 13
        ).cgPath
    }
}

@MainActor
private final class RunQPublishTagChip: UIView {
    var onRemove: (() -> Void)?

    init(text: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor(red: 8 / 255, green: 55 / 255, blue: 46 / 255, alpha: 1)
        layer.cornerRadius = 13.5
        let label = UILabel()
        label.text = text
        label.textColor = UIColor(red: 29 / 255, green: 238 / 255, blue: 203 / 255, alpha: 1)
        label.font = AppFont.barlow(size: 12)
        let remove = UIButton(type: .custom)
        remove.setImage(UIImage(named: "runq_publish_remove_tag"), for: .normal)
        remove.accessibilityLabel = "Remove tag"
        remove.addAction(UIAction { [weak self] _ in self?.onRemove?() }, for: .touchUpInside)
        [label, remove].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 130),
            heightAnchor.constraint(equalToConstant: 27),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            remove.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            remove.centerYAnchor.constraint(equalTo: centerYAnchor),
            remove.widthAnchor.constraint(equalToConstant: 16),
            remove.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

private extension UIView {
    var runQFirstResponder: UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let responder = subview.runQFirstResponder { return responder }
        }
        return nil
    }
}

@MainActor
final class RunQUIKitSearchViewController: UIViewController {
    private enum Result {
        case user(RunQUserRecord)
        case post(RunQPostRecord)
        case activity(RunQPostRecord)
    }

    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let searchField = UITextField()
    private let searchButton = UIButton(type: .custom)
    private let emptyView = UIView()
    private let searchLoadingView = UIView()
    private let searchLoadingIndicator = UIActivityIndicatorView(style: .large)
    private let layout = UICollectionViewFlowLayout()
    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: layout
    )
    private var results: [Result] = []
    private var isSearching = false

    init(
        title: String,
        dataStore: RunQDataStore,
        sessionStore: CynosureSessionStore
    ) {
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
        configureNavigation()
        configureCollectionView()
        configureEmptyState()
        configureSearchLoading()
        configureKeyboard()
        updateEmptyState()

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--search-results-preview") {
            searchField.text = "Gym"
            performSearch()
        }
        #endif
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
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

        searchField.backgroundColor = UIColor(
            red: 42 / 255,
            green: 41 / 255,
            blue: 40 / 255,
            alpha: 1
        )
        searchField.layer.cornerRadius = 20
        searchField.textColor = .white
        searchField.tintColor = .white
        searchField.font = AppFont.barlow(size: 12)
        searchField.attributedPlaceholder = NSAttributedString(
            string: "Search",
            attributes: [
                .foregroundColor: UIColor.white.withAlphaComponent(0.48)
            ]
        )
        searchField.leftView = UIView(
            frame: CGRect(x: 0, y: 0, width: 20, height: 1)
        )
        searchField.leftViewMode = .always
        searchField.returnKeyType = .search
        searchField.delegate = self
        searchField.inputAccessoryView = doneToolbar()

        searchButton.setImage(UIImage(named: "runq_search_submit"), for: .normal)
        searchButton.accessibilityLabel = "Search"
        searchButton.addAction(
            UIAction { [weak self] _ in self?.performSearch() },
            for: .touchUpInside
        )

        [backButton, searchField, searchButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(3)
            make.size.equalTo(44)
        }
        searchButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalTo(backButton)
            make.size.equalTo(40)
        }
        searchField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(64)
            make.trailing.equalTo(searchButton.snp.leading).offset(-12)
            make.centerY.equalTo(backButton)
            make.height.equalTo(40)
        }
    }

    private func configureCollectionView() {
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 16, left: 20, bottom: 24, right: 20)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .interactive
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            RunQSearchResultCell.self,
            forCellWithReuseIdentifier: RunQSearchResultCell.reuseIdentifier
        )
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 56
            ),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureEmptyState() {
        let artwork = UIImageView(image: UIImage(named: "runq_search_empty_state"))
        artwork.contentMode = .scaleAspectFit
        let label = UILabel()
        label.text = "No content"
        label.textColor = UIColor.white.withAlphaComponent(0.48)
        label.font = AppFont.barlow(size: 14)
        label.textAlignment = .center
        [artwork, label].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            emptyView.addSubview($0)
        }
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView)
        NSLayoutConstraint.activate([
            emptyView.topAnchor.constraint(equalTo: view.topAnchor, constant: 210),
            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.widthAnchor.constraint(equalToConstant: 200),
            emptyView.heightAnchor.constraint(equalToConstant: 244),
            artwork.topAnchor.constraint(equalTo: emptyView.topAnchor),
            artwork.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor),
            artwork.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor),
            artwork.heightAnchor.constraint(equalToConstant: 200),
            label.topAnchor.constraint(equalTo: artwork.bottomAnchor, constant: 18),
            label.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor)
        ])
    }

    private func configureSearchLoading() {
        searchLoadingView.backgroundColor = .runQUIKitBackground
        searchLoadingView.isHidden = true
        searchLoadingIndicator.color = .white
        searchLoadingView.addSubview(searchLoadingIndicator)
        view.addSubview(searchLoadingView)
        searchLoadingView.translatesAutoresizingMaskIntoConstraints = false
        searchLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchLoadingView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 56
            ),
            searchLoadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchLoadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchLoadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            searchLoadingIndicator.centerXAnchor.constraint(
                equalTo: searchLoadingView.centerXAnchor
            ),
            searchLoadingIndicator.centerYAnchor.constraint(
                equalTo: searchLoadingView.centerYAnchor,
                constant: -44
            )
        ])
    }

    private func configureKeyboard() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    private func doneToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(
                title: "Done",
                style: .done,
                target: self,
                action: #selector(dismissKeyboard)
            )
        ]
        return toolbar
    }

    private func performSearch() {
        guard !isSearching else { return }
        let query = searchField.text?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        guard !query.isEmpty else {
            results = []
            collectionView.reloadData()
            updateEmptyState()
            searchField.resignFirstResponder()
            return
        }
        isSearching = true
        searchButton.isEnabled = false
        searchField.isEnabled = false
        searchField.resignFirstResponder()
        emptyView.isHidden = true
        collectionView.isHidden = true
        searchLoadingView.isHidden = false
        searchLoadingIndicator.startAnimating()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.completeSearch(query: query)
        }
    }

    private func completeSearch(query: String) {
        let users = dataStore.searchUsers(
            query: query,
            excluding: sessionStore.currentUser?.id
        ).map(Result.user)
        let content = dataStore.searchPosts(
            query: query,
            visibleTo: sessionStore.currentUser?.id
        ).map { post in
            post.id.hasPrefix("seed-post-")
                ? Result.activity(post)
                : Result.post(post)
        }
        results = users + content
        collectionView.reloadData()
        searchLoadingIndicator.stopAnimating()
        searchLoadingView.isHidden = true
        isSearching = false
        searchButton.isEnabled = true
        searchField.isEnabled = true
        updateEmptyState()
    }

    private func updateEmptyState() {
        let isEmpty = results.isEmpty
        emptyView.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
    }

    private func open(_ result: Result) {
        switch result {
        case .user(let user):
            navigationController?.pushViewController(
                RunQUIKitOtherProfileViewController(
                    title: "PROFILE",
                    dataStore: dataStore,
                    sessionStore: sessionStore,
                    userID: user.id
                ),
                animated: true
            )
        case .post(let post), .activity(let post):
            navigationController?.pushViewController(
                RunQUIKitActivityDetailViewController(
                    post: post,
                    dataStore: dataStore,
                    sessionStore: sessionStore
                ),
                animated: true
            )
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

extension RunQUIKitSearchViewController: UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout, UITextFieldDelegate,
    UIGestureRecognizerDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        results.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RunQSearchResultCell.reuseIdentifier,
            for: indexPath
        ) as! RunQSearchResultCell
        switch results[indexPath.item] {
        case .user(let user):
            let details = dataStore.profileDetails(for: user.id)
            cell.configure(
                image: details.avatarData.flatMap(UIImage.init(data:))
                    ?? UIImage(named: user.avatarAssetName),
                title: "@\(user.username.uppercased())",
                subtitle: "\(user.category) · AGE \(user.age)",
                kind: "USER"
            )
        case .post(let post):
            cell.configure(
                image: post.imageData.flatMap(UIImage.init(data:))
                    ?? UIImage(named: post.imageAssetName),
                title: "@\(post.authorName.uppercased())",
                subtitle: post.text,
                kind: "POST"
            )
        case .activity(let post):
            cell.configure(
                image: post.imageData.flatMap(UIImage.init(data:))
                    ?? UIImage(named: post.imageAssetName),
                title: "@\(post.authorName.uppercased())",
                subtitle: post.text,
                kind: "ACTIVITY"
            )
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: collectionView.bounds.width - 40, height: 88)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        open(results[indexPath.item])
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        performSearch()
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        !(touch.view is UIControl)
    }
}

private final class RunQSearchResultCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQSearchResultCell"
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let kindLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor(
            red: 48 / 255,
            green: 48 / 255,
            blue: 52 / 255,
            alpha: 1
        )
        contentView.layer.cornerRadius = 16
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        titleLabel.textColor = .white
        titleLabel.font = AppFont.barlow(size: 15, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.58)
        subtitleLabel.font = AppFont.barlow(size: 12)
        subtitleLabel.numberOfLines = 2
        kindLabel.textColor = UIColor(red: 29 / 255, green: 238 / 255, blue: 203 / 255, alpha: 1)
        kindLabel.font = AppFont.barlow(size: 11, weight: .medium)
        kindLabel.textAlignment = .right
        [imageView, titleLabel, subtitleLabel, kindLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            imageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 64),
            imageView.heightAnchor.constraint(equalToConstant: 64),
            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 17),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: kindLabel.leadingAnchor, constant: -8),
            kindLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            kindLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(image: UIImage?, title: String, subtitle: String, kind: String) {
        imageView.image = image
        titleLabel.text = title
        subtitleLabel.text = subtitle
        kindLabel.text = kind
    }
}

@MainActor
final class RunQUIKitOtherProfileViewController: UIViewController,
    UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private enum FeedSelection {
        case albums
        case posts
        case likes
    }

    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let userID: String
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let navigationHeader = UIView()
    private let followButton = UIButton(type: .custom)
    private let albumButton = UIButton(type: .custom)
    private let postsButton = UIButton(type: .custom)
    private let likesButton = UIButton(type: .custom)
    private let albumDivider = UIView()
    private let albumIndicator = UIView()
    private let feedContainer = UIView()
    private let postListView = RunQProfilePostListView()
    private let itineraryCard = UIView()
    private let itineraryRows = UIStackView()
    private var itineraryHeight: Constraint?
    private var feedHeight: Constraint?
    private var selectedFeed: FeedSelection = .albums
    private var hasEstablishedInitialOffset = false
    private var profile: RunQUserRecord?
    private var profilePosts: [RunQPostRecord] = []
    private var displayedPosts: [RunQPostRecord] = []
    private var galleryAssets: [String] = []

    private lazy var galleryView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 20
        layout.minimumLineSpacing = 16
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.isScrollEnabled = false
        collection.showsVerticalScrollIndicator = false
        collection.dataSource = self
        collection.delegate = self
        collection.register(
            RunQArcaneProfileGalleryCell.self,
            forCellWithReuseIdentifier: RunQArcaneProfileGalleryCell.reuseIdentifier
        )
        return collection
    }()

    init(
        title: String,
        dataStore: RunQDataStore,
        sessionStore: CynosureSessionStore,
        userID: String
    ) {
        _ = title
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        self.userID = userID
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
        guard dataStore.isUserVisible(
            userID,
            to: sessionStore.currentUser?.id
        ), let profile = dataStore.user(id: userID) else {
            showUnavailableProfile()
            return
        }
        self.profile = profile
        profilePosts = dataStore.posts(
            for: userID,
            visibleTo: sessionStore.currentUser?.id
        )
        galleryAssets = galleryAssetNames(from: profilePosts)
        configureCanvas(for: profile)
        configureFixedNavigation(isOwnProfile: sessionStore.currentUser?.id == userID)
        refreshFeed()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itineraryDidChange(_:)),
            name: .runQItinerariesDidChange,
            object: dataStore
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshFeed()
        rebuildItineraryRows()
        updateFollowAppearance()
        if !hasEstablishedInitialOffset {
            hasEstablishedInitialOffset = true
            scrollView.setContentOffset(.zero, animated: false)
        }
        view.bringSubviewToFront(navigationHeader)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }

    @objc private func itineraryDidChange(_ notification: Notification) {
        guard let changedUserID = notification.userInfo?["userID"] as? String,
              changedUserID == userID else { return }
        rebuildItineraryRows()
        view.layoutIfNeeded()
    }

    private func configureCanvas(for profile: RunQUserRecord) {
        view.backgroundColor = .runQUIKitBackground
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        let hero = UIImageView(image: heroImage(for: profile))
        hero.contentMode = .scaleAspectFill
        hero.clipsToBounds = true
        let veil = UIImageView(image: UIImage(named: "runq_other_profile_album_backdrop"))
        veil.contentMode = .scaleToFill

        let nameLabel = label(
            "@\(profile.username.uppercased())",
            font: AppFont.barlow(size: 15, weight: .bold)
        )
        configureFollowButton()

        let ageBadge = informationBadge(
            imageName: profile.gender.lowercased() == "female"
                ? "runq_home_gender_female"
                : "runq_home_gender_male",
            title: "AGE \(profile.age)"
        )
        let popularityBadge = popularityView()

        let followers = metricView(
            value: "\(dataStore.followerUsers(for: userID).count)",
            title: "Followers"
        )
        let following = metricView(
            value: "\(dataStore.followingUsers(for: userID).count)",
            title: "Following"
        )
        let reserveButton = reserveActionButton()

        let profileTitle = label(
            "PROFILE",
            font: AppFont.barlow(size: 15, weight: .semibold)
        )
        let profileSummary = label(
            [profile.certificate, profile.biography]
                .filter { !$0.isEmpty }
                .joined(separator: "\n"),
            font: AppFont.barlow(size: 12),
            color: UIColor.white.withAlphaComponent(0.58)
        )
        profileSummary.numberOfLines = 4
        profileSummary.lineBreakMode = .byTruncatingTail

        configureItineraryCard()
        configureAlbumTabs()
        configurePostListActions()

        [hero, veil, nameLabel, followButton, ageBadge,
         popularityBadge, followers, following, reserveButton, profileTitle,
         profileSummary, itineraryCard, albumButton, postsButton, likesButton,
         albumDivider, albumIndicator, feedContainer].forEach(contentView.addSubview)
        feedContainer.addSubview(galleryView)
        feedContainer.addSubview(postListView)

        hero.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(288)
        }
        veil.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(hero)
            make.height.equalTo(171)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(170)
        }
        followButton.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel.snp.trailing).offset(8)
            make.centerY.equalTo(nameLabel)
            make.size.equalTo(40)
        }
        ageBadge.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(207)
            make.width.equalTo(81)
            make.height.equalTo(33)
        }
        popularityBadge.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(ageBadge)
            make.width.equalTo(101)
            make.height.equalTo(41)
        }
        followers.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(274)
            make.width.equalTo(66)
        }
        following.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(111)
            make.centerY.equalTo(followers)
            make.width.equalTo(66)
        }
        reserveButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalToSuperview().offset(268)
            make.width.equalTo(135)
            make.height.equalTo(52)
        }
        profileTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(342)
        }
        profileSummary.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalTo(profileTitle.snp.bottom).offset(12)
            make.height.lessThanOrEqualTo(60)
        }
        itineraryCard.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(446)
            make.leading.trailing.equalToSuperview().inset(20)
            itineraryHeight = make.height.equalTo(itineraryCardHeight()).constraint
        }
        albumButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalTo(itineraryCard.snp.bottom).offset(24)
            make.height.equalTo(36)
        }
        postsButton.snp.makeConstraints { make in
            make.leading.equalTo(albumButton.snp.trailing).offset(25)
            make.centerY.equalTo(albumButton)
            make.height.equalTo(36)
        }
        likesButton.snp.makeConstraints { make in
            make.leading.equalTo(postsButton.snp.trailing).offset(25)
            make.centerY.equalTo(albumButton)
            make.height.equalTo(36)
        }
        albumDivider.snp.makeConstraints { make in
            make.top.equalTo(albumButton.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
        albumIndicator.snp.makeConstraints { make in
            make.leading.equalTo(albumButton)
            make.centerY.equalTo(albumDivider)
            make.width.equalTo(80)
            make.height.equalTo(3)
        }
        feedContainer.snp.makeConstraints { make in
            make.top.equalTo(albumDivider.snp.bottom).offset(22)
            make.leading.trailing.equalToSuperview()
            feedHeight = make.height.equalTo(216).constraint
            make.bottom.equalToSuperview().offset(-24)
        }
        galleryView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20))
        }
        postListView.snp.makeConstraints { make in make.edges.equalToSuperview() }
    }

    private func configureFixedNavigation(isOwnProfile: Bool) {
        navigationHeader.backgroundColor = .clear
        view.addSubview(navigationHeader)
        navigationHeader.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(94)
        }

        let back = UIButton(type: .custom)
        back.setImage(UIImage(named: "runq_navigation_back"), for: .normal)
        back.accessibilityLabel = "Back"
        back.addAction(UIAction { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }, for: .touchUpInside)

        let message = UIButton(type: .custom)
        message.setImage(UIImage(named: "runq_other_profile_message"), for: .normal)
        message.accessibilityLabel = "Message"
        message.isHidden = isOwnProfile
        message.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            guard requireAccount() else { return }
            guard let currentUserID = sessionStore.currentUser?.id,
                  dataStore.areMutuallyFollowing(
                    userID: currentUserID,
                    otherUserID: userID
                  ) else {
                RunQToastPresenter.show(
                    "You can chat after following each other.",
                    on: view
                )
                return
            }
            guard let profile else {
                RunQToastPresenter.show("This profile is unavailable.", on: view)
                return
            }
            let chat = RunQDirectChatViewController(
                peer: profile,
                dataStore: dataStore,
                sessionStore: sessionStore
            )
            navigationController?.pushViewController(chat, animated: true)
        }, for: .touchUpInside)

        let report = UIButton(type: .custom)
        report.setImage(UIImage(named: "runq_square_report"), for: .normal)
        report.accessibilityLabel = "More"
        report.isHidden = isOwnProfile
        report.isUserInteractionEnabled = !isOwnProfile
        if !isOwnProfile {
            report.addAction(
                UIAction { [weak self] _ in self?.showReportActions() },
                for: .touchUpInside
            )
        }

        [back, message, report].forEach(navigationHeader.addSubview)
        back.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-3)
            make.size.equalTo(44)
        }
        report.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalTo(back)
            make.size.equalTo(44)
        }
        message.snp.makeConstraints { make in
            make.trailing.equalTo(report.snp.leading).offset(-5)
            make.centerY.equalTo(back)
            make.size.equalTo(44)
        }
    }

    private func configureFollowButton() {
        followButton.setImage(UIImage(named: "runq_other_profile_follow_add"), for: .normal)
        followButton.accessibilityLabel = "Follow"
        followButton.isHidden = sessionStore.currentUser?.id == userID
        followButton.addAction(UIAction { [weak self] _ in self?.toggleFollowing() }, for: .touchUpInside)
        updateFollowAppearance()
    }

    private func configureItineraryCard() {
        itineraryCard.backgroundColor = UIColor(red: 48 / 255, green: 48 / 255, blue: 52 / 255, alpha: 1)
        itineraryCard.layer.cornerRadius = 28
        itineraryCard.clipsToBounds = true
        let icon = UIImageView(image: UIImage(named: "runq_periplus_profile_itinerary"))
        icon.contentMode = .scaleAspectFit
        let title = label("ITINERARY", font: AppFont.barlow(size: 13))
        let timeline = UIView()
        timeline.backgroundColor = UIColor(red: 40 / 255, green: 239 / 255, blue: 197 / 255, alpha: 0.78)
        itineraryRows.axis = .vertical
        itineraryRows.spacing = 10
        itineraryRows.alignment = .fill
        rebuildItineraryRows()

        [icon, title, timeline, itineraryRows].forEach(itineraryCard.addSubview)
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(14)
            make.size.equalTo(24)
        }
        title.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(12)
            make.centerY.equalTo(icon)
        }
        timeline.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(27)
            make.top.equalToSuperview().offset(62)
            make.bottom.equalToSuperview().offset(-31)
            make.width.equalTo(1)
        }
        itineraryRows.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalToSuperview().offset(54)
        }
    }

    private func configureAlbumTabs() {
        let albumIcon = UIImage(named: "runq_square_section_mark")
        albumButton.setImage(albumIcon, for: .normal)
        albumButton.setTitle("  PHOTO ALBUMS", for: .normal)
        albumButton.setTitleColor(.white, for: .normal)
        albumButton.titleLabel?.font = AppFont.barlow(size: 16, weight: .semibold)
        albumButton.addAction(UIAction { [weak self] _ in self?.showAlbums() }, for: .touchUpInside)
        postsButton.setTitle("POSTS", for: .normal)
        postsButton.setTitleColor(UIColor.white.withAlphaComponent(0.62), for: .normal)
        postsButton.titleLabel?.font = AppFont.barlow(size: 16)
        postsButton.addAction(UIAction { [weak self] _ in self?.showPosts() }, for: .touchUpInside)
        likesButton.setTitle("LIKE", for: .normal)
        likesButton.setTitleColor(UIColor.white.withAlphaComponent(0.62), for: .normal)
        likesButton.titleLabel?.font = AppFont.barlow(size: 16)
        likesButton.addAction(UIAction { [weak self] _ in self?.showLikes() }, for: .touchUpInside)
        albumDivider.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        albumIndicator.backgroundColor = UIColor(red: 1, green: 88 / 255, blue: 24 / 255, alpha: 1)
        albumIndicator.layer.cornerRadius = 1.5
    }

    private func configurePostListActions() {
        postListView.onOpenPost = { [weak self] post in
            self?.openPost(post)
        }
        postListView.onOpenAuthor = { [weak self] authorID in
            self?.openAuthor(authorID)
        }
        postListView.onReportPost = { [weak self] post in
            self?.showReport(for: post)
        }
        postListView.onSharePost = { [weak self] _ in
            guard let self else { return }
            guard requireAccount() else { return }
            navigationController?.pushViewController(
                RunQUIKitPublishViewController(
                    dataStore: dataStore,
                    sessionStore: sessionStore
                ),
                animated: true
            )
        }
    }

    private func informationBadge(imageName: String, title: String) -> UIView {
        let badge = UIView()
        badge.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        badge.layer.cornerRadius = 16.5
        let icon = UIImageView(image: UIImage(named: imageName))
        icon.contentMode = .scaleAspectFit
        let titleLabel = label(title, font: AppFont.barlow(size: 12), color: UIColor.white.withAlphaComponent(0.78))
        badge.addSubview(icon)
        badge.addSubview(titleLabel)
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(9)
            make.centerY.equalToSuperview()
            make.size.equalTo(14)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(5)
            make.centerY.equalToSuperview()
        }
        return badge
    }

    private func popularityView() -> UIView {
        let badge = UIView()
        badge.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        badge.layer.cornerRadius = 20.5
        let heart = UIImageView(image: UIImage(named: "runq_home_like_idle"))
        heart.contentMode = .scaleAspectFit
        let count = label("108", font: AppFont.barlow(size: 12), color: UIColor.white.withAlphaComponent(0.55))
        badge.addSubview(heart)
        badge.addSubview(count)
        heart.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(9)
            make.centerY.equalToSuperview()
            make.size.equalTo(31)
        }
        count.snp.makeConstraints { make in
            make.leading.equalTo(heart.snp.trailing).offset(11)
            make.centerY.equalToSuperview()
        }
        return badge
    }

    private func metricView(value: String, title: String) -> UIView {
        let container = UIView()
        let valueLabel = label(value, font: AppFont.barlow(size: 21, weight: .semibold))
        let titleLabel = label(title, font: AppFont.barlow(size: 13), color: UIColor.white.withAlphaComponent(0.52))
        container.addSubview(valueLabel)
        container.addSubview(titleLabel)
        valueLabel.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(valueLabel.snp.bottom).offset(2)
            make.centerX.bottom.equalToSuperview()
        }
        return container
    }

    private func reserveActionButton() -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor(red: 1, green: 88 / 255, blue: 24 / 255, alpha: 1)
        button.layer.cornerRadius = 26
        button.setImage(UIImage(named: "runq_other_profile_reserve"), for: .normal)
        button.setTitle("  Reserve", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = AppFont.barlow(size: 16)
        button.accessibilityLabel = "Reserve"
        button.addAction(UIAction { [weak self] _ in self?.openReservation() }, for: .touchUpInside)

        let priceBadge = UIImageView(
            image: UIImage(named: "runq_other_profile_reserve_price")
        )
        priceBadge.contentMode = .scaleAspectFit
        priceBadge.isUserInteractionEnabled = false
        button.addSubview(priceBadge)
        priceBadge.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(-10)
            make.trailing.equalToSuperview().offset(-1)
            make.width.equalTo(55)
            make.height.equalTo(24)
        }
        return button
    }

    private func rebuildItineraryRows() {
        itineraryRows.arrangedSubviews.forEach {
            itineraryRows.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let itineraries = dataStore.itineraries(for: userID)
        itineraryCard.isHidden = itineraries.isEmpty
        itineraries.forEach { itineraryRows.addArrangedSubview(itineraryRow($0)) }
        itineraryHeight?.update(offset: itineraryCardHeight())
    }

    private func itineraryRow(_ itinerary: RunQItineraryRecord) -> UIView {
        let row = UIView()
        let dot = UIView()
        dot.backgroundColor = UIColor(red: 40 / 255, green: 239 / 255, blue: 197 / 255, alpha: 1)
        dot.layer.cornerRadius = 6
        let date = label(itinerary.dateText, font: AppFont.barlow(size: 13), color: UIColor.white.withAlphaComponent(0.5))
        let details = label(itinerary.details, font: AppFont.barlow(size: 13), color: UIColor.white.withAlphaComponent(0.82))
        details.numberOfLines = 2
        row.addSubview(dot)
        row.addSubview(date)
        row.addSubview(details)
        row.snp.makeConstraints { make in make.height.equalTo(32) }
        dot.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(2)
            make.top.equalToSuperview().offset(2)
            make.size.equalTo(12)
        }
        date.snp.makeConstraints { make in
            make.leading.equalTo(dot.snp.trailing).offset(12)
            make.centerY.equalTo(dot)
            make.width.equalTo(56)
        }
        details.snp.makeConstraints { make in
            make.leading.equalTo(date.snp.trailing).offset(12)
            make.trailing.equalToSuperview()
            make.top.equalToSuperview()
        }
        return row
    }

    private func itineraryCardHeight() -> CGFloat {
        let rowCount = dataStore.itineraries(for: userID).count
        guard rowCount > 0 else { return 0 }
        return max(158, 60 + CGFloat(rowCount) * 42)
    }

    private func heroImage(for profile: RunQUserRecord) -> UIImage? {
        if let post = profilePosts.first,
           let data = post.imageData,
           let image = UIImage(data: data) {
            return image
        }
        if let post = profilePosts.first,
           let image = UIImage(named: post.imageAssetName) {
            return image
        }
        let details = dataStore.profileDetails(for: userID)
        return details.avatarData.flatMap(UIImage.init(data:))
            ?? UIImage(named: profile.avatarAssetName)
    }

    private func galleryAssetNames(from posts: [RunQPostRecord]) -> [String] {
        let fallbacks = [
            "runq_square_surf_photo", "runq_breaker_surfing",
            "runq_pelagic_diving", "runq_cragbound_climbing",
            "runq_stratos_skydive", "runq_home_ski_buddy_photo"
        ]
        let identity = userID + posts.map(\.id).sorted().joined()
        let seed = identity.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) & 0x7fff_ffff
        }
        let itemCount = 2 + seed % 5
        let startIndex = (seed / 5) % fallbacks.count
        return (0..<itemCount).map { index in
            fallbacks[(startIndex + index) % fallbacks.count]
        }
    }

    private func label(
        _ text: String,
        font: UIFont,
        color: UIColor = .white
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = font
        return label
    }

    private func updateFollowAppearance() {
        guard let currentUserID = sessionStore.currentUser?.id else { return }
        let isFollowing = dataStore.isFollowing(sourceUserID: currentUserID, targetUserID: userID)
        followButton.isHidden = currentUserID == userID || isFollowing
        followButton.isUserInteractionEnabled = !followButton.isHidden
        followButton.alpha = 1
        followButton.accessibilityValue = isFollowing ? "Following" : "Not following"
    }

    private func toggleFollowing() {
        guard requireAccount() else { return }
        guard let currentUserID = sessionStore.currentUser?.id else {
            RunQToastPresenter.show("Please sign in first.", on: view)
            return
        }
        guard currentUserID != userID else { return }
        let currentlyFollowing = dataStore.isFollowing(sourceUserID: currentUserID, targetUserID: userID)
        do {
            try dataStore.setFollowing(
                sourceUserID: currentUserID,
                targetUserID: userID,
                isFollowing: !currentlyFollowing
            )
            updateFollowAppearance()
            RunQToastPresenter.show(currentlyFollowing ? "Unfollowed." : "Followed.", on: view)
        } catch {
            RunQToastPresenter.show("Unable to update this user.", on: view)
        }
    }

    private func showAlbums() {
        guard requireAccount() else { return }
        selectFeed(.albums)
    }

    private func showPosts() {
        guard requireAccount() else { return }
        selectFeed(.posts)
    }

    private func showLikes() {
        guard requireAccount() else { return }
        selectFeed(.likes)
    }

    private func selectFeed(_ selection: FeedSelection) {
        guard selectedFeed != selection else { return }
        selectedFeed = selection
        refreshFeed()
        updateFeedTabs(animated: true)
    }

    private func refreshFeed() {
        profilePosts = dataStore.posts(
            for: userID,
            visibleTo: sessionStore.currentUser?.id
        )
        let showsPostSection = !profilePosts.isEmpty
        [albumButton, postsButton, likesButton, albumDivider,
         albumIndicator, feedContainer].forEach {
            $0.isHidden = !showsPostSection
        }
        guard showsPostSection else {
            galleryAssets = []
            displayedPosts = []
            galleryView.reloadData()
            postListView.isHidden = true
            feedHeight?.update(offset: 0)
            return
        }
        switch selectedFeed {
        case .albums:
            galleryAssets = galleryAssetNames(from: profilePosts)
            let rows = max(1, Int(ceil(Double(max(galleryAssets.count, 1)) / 3.0)))
            feedHeight?.update(offset: CGFloat(rows * 99 + max(0, rows - 1) * 16))
            galleryView.reloadData()
            galleryView.isHidden = false
            postListView.isHidden = true
        case .posts:
            displayedPosts = profilePosts
            showPostList(emptyMessage: "No posts yet.")
        case .likes:
            displayedPosts = dataStore.likedPosts(
                by: userID,
                visibleTo: sessionStore.currentUser?.id
            )
            showPostList(emptyMessage: "No liked posts yet.")
        }
        updateFeedTabs(animated: false)
    }

    private func showPostList(emptyMessage: String) {
        postListView.update(
            posts: displayedPosts,
            currentUserID: sessionStore.currentUser?.id,
            emptyMessage: emptyMessage,
            displaysLikedState: selectedFeed == .likes
        )
        feedHeight?.update(offset: displayedPosts.isEmpty ? 0 : postListView.requiredHeight)
        galleryView.isHidden = true
        postListView.isHidden = displayedPosts.isEmpty
    }

    private func updateFeedTabs(animated: Bool) {
        let inactive = UIColor.white.withAlphaComponent(0.62)
        albumButton.setTitleColor(selectedFeed == .albums ? .white : inactive, for: .normal)
        postsButton.setTitleColor(selectedFeed == .posts ? .white : inactive, for: .normal)
        likesButton.setTitleColor(selectedFeed == .likes ? .white : inactive, for: .normal)
        let button: UIButton
        switch selectedFeed {
        case .albums: button = albumButton
        case .posts: button = postsButton
        case .likes: button = likesButton
        }
        albumIndicator.snp.remakeConstraints { make in
            make.leading.equalTo(button)
            make.centerY.equalTo(albumDivider)
            make.width.equalTo(80)
            make.height.equalTo(3)
        }
        let changes = { self.view.layoutIfNeeded() }
        if animated {
            UIView.animate(withDuration: 0.2, animations: changes)
        } else {
            changes()
        }
    }

    private func openReservation() {
        guard requireAccount() else { return }
        let toll = RunQUIKitTollViewController(
            dataStore: dataStore,
            sessionStore: sessionStore,
            purchaseDescription: "send this reservation"
        )
        toll.modalPresentationStyle = .overFullScreen
        toll.onCompleted = { [weak self] in
            guard let self else { return }
            let reservation = RunQReservationViewController(
                targetUserID: userID,
                dataStore: dataStore,
                sessionStore: sessionStore
            )
            reservation.modalPresentationStyle = .overFullScreen
            present(reservation, animated: true)
        }
        present(toll, animated: true)
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

    private func openAuthor(_ authorID: String) {
        guard requireAccount() else { return }
        guard authorID != userID,
              authorID != sessionStore.currentUser?.id,
              dataStore.isUserVisible(authorID, to: sessionStore.currentUser?.id),
              dataStore.user(id: authorID) != nil else { return }
        navigationController?.pushViewController(
            RunQUIKitOtherProfileViewController(
                title: "PROFILE",
                dataStore: dataStore,
                sessionStore: sessionStore,
                userID: authorID
            ),
            animated: true
        )
    }

    private func showReport(for post: RunQPostRecord) {
        guard requireAccount() else { return }
        guard let currentUserID = sessionStore.currentUser?.id,
              post.authorID != currentUserID else { return }
        let report = RunQUIKitReportViewController()
        report.modalPresentationStyle = .overFullScreen
        report.onBlock = { [weak self] in
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

    private func showReportActions() {
        guard requireAccount() else { return }
        guard let currentUserID = sessionStore.currentUser?.id,
              currentUserID != userID,
              dataStore.user(id: userID) != nil else {
            RunQToastPresenter.show("Unable to block this user.", on: navigationController?.view ?? view)
            return
        }
        let report = RunQUIKitReportViewController()
        report.modalPresentationStyle = .overFullScreen
        report.onBlock = { [weak self] in
            guard let self else { return }
            do {
                try dataStore.setBlocked(sourceUserID: currentUserID, targetUserID: userID, isBlocked: true)
                RunQToastPresenter.show("Added to blocked list.", on: navigationController?.view ?? view)
                navigationController?.popViewController(animated: true)
            } catch {
                RunQToastPresenter.show("Unable to block this user.", on: navigationController?.view ?? view)
            }
        }
        present(report, animated: true)
    }

    @discardableResult
    private func requireAccount() -> Bool {
        runQUIKitRequireAccount(
            from: self,
            dataStore: dataStore,
            sessionStore: sessionStore
        )
    }

    private func showUnavailableProfile() {
        view.backgroundColor = .runQUIKitBackground
        RunQToastPresenter.show("This profile is unavailable.", on: view)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        galleryAssets.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RunQArcaneProfileGalleryCell.reuseIdentifier,
            for: indexPath
        ) as! RunQArcaneProfileGalleryCell
        cell.configure(imageName: galleryAssets[indexPath.item])
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = floor((collectionView.bounds.width - 40) / 3)
        return CGSize(width: width, height: 99)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
    }
}

private final class RunQArcaneProfileGalleryCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQArcaneProfileGalleryCell"
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in make.edges.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(imageName: String) {
        imageView.image = UIImage(named: imageName)
    }
}

@MainActor
final class RunQUIKitCreateChatboxViewController: UIViewController {
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let nameField = UITextField()
    private let keyField = UITextField()
    private let limitField = UITextField()
    private let avatarButton = RunQChatboxAvatarPickerButton(type: .custom)
    private let createButton = UIButton(type: .custom)
    private var createButtonBottomConstraint: Constraint?
    private var avatarData: Data?
    private var loadingView: UIView?
    private lazy var boxID = dataStore.nextChatRoomID()

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    init(
        title: String,
        dataStore: RunQDataStore,
        sessionStore: CynosureSessionStore
    ) {
        self.dataStore = dataStore
        self.sessionStore = sessionStore
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureNavigation()
        configureForm()
        configureCreateButton()
        configureKeyboard()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureView() {
        view.backgroundColor = UIColor(
            red: 20 / 255,
            green: 19 / 255,
            blue: 18 / 255,
            alpha: 1
        )
        RunQAuroralTabBackdrop.install(in: view)

        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(createButton)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(77)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(createButton.snp.top).offset(-12)
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.height.greaterThanOrEqualTo(456)
        }
    }

    private func configureNavigation() {
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
        view.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(3)
            make.size.equalTo(44)
        }
    }

    private func configureForm() {
        let boxIDTitle = makeLabel("BOX ID:")
        let boxIDValue = makeLabel(boxID)
        let nameTitle = makeLabel("BOX NAME:")
        let keyTitle = makeLabel("KEY:")
        let limitTitle = makeLabel("NUM. OF PPL:")
        let avatarTitle = makeLabel("AVATAR:")

        configureField(nameField, placeholder: "Please enter")
        configureField(keyField, placeholder: "Please enter")
        keyField.isSecureTextEntry = true
        configureField(limitField, placeholder: "10(default)")
        limitField.keyboardType = .numberPad

        nameField.delegate = self
        keyField.delegate = self
        limitField.delegate = self
        nameField.returnKeyType = .next
        keyField.returnKeyType = .next
        limitField.returnKeyType = .done

        avatarButton.accessibilityLabel = "Select Chatbox avatar"
        avatarButton.addAction(
            UIAction { [weak self] _ in self?.selectAvatar() },
            for: .touchUpInside
        )

        [
            boxIDTitle, boxIDValue, nameTitle, nameField, keyTitle, keyField,
            limitTitle, limitField, avatarTitle, avatarButton
        ].forEach(contentView.addSubview)

        boxIDTitle.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(20)
        }
        boxIDValue.snp.makeConstraints { make in
            make.centerY.equalTo(boxIDTitle)
            make.leading.equalToSuperview().offset(101)
        }
        nameTitle.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(61)
            make.leading.equalToSuperview().offset(20)
        }
        nameField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(89)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(48)
        }
        keyTitle.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(158)
            make.leading.equalToSuperview().offset(20)
        }
        keyField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(186)
            make.leading.trailing.height.equalTo(nameField)
        }
        limitTitle.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(255)
            make.leading.equalToSuperview().offset(20)
        }
        limitField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(283)
            make.leading.trailing.height.equalTo(nameField)
        }
        avatarTitle.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(354)
            make.leading.equalToSuperview().offset(20)
        }
        avatarButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(385)
            make.leading.equalToSuperview().offset(20)
            make.size.equalTo(61)
            make.bottom.lessThanOrEqualToSuperview().inset(10)
        }
    }

    private func configureCreateButton() {
        createButton.setBackgroundImage(
            UIImage(named: "runq_ember_affinity_cta"),
            for: .normal
        )
        createButton.setTitle("Create  My Chatbox", for: .normal)
        createButton.setTitleColor(.white, for: .normal)
        createButton.titleLabel?.font = AppFont.barlow(size: 15)
        createButton.accessibilityLabel = "Create My Chatbox"
        createButton.addAction(
            UIAction { [weak self] _ in self?.requestCreation() },
            for: .touchUpInside
        )
        createButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.equalTo(CGSize(width: 195, height: 52))
            createButtonBottomConstraint = make.bottom
                .equalTo(view.safeAreaLayoutGuide)
                .offset(-18)
                .constraint
        }
    }

    private func makeLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = AppFont.barlow(size: 13)
        return label
    }

    private func configureField(_ field: UITextField, placeholder: String) {
        field.backgroundColor = UIColor(
            red: 79 / 255,
            green: 79 / 255,
            blue: 82 / 255,
            alpha: 1
        )
        field.layer.cornerRadius = 16
        field.textColor = .white
        field.tintColor = .white
        field.font = AppFont.barlow(size: 13)
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: AppFont.barlow(size: 13),
                .foregroundColor: UIColor.white.withAlphaComponent(0.47)
            ]
        )
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        field.leftViewMode = .always
        field.inputAccessoryView = doneToolbar()
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
    }

    private func doneToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(
                title: "Done",
                style: .done,
                target: self,
                action: #selector(dismissKeyboard)
            )
        ]
        return toolbar
    }

    private func configureKeyboard() {
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
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

    @objc private func selectAvatar() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let info = notification.userInfo,
              let keyboardValue = info[UIResponder.keyboardFrameEndUserInfoKey]
                as? NSValue else { return }
        let keyboardFrame = view.convert(keyboardValue.cgRectValue, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
        let safeBottom = view.safeAreaInsets.bottom
        let lift = max(0, overlap - safeBottom)
        createButtonBottomConstraint?.update(offset: -18 - lift)

        let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey]
            as? TimeInterval ?? 0.25
        let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey]
            as? UInt ?? 7
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curve << 16)
                .union(.beginFromCurrentState)
        ) {
            self.view.layoutIfNeeded()
            if lift > 0, let focusedField = [
                self.nameField, self.keyField, self.limitField
            ].first(where: { $0.isFirstResponder }) {
                let visibleRect = focusedField.convert(
                    focusedField.bounds.insetBy(dx: 0, dy: -12),
                    to: self.scrollView
                )
                self.scrollView.scrollRectToVisible(visibleRect, animated: false)
            } else {
                self.scrollView.setContentOffset(.zero, animated: false)
            }
        }
    }

    private func requestCreation() {
        guard loadingView == nil else { return }
        guard let userID = sessionStore.currentUser?.id else {
            RunQToastPresenter.show("Please sign in first.", on: view)
            return
        }
        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let key = keyField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty, !key.isEmpty else {
            RunQToastPresenter.show("Please complete all fields.", on: view)
            return
        }
        let limitText = limitField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let limit = limitText.isEmpty ? 10 : Int(limitText)
        guard let limit, limit > 1 else {
            RunQToastPresenter.show(
                "Please enter a valid participant limit.",
                on: view
            )
            return
        }
        guard let avatarData else {
            RunQToastPresenter.show(
                "Please select a Chatbox avatar.",
                on: view
            )
            return
        }

        view.endEditing(true)
        showCreationLoading()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            do {
                try dataStore.createChatRoom(
                    id: boxID,
                    ownerID: userID,
                    name: name,
                    key: key,
                    participantLimit: limit,
                    avatarData: avatarData
                )
                hideCreationLoading()
                RunQToastPresenter.show(
                    "Chatbox created.",
                    on: navigationController?.view ?? view
                )
                navigationController?.popViewController(animated: true)
            } catch {
                hideCreationLoading()
                RunQToastPresenter.show(
                    "Unable to create this Chatbox.",
                    on: view
                )
            }
        }
    }

    private func showCreationLoading() {
        createButton.isEnabled = false
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.46)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        overlay.addSubview(indicator)
        view.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
        indicator.snp.makeConstraints { $0.center.equalToSuperview() }
        loadingView = overlay
    }

    private func hideCreationLoading() {
        loadingView?.removeFromSuperview()
        loadingView = nil
        createButton.isEnabled = true
    }
}

extension RunQUIKitCreateChatboxViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === nameField {
            keyField.becomeFirstResponder()
        } else if textField === keyField {
            limitField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}

extension RunQUIKitCreateChatboxViewController: PHPickerViewControllerDelegate {
    nonisolated func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ) {
        Task { @MainActor in picker.dismiss(animated: true) }
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                avatarData = image.jpegData(compressionQuality: 0.88)
                avatarButton.setAvatar(image)
            }
        }
    }
}

private final class RunQChatboxAvatarPickerButton: UIButton {
    private let dashedView = RunQDashedAddView(cornerRadius: 10)
    private let avatarView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(dashedView)
        addSubview(avatarView)
        dashedView.isUserInteractionEnabled = false
        avatarView.isUserInteractionEnabled = false
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 10
        avatarView.isHidden = true
        dashedView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        avatarView.snp.makeConstraints { make in make.edges.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func setAvatar(_ image: UIImage) {
        avatarView.image = image
        avatarView.isHidden = false
        dashedView.isHidden = true
    }
}

private final class RunQDashedAddView: UIView {
    private let shapeLayer = CAShapeLayer()
    private let plusLabel = UILabel()
    private let radius: CGFloat

    init(cornerRadius: CGFloat) {
        self.radius = cornerRadius
        super.init(frame: .zero)
        backgroundColor = UIColor(
            red: 67 / 255,
            green: 66 / 255,
            blue: 65 / 255,
            alpha: 1
        )
        layer.cornerRadius = cornerRadius

        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor.white.withAlphaComponent(0.72).cgColor
        shapeLayer.lineWidth = 1.5
        shapeLayer.lineDashPattern = [5, 3]
        layer.addSublayer(shapeLayer)

        plusLabel.text = "+"
        plusLabel.textColor = .white
        plusLabel.textAlignment = .center
        plusLabel.font = AppFont.barlow(size: 28)
        addSubview(plusLabel)
        plusLabel.snp.makeConstraints { make in make.center.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
        shapeLayer.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: 0.75, dy: 0.75),
            cornerRadius: max(0, radius - 0.75)
        ).cgPath
    }
}

private enum RunQAIReplyComposer {
    private struct Topic {
        let keywords: [String]
        let answers: [String]
    }

    private static let topics = [
        Topic(
            keywords: ["hello", "hey", "good morning", "good afternoon"],
            answers: [
                "Hi! Tell me which activity you are interested in and what level you are at.",
                "Hello! I can help with training, technique, recovery, nutrition, or outdoor preparation.",
                "Hey! What fitness or outdoor goal would you like to work on today?"
            ]
        ),
        Topic(
            keywords: ["gym", "workout", "fitness", "strength", "muscle", "exercise"],
            answers: [
                "Start with two or three full-body sessions each week. Focus on squats, hinges, pushes, pulls, and controlled core work.",
                "Choose weights that let you finish every set with two good repetitions left. Add weight only when your form stays consistent.",
                "A balanced beginner session can include goblet squats, dumbbell presses, rows, Romanian deadlifts, and planks."
            ]
        ),
        Topic(
            keywords: ["climb", "climbing", "boulder", "belay", "crag"],
            answers: [
                "For climbing progress, combine technique drills with grip-friendly strength work and keep at least one recovery day between hard sessions.",
                "Practice quiet feet, straight arms, and deliberate hip movement before chasing harder grades. Efficient movement saves more energy than pulling harder.",
                "Warm up on easy routes, inspect your equipment, confirm partner checks, and stop before your grip becomes too fatigued for safe movement."
            ]
        ),
        Topic(
            keywords: ["surf", "surfing", "wave", "paddle", "board"],
            answers: [
                "Check the forecast, currents, and local hazards first. Spend time on paddle fitness and pop-up consistency before moving into larger surf.",
                "For a cleaner takeoff, look forward, keep your chest lifted, and place your feet in one quick controlled movement.",
                "Build surf endurance with steady swimming or paddling intervals, shoulder mobility, and rotational core work."
            ]
        ),
        Topic(
            keywords: ["dive", "diving", "scuba", "freedive", "underwater"],
            answers: [
                "Always dive within your certification and conditions, complete a buddy check, and review the depth, gas, and emergency plan before entering the water.",
                "For better underwater control, practice slow breathing, neutral buoyancy, and small efficient fin movements in a controlled environment.",
                "Freediving training should always use a qualified buddy. Never practice breath holds alone in water."
            ]
        ),
        Topic(
            keywords: ["skydive", "skydiving", "parachute", "freefall", "jump"],
            answers: [
                "Follow your instructor and drop-zone procedures exactly, review emergency actions, and avoid jumping when weather or equipment checks are uncertain.",
                "Stable body position comes from relaxed shoulders, a balanced arch, and steady awareness. Practice only under qualified supervision.",
                "Prepare for a jump with good sleep, hydration, a complete gear check, and a clear review of the exit and landing plan."
            ]
        ),
        Topic(
            keywords: ["recover", "recovery", "sore", "pain", "injury", "rest"],
            answers: [
                "Use easy movement, sleep, hydration, and adequate food for normal soreness. Sharp, worsening, or persistent pain should be assessed by a clinician.",
                "Reduce intensity for a few days instead of stopping all movement. Keep activity comfortable and rebuild gradually when symptoms improve.",
                "Recovery improves when hard sessions alternate with easy days and you keep a consistent sleep schedule."
            ]
        ),
        Topic(
            keywords: ["food", "diet", "nutrition", "protein", "hydrate", "hydration"],
            answers: [
                "Build meals around protein, vegetables or fruit, a useful carbohydrate source, and enough fluids for your training conditions.",
                "For most sessions, eat a familiar meal two or three hours before training and have water available throughout.",
                "After training, combine protein with carbohydrates and rehydrate. Consistent daily nutrition matters more than a single supplement."
            ]
        ),
        Topic(
            keywords: ["plan", "schedule", "routine", "program", "week"],
            answers: [
                "A simple week can use two strength days, two activity-specific practice days, one easy conditioning day, and two recovery days.",
                "Set one measurable goal for the next four weeks, track each session, and adjust only one training variable at a time.",
                "Keep hard days hard and easy days easy. That structure makes progress easier to measure and recovery easier to manage."
            ]
        )
    ]

    private static let fallbackAnswers = [
        "Tell me a little more about your goal, experience level, available time, and equipment so I can suggest a practical next step.",
        "I can help you turn that into a simple plan. What activity are you preparing for, and what feels most difficult right now?",
        "A good starting point is to define the goal, assess your current level, and choose one small action you can repeat consistently this week.",
        "Could you share more detail about the activity and the result you want? I will tailor the advice to your situation."
    ]

    static func reply(to text: String) -> String {
        let normalized = text.lowercased()
        let words = Set(normalized.split(whereSeparator: { !$0.isLetter }).map(String.init))
        let bestMatch = topics
            .map { topic in
                let score = topic.keywords.reduce(into: 0) { result, keyword in
                    result += keyword.contains(" ")
                        ? (normalized.contains(keyword) ? 1 : 0)
                        : (words.contains(keyword) ? 1 : 0)
                }
                return (topic, score)
            }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }
        return bestMatch?.0.answers.randomElement()
            ?? fallbackAnswers.randomElement()
            ?? fallbackAnswers[0]
    }
}

@MainActor
final class RunQUIKitAIChatViewController: UIViewController {
    private let dataStore: RunQDataStore
    private let sessionStore: CynosureSessionStore
    private let heroView = UIImageView(image: UIImage(named: "runq_ai_chat_hero"))
    private let messageLayout = UICollectionViewFlowLayout()
    private lazy var messageCollectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: messageLayout
    )
    private let composerView = UIView()
    private let inputField = UITextField()
    private let sendButton = UIButton(type: .custom)
    private var composerBottomConstraint: Constraint?
    private var messages: [RunQAIMessageRecord] = []
    private var isSending = false

    init(
        title: String,
        dataStore: RunQDataStore,
        sessionStore: CynosureSessionStore
    ) {
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
        configureHero()
        configureNavigation()
        configureComposer()
        configureMessages()
        configureKeyboard()
        reloadMessages(scrollsToBottom: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ai-chat-keyboard-preview") {
            inputField.becomeFirstResponder()
        }
        #endif
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func configureHero() {
        heroView.contentMode = .scaleToFill
        view.addSubview(heroView)
        heroView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(heroView.snp.width).multipliedBy(291.0 / 375.0)
        }
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
        titleLabel.text = "AI RUNQ"
        titleLabel.textColor = .white
        titleLabel.font = AppFont.passionOne(size: 22)
        titleLabel.textAlignment = .center

        [backButton, titleLabel].forEach(view.addSubview)
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(4)
            make.size.equalTo(44)
        }
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(backButton)
        }
    }

    private func configureMessages() {
        messageLayout.scrollDirection = .vertical
        messageLayout.minimumLineSpacing = 0
        messageCollectionView.backgroundColor = .clear
        messageCollectionView.showsVerticalScrollIndicator = false
        messageCollectionView.alwaysBounceVertical = true
        messageCollectionView.keyboardDismissMode = .interactive
        messageCollectionView.contentInset = UIEdgeInsets(
            top: 40,
            left: 0,
            bottom: 12,
            right: 0
        )
        messageCollectionView.dataSource = self
        messageCollectionView.delegate = self
        messageCollectionView.register(
            RunQAIMessageCell.self,
            forCellWithReuseIdentifier: RunQAIMessageCell.reuseIdentifier
        )
        view.insertSubview(messageCollectionView, belowSubview: heroView)
        messageCollectionView.snp.makeConstraints { make in
            make.top.equalTo(heroView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(composerView.snp.top).offset(-12)
        }
    }

    private func configureComposer() {
        composerView.backgroundColor = .runQUIKitBackground
        inputField.backgroundColor = UIColor(
            red: 46 / 255,
            green: 44 / 255,
            blue: 43 / 255,
            alpha: 1
        )
        inputField.layer.cornerRadius = 27.5
        inputField.textColor = .white
        inputField.tintColor = .white
        inputField.font = AppFont.barlow(size: 15)
        inputField.attributedPlaceholder = NSAttributedString(
            string: "Say something",
            attributes: [
                .foregroundColor: UIColor.white.withAlphaComponent(0.52)
            ]
        )
        inputField.leftView = UIView(
            frame: CGRect(x: 0, y: 0, width: 20, height: 1)
        )
        inputField.leftViewMode = .always
        inputField.returnKeyType = .send
        inputField.delegate = self

        sendButton.backgroundColor = UIColor(
            red: 1,
            green: 91 / 255,
            blue: 25 / 255,
            alpha: 1
        )
        sendButton.layer.cornerRadius = 27.5
        sendButton.setTitle("SEND", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = AppFont.passionOne(size: 18)
        sendButton.accessibilityLabel = "Send message"
        sendButton.addAction(
            UIAction { [weak self] _ in self?.sendMessage() },
            for: .touchUpInside
        )

        view.addSubview(composerView)
        composerView.addSubview(inputField)
        composerView.addSubview(sendButton)
        composerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(55)
            composerBottomConstraint = make.bottom
                .equalTo(view.safeAreaLayoutGuide)
                .offset(-6)
                .constraint
        }
        inputField.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(0)
            make.trailing.equalTo(sendButton.snp.leading).offset(2)
        }
        sendButton.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview().inset(0)
            make.width.equalTo(55)
        }
    }

    private func configureKeyboard() {
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
        tap.cancelsTouchesInView = false
        tap.delegate = self
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

    private func reloadMessages(scrollsToBottom: Bool) {
        guard let userID = sessionStore.currentUser?.id else {
            messages = []
            messageCollectionView.reloadData()
            return
        }
        messages = dataStore.aiMessages(for: userID)
        messageCollectionView.reloadData()
        guard scrollsToBottom, !messages.isEmpty else { return }
        messageCollectionView.layoutIfNeeded()
        messageCollectionView.scrollToItem(
            at: IndexPath(item: messages.count - 1, section: 0),
            at: .bottom,
            animated: true
        )
    }

    private func sendMessage() {
        guard !isSending else { return }
        guard runQUIKitRequireAccount(
            from: self,
            dataStore: dataStore,
            sessionStore: sessionStore
        ) else { return }
        let text = inputField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
            let reply = RunQAIReplyComposer.reply(to: text)
            try dataStore.addAIExchange(
                userID: userID,
                userText: text,
                replyText: reply
            )
            inputField.text = nil
            inputField.resignFirstResponder()
            reloadMessages(scrollsToBottom: true)
        } catch {
            RunQToastPresenter.show("Unable to send this message.", on: view)
        }
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey]
                as? NSValue else { return }
        let keyboardFrame = view.convert(keyboardValue.cgRectValue, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
        let safeBottom = view.safeAreaInsets.bottom
        let offset = overlap > 0
            ? -(overlap - safeBottom + 8)
            : -6
        composerBottomConstraint?.update(offset: offset)
        let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey]
            as? TimeInterval ?? 0.25
        let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey]
            as? UInt ?? 7
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curveValue << 16)
                .union(.beginFromCurrentState),
            animations: { self.view.layoutIfNeeded() }
        )
    }
}

extension RunQUIKitAIChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendMessage()
        return false
    }
}

extension RunQUIKitAIChatViewController: UICollectionViewDataSource,
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
            withReuseIdentifier: RunQAIMessageCell.reuseIdentifier,
            for: indexPath
        ) as! RunQAIMessageCell
        cell.configure(message: messages[indexPath.item])
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let message = messages[indexPath.item]
        return CGSize(
            width: collectionView.bounds.width,
            height: RunQAIMessageCell.height(
                for: message,
                availableWidth: collectionView.bounds.width
            )
        )
    }
}

extension RunQUIKitAIChatViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        !(touch.view is UIControl)
    }
}

private final class RunQAIMessageCell: UICollectionViewCell {
    static let reuseIdentifier = "RunQAIMessageCell"
    private static let font = AppFont.barlow(size: 15)
    private let avatarView = UIImageView(
        image: UIImage(named: "runq_ai_chat_avatar")
    )
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private let timeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        avatarView.contentMode = .scaleAspectFit
        bubbleView.layer.cornerRadius = 16
        messageLabel.textColor = .white
        messageLabel.font = Self.font
        messageLabel.numberOfLines = 0
        timeLabel.textColor = UIColor.white.withAlphaComponent(0.48)
        timeLabel.font = AppFont.barlow(size: 14)
        [avatarView, bubbleView, timeLabel].forEach(contentView.addSubview)
        bubbleView.addSubview(messageLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(message: RunQAIMessageRecord) {
        let isUser = message.isFromCurrentUser
        avatarView.isHidden = isUser
        bubbleView.backgroundColor = isUser
            ? UIColor(red: 1, green: 91 / 255, blue: 25 / 255, alpha: 1)
            : UIColor(red: 47 / 255, green: 47 / 255, blue: 52 / 255, alpha: 1)
        messageLabel.text = message.text
        timeLabel.text = message.id.hasPrefix("seed-ai-")
            ? "11: 26 am"
            : Self.timeFormatter.string(from: message.createdAt).lowercased()

        let bubbleWidth = Self.bubbleWidth(
            isUser: isUser,
            availableWidth: contentView.bounds.width
        )
        avatarView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview()
            make.size.equalTo(32)
        }
        bubbleView.snp.remakeConstraints { make in
            make.top.equalToSuperview()
            make.width.equalTo(bubbleWidth)
            if isUser {
                make.trailing.equalToSuperview().inset(20)
            } else {
                make.leading.equalToSuperview().offset(60)
            }
        }
        messageLabel.snp.remakeConstraints { make in
            make.edges.equalToSuperview().inset(
                UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
            )
        }
        timeLabel.snp.remakeConstraints { make in
            make.top.equalTo(bubbleView.snp.bottom).offset(8)
            if isUser {
                make.leading.equalTo(bubbleView)
            } else {
                make.trailing.equalTo(bubbleView)
            }
        }
    }

    static func height(
        for message: RunQAIMessageRecord,
        availableWidth: CGFloat
    ) -> CGFloat {
        let width = bubbleWidth(
            isUser: message.isFromCurrentUser,
            availableWidth: availableWidth
        ) - 32
        let textHeight = ceil(
            (message.text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            ).height
        )
        return max(64, textHeight + 32) + 8 + 18 + 22
    }

    private static func bubbleWidth(
        isUser: Bool,
        availableWidth: CGFloat
    ) -> CGFloat {
        min(277, availableWidth - (isUser ? 98 : 80))
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h: mm a"
        return formatter
    }()
}

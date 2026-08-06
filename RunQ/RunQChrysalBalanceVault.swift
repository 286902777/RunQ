import Foundation
import Security

extension Notification.Name {
    static let runQWalletBalanceDidChange = Notification.Name(
        "runq.wallet.balance.did-change"
    )
}

enum RunQBalanceVaultError: Error {
    case invalidBalance
    case insufficientBalance
    case secureStorageFailure
}

@MainActor
final class RunQChrysalBalanceVault {
    static let shared = RunQChrysalBalanceVault()

    private let service = "app.myfy.test.runq.wallet"

    private init() {}

    func balance(userID: String) throws -> Int {
        try storedBalance(userID: userID) ?? 0
    }

    @discardableResult
    func apply(
        delta: Int,
        userID: String,
        dataStore: RunQDataStore
    ) throws -> Int {
        let previousBalance = try balance(userID: userID)
        let updatedBalance = previousBalance + delta
        guard updatedBalance >= 0 else {
            throw RunQBalanceVaultError.insufficientBalance
        }

        try setBalance(updatedBalance, userID: userID)
        do {
            try dataStore.setWalletBalance(
                updatedBalance,
                for: userID
            )
        } catch {
            try? setBalance(previousBalance, userID: userID)
            throw error
        }

        NotificationCenter.default.post(
            name: .runQWalletBalanceDidChange,
            object: nil,
            userInfo: ["userID": userID, "balance": updatedBalance]
        )
        return updatedBalance
    }

    func removeBalance(userID: String) throws {
        let status = SecItemDelete(baseQuery(userID: userID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RunQBalanceVaultError.secureStorageFailure
        }
    }

    private func storedBalance(userID: String) throws -> Int? {
        var query = baseQuery(userID: userID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let data = item as? Data,
              let text = String(data: data, encoding: .utf8),
              let balance = Int(text),
              balance >= 0 else {
            throw RunQBalanceVaultError.secureStorageFailure
        }
        return balance
    }

    private func setBalance(_ balance: Int, userID: String) throws {
        guard balance >= 0 else {
            throw RunQBalanceVaultError.invalidBalance
        }
        let data = Data(String(balance).utf8)
        let query = baseQuery(userID: userID)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw RunQBalanceVaultError.secureStorageFailure
        }

        var insertion = query
        insertion[kSecValueData as String] = data
        let addStatus = SecItemAdd(insertion as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw RunQBalanceVaultError.secureStorageFailure
        }
    }

    private func baseQuery(userID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: userID,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }
}

import Combine
import Foundation

@MainActor
final class CynosureSessionStore: ObservableObject {
    private enum PersistenceKey {
        static let userID = "runq.cynosure.session.user-id"
    }

    @Published private(set) var currentUser: RunQUserRecord?
    @Published private(set) var pendingRegistrationUser: RunQUserRecord?

    var isAuthenticated: Bool {
        currentUser != nil
    }

    private let dataStore: RunQDataStore
    private let defaults: UserDefaults

    init(
        dataStore: RunQDataStore,
        defaults: UserDefaults = .standard
    ) {
        self.dataStore = dataStore
        self.defaults = defaults
    }

    func restorePersistedSession() {
        guard let userID = defaults.string(
            forKey: PersistenceKey.userID
        ), let user = dataStore.user(id: userID) else {
            defaults.removeObject(forKey: PersistenceKey.userID)
            currentUser = nil
            return
        }
        try? dataStore.ensureSocialData(for: user.id)
        currentUser = user
    }

    func signIn(email: String, password: String) throws {
        establishSession(
            for: try dataStore.authenticate(
                email: email,
                password: password
            )
        )
    }

    func register(email: String, password: String) throws {
        pendingRegistrationUser = try dataStore.register(
            email: email,
            password: password
        )
    }

    func completePendingRegistration(
        affinities: [String]
    ) throws {
        guard let pendingRegistrationUser else {
            throw RunQDataError.accountNotFound
        }
        let user = try dataStore.completeProfile(
            userID: pendingRegistrationUser.id,
            affinities: affinities
        )
        self.pendingRegistrationUser = nil
        establishSession(for: user)
    }

    func resetPassword(email: String, newPassword: String) throws {
        try dataStore.resetPassword(
            email: email,
            newPassword: newPassword
        )
    }

    func continueAsGuest() throws {
        establishSession(for: try dataStore.createGuest())
    }

    func relinquishSession() {
        defaults.removeObject(forKey: PersistenceKey.userID)
        currentUser = nil
        pendingRegistrationUser = nil
    }

    func refreshCurrentUser() {
        guard let userID = currentUser?.id else { return }
        currentUser = dataStore.user(id: userID)
    }

    func deleteCurrentAccount() throws {
        guard let user = currentUser else {
            throw RunQDataError.accountNotFound
        }

        try dataStore.deactivateUser(id: user.id)
        guard dataStore.user(id: user.id) == nil else {
            throw RunQDataError.persistenceFailure
        }
        relinquishSession()
    }

    private func establishSession(for user: RunQUserRecord) {
        try? dataStore.ensureSocialData(for: user.id)
        defaults.set(user.id, forKey: PersistenceKey.userID)
        currentUser = user
    }

}

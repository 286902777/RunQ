import Combine
import Foundation
import SQLite3

extension Notification.Name {
    static let runQSocialDataDidChange = Notification.Name(
        "runq.social.data.did-change"
    )
    static let runQChatRoomsDidChange = Notification.Name(
        "runq.chat-rooms.did-change"
    )
    static let runQReservationsDidChange = Notification.Name(
        "runq.reservations.did-change"
    )
    static let runQItinerariesDidChange = Notification.Name(
        "runq.itineraries.did-change"
    )
}

struct RunQUserRecord: Identifiable, Equatable {
    let id: String
    let email: String
    let username: String
    let gender: String
    let age: Int
    let category: String
    let certificate: String
    let avatarAssetName: String
    let biography: String
    let isGuest: Bool
}

struct RunQItineraryRecord: Identifiable, Equatable {
    let id: String
    let dateText: String
    let details: String
    let sortOrder: Int
}

struct RunQPostRecord: Identifiable, Equatable {
    let id: String
    let authorID: String
    let authorName: String
    let authorAvatarAssetName: String
    let text: String
    let tags: [String]
    let imageAssetName: String
    let imageDataItems: [Data]
    let createdAt: Date
    let likeCount: Int
    let commentCount: Int
    let type: RunQPostType

    var imageData: Data? { imageDataItems.first }
}

enum RunQPostType: String {
    case news
    case buddy
}

enum RunQVideoFeedSection: String, CaseIterable {
    case nearby
    case recommend

    var title: String { rawValue.uppercased() }
}

struct RunQVideoRecord: Identifiable, Equatable {
    let id: String
    let authorID: String
    let authorName: String
    let authorAvatarAssetName: String
    let feedSection: RunQVideoFeedSection
    let mediaFileName: String
    let fallbackImageAssetName: String
    let caption: String
    let tags: [String]
    let createdAt: Date
    let likeCount: Int
    let commentCount: Int
}

struct RunQVideoCommentRecord: Identifiable, Equatable {
    let id: String
    let videoID: String
    let authorID: String?
    let authorName: String
    let authorAvatarAssetName: String
    let authorAvatarData: Data?
    let text: String
    let createdAt: Date
}

struct RunQProfileDetails: Equatable {
    let birthday: String
    let location: String
    let avatarData: Data?
}

struct RunQCommentRecord: Identifiable, Equatable {
    let id: String
    let postID: String
    let authorID: String?
    let authorName: String
    let authorAvatarAssetName: String
    let authorAvatarData: Data?
    let text: String
    let createdAt: Date
}

struct RunQChatRoomRecord: Identifiable, Equatable {
    let id: String
    let name: String
    let participantLimit: Int
    let participantCount: Int
    let avatarData: Data?
    let createdBy: String
    let ownerAvatarAssetName: String
    let ownerAvatarData: Data?
    let maleParticipantCount: Int
    let femaleParticipantCount: Int

    var resolvedAvatarData: Data? {
        avatarData ?? ownerAvatarData
    }
}

struct RunQChatMessageRecord: Identifiable, Equatable {
    let id: String
    let roomID: String
    let authorID: String
    let authorName: String
    let authorAvatarAssetName: String
    let text: String
    let audioData: Data?
    let audioDuration: TimeInterval
    let createdAt: Date
}

struct RunQDirectMessageRecord: Identifiable, Equatable {
    let id: String
    let senderID: String
    let receiverID: String
    let senderName: String
    let senderAvatarAssetName: String
    let text: String
    let audioData: Data?
    let audioDuration: TimeInterval
    let createdAt: Date
}

struct RunQDirectConversationRecord: Identifiable, Equatable {
    var id: String { peer.id }
    let peer: RunQUserRecord
    let preview: String
    let createdAt: Date
}

struct RunQAIMessageRecord: Identifiable, Equatable {
    let id: String
    let text: String
    let isFromCurrentUser: Bool
    let createdAt: Date
}

struct RunQReservationRecord: Identifiable, Equatable {
    let id: String
    let requesterID: String
    let targetUserID: String
    let activity: String
    let startDate: Date
    let endDate: Date
    let attendance: Int
    let location: String
    let createdAt: Date
}

enum RunQDataError: LocalizedError {
    case accountExists
    case accountNotFound
    case invalidCredentials
    case invalidSeed
    case persistenceFailure

    var errorDescription: String? {
        switch self {
        case .accountExists:
            return "An account already exists for this email."
        case .accountNotFound:
            return "No account was found for this email."
        case .invalidCredentials:
            return "Email or password is incorrect."
        case .invalidSeed:
            return "Starter data could not be loaded."
        case .persistenceFailure:
            return "Your changes could not be saved."
        }
    }
}

@MainActor
final class RunQDataStore: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var startupMessage: String?
    @Published private(set) var users: [RunQUserRecord] = []
    @Published private(set) var posts: [RunQPostRecord] = []
    @Published private(set) var videos: [RunQVideoRecord] = []

    private let database: OpaquePointer
    private static let seedKey = "starter-data-version"
    private static let transient = unsafeBitCast(
        -1,
        to: sqlite3_destructor_type.self
    )

    init(isStoredInMemoryOnly: Bool = false) {
        if isStoredInMemoryOnly,
           let memoryDatabase = Self.openDatabase(at: ":memory:") {
            database = memoryDatabase
            return
        }

        let fileManager = FileManager.default
        let supportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let directoryURL = supportURL.appendingPathComponent(
            "RunQ",
            isDirectory: true
        )
        try? fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let databaseURL = directoryURL.appendingPathComponent("runq.sqlite3")

        if let persistentDatabase = Self.openDatabase(
            at: databaseURL.path
        ) {
            database = persistentDatabase
        } else {
            database = Self.openDatabase(at: ":memory:")!
            startupMessage = RunQDataError.persistenceFailure.localizedDescription
        }
    }

    func prepareIfNeeded() async {
        guard !isReady else { return }
        do {
            try createSchema()
            try migrateLegacyDefaultAvatar()
            try seedIfNeeded()
            try seedSharedReferenceData()
            try refresh()
        } catch {
            startupMessage = (error as? LocalizedError)?.errorDescription
                ?? RunQDataError.invalidSeed.localizedDescription
        }
        isReady = true
    }

    func authenticate(email: String, password: String) throws -> RunQUserRecord {
        let normalizedEmail = normalizeEmail(email)
        let statement = try prepare(
            """
            SELECT id, email, username, gender, age, category, certificate,
                   avatar_asset_name, biography, is_guest
            FROM users
            WHERE email = ? AND password = ? AND is_deleted = 0
            LIMIT 1
            """,
            values: [.text(normalizedEmail), .text(password)]
        )
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw RunQDataError.invalidCredentials
        }
        return userRecord(from: statement)
    }

    func register(email: String, password: String) throws -> RunQUserRecord {
        let normalizedEmail = normalizeEmail(email)
        guard try user(email: normalizedEmail) == nil else {
            throw RunQDataError.accountExists
        }
        let username = normalizedEmail.split(separator: "@").first
            .map(String.init) ?? "Member"
        let id = UUID().uuidString.lowercased()
        if try tableHasColumn("password_hash", in: "users") {
            try execute(
                """
                INSERT INTO users (
                    id, email, username, password, password_hash, gender, age,
                    category, certificate, avatar_source, avatar_asset_name,
                    biography, affinities, is_guest, created_at
                ) VALUES (?, ?, ?, ?, '', '', 0, '', '', '', ?, '', '', 0, ?)
                """,
                values: [
                    .text(id), .text(normalizedEmail), .text(username),
                    .text(password), .text("runq_profile_default_avatar"),
                    .double(Date().timeIntervalSince1970)
                ]
            )
        } else {
            try execute(
                """
                INSERT INTO users (
                    id, email, username, password, gender, age, category,
                    certificate, avatar_source, avatar_asset_name, biography,
                    affinities, is_guest, created_at
                ) VALUES (?, ?, ?, ?, '', 0, '', '', '', ?, '', '', 0, ?)
                """,
                values: [
                    .text(id), .text(normalizedEmail), .text(username),
                    .text(password), .text("runq_profile_default_avatar"),
                    .double(Date().timeIntervalSince1970)
                ]
            )
        }
        try execute(
            "INSERT OR IGNORE INTO wallet_accounts (user_id, balance) VALUES (?, 0)",
            values: [.text(id)]
        )
        try refresh()
        return try requiredUser(id: id)
    }

    func createGuest() throws -> RunQUserRecord {
        let id = UUID().uuidString.lowercased()
        let legacyPasswordColumn = try tableHasColumn("password_hash", in: "users")
        let passwordColumns = legacyPasswordColumn ? ", password_hash" : ""
        let passwordValues = legacyPasswordColumn ? ", ''" : ""
        try execute(
            """
            INSERT INTO users (
                id, email, username, password\(passwordColumns), gender, age,
                category, certificate, avatar_source, avatar_asset_name,
                biography, affinities, is_guest, created_at
            ) VALUES (?, ?, 'Guest', ''\(passwordValues), '', 0, '', '', '', ?, '', '', 1, ?)
            """,
            values: [
                .text(id), .text("guest-\(id)@runq.local"),
                .text("runq_profile_default_avatar"),
                .double(Date().timeIntervalSince1970)
            ]
        )
        try execute(
            "INSERT OR IGNORE INTO wallet_accounts (user_id, balance) VALUES (?, 0)",
            values: [.text(id)]
        )
        try refresh()
        return try requiredUser(id: id)
    }

    func resetPassword(email: String, newPassword: String) throws {
        let normalizedEmail = normalizeEmail(email)
        guard try user(email: normalizedEmail) != nil else {
            throw RunQDataError.accountNotFound
        }
        try execute(
            "UPDATE users SET password = ? WHERE email = ?",
            values: [
                .text(newPassword),
                .text(normalizedEmail)
            ]
        )
    }

    func completeProfile(
        userID: String,
        affinities: [String]
    ) throws -> RunQUserRecord {
        let category = affinities.first.map { "\($0) BUDDY" } ?? ""
        try execute(
            """
            UPDATE users
            SET affinities = ?, category = CASE WHEN category = '' THEN ? ELSE category END
            WHERE id = ?
            """,
            values: [
                .text(affinities.joined(separator: "|")),
                .text(category),
                .text(userID)
            ]
        )
        guard sqlite3_changes(database) > 0 else {
            throw RunQDataError.accountNotFound
        }
        try refresh()
        NotificationCenter.default.post(
            name: .runQSocialDataDidChange,
            object: self,
            userInfo: ["userID": userID]
        )
        return try requiredUser(id: userID)
    }

    func user(id: String) -> RunQUserRecord? {
        try? requiredUser(id: id)
    }

    func discoverableUsers(excluding userID: String?) -> [RunQUserRecord] {
        let statement: OpaquePointer?
        if let userID {
            statement = try? prepare(
                """
                SELECT id, email, username, gender, age, category, certificate,
                       avatar_asset_name, biography, is_guest
                FROM users
                WHERE is_guest = 0 AND is_deleted = 0 AND id != ?
                ORDER BY created_at
                """,
                values: [.text(userID)]
            )
        } else {
            statement = try? prepare(
                """
                SELECT id, email, username, gender, age, category, certificate,
                       avatar_asset_name, biography, is_guest
                FROM users
                WHERE is_guest = 0 AND is_deleted = 0
                ORDER BY created_at
                """
            )
        }
        guard let statement else { return [] }
        defer { sqlite3_finalize(statement) }
        var records: [RunQUserRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            records.append(userRecord(from: statement))
        }
        guard let userID else { return records }
        return records.filter { isUserVisible($0.id, to: userID) }
    }

    func feedPosts(visibleTo userID: String? = nil) -> [RunQPostRecord] {
        let records = (try? fetchPosts()) ?? []
        return visiblePosts(records, userID: userID)
    }

    func followingPosts(for userID: String) -> [RunQPostRecord] {
        let followedUserIDs = Set(followingUsers(for: userID).map(\.id))
        guard !followedUserIDs.isEmpty else { return [] }
        return feedPosts(visibleTo: userID).filter {
            followedUserIDs.contains($0.authorID)
        }
    }

    func videoFeed(
        section: RunQVideoFeedSection,
        visibleTo userID: String? = nil
    ) -> [RunQVideoRecord] {
        ((try? fetchVideos()) ?? []).filter {
            $0.feedSection == section && isUserVisible($0.authorID, to: userID)
        }.map { video in
            guard userID != nil else { return video }
            return RunQVideoRecord(
                id: video.id,
                authorID: video.authorID,
                authorName: video.authorName,
                authorAvatarAssetName: video.authorAvatarAssetName,
                feedSection: video.feedSection,
                mediaFileName: video.mediaFileName,
                fallbackImageAssetName: video.fallbackImageAssetName,
                caption: video.caption,
                tags: video.tags,
                createdAt: video.createdAt,
                likeCount: video.likeCount,
                commentCount: videoComments(
                    for: video.id,
                    visibleTo: userID
                ).count
            )
        }
    }

    func isVideoLiked(videoID: String, userID: String) -> Bool {
        guard let statement = try? prepare(
            """
            SELECT 1 FROM video_likes
            WHERE video_id = ? AND user_id = ? LIMIT 1
            """,
            values: [.text(videoID), .text(userID)]
        ) else { return false }
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW
    }

    func setVideoLiked(
        videoID: String,
        userID: String,
        isLiked: Bool
    ) throws {
        if isLiked {
            guard let video = videos.first(where: { $0.id == videoID }),
                  isUserVisible(video.authorID, to: userID) else {
                throw RunQDataError.invalidCredentials
            }
        }
        let currentlyLiked = isVideoLiked(videoID: videoID, userID: userID)
        guard currentlyLiked != isLiked else { return }
        try transaction {
            if isLiked {
                try execute(
                    """
                    INSERT INTO video_likes (user_id, video_id, created_at)
                    VALUES (?, ?, ?)
                    """,
                    values: [
                        .text(userID), .text(videoID),
                        .double(Date().timeIntervalSince1970)
                    ]
                )
                try execute(
                    "UPDATE videos SET like_count = like_count + 1 WHERE id = ?",
                    values: [.text(videoID)]
                )
            } else {
                try execute(
                    "DELETE FROM video_likes WHERE user_id = ? AND video_id = ?",
                    values: [.text(userID), .text(videoID)]
                )
                try execute(
                    "UPDATE videos SET like_count = MAX(0, like_count - 1) WHERE id = ?",
                    values: [.text(videoID)]
                )
            }
        }
        try refresh()
    }

    func videoComments(
        for videoID: String,
        visibleTo userID: String? = nil
    ) -> [RunQVideoCommentRecord] {
        guard let statement = try? prepare(
            """
            SELECT c.id, c.video_id, c.author_id,
                   COALESCE(u.username, 'Luna'),
                   COALESCE(u.avatar_asset_name, 'runq_square_author_avatar'),
                   p.avatar_data, c.text, c.created_at
            FROM video_comments c
            LEFT JOIN users u ON u.id = c.author_id
            LEFT JOIN user_profiles p ON p.user_id = c.author_id
            WHERE c.video_id = ?
            ORDER BY c.created_at
            """,
            values: [.text(videoID)]
        ) else { return [] }
        defer { sqlite3_finalize(statement) }
        var result: [RunQVideoCommentRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(
                RunQVideoCommentRecord(
                    id: text(statement, 0),
                    videoID: text(statement, 1),
                    authorID: nullableText(statement, 2),
                    authorName: text(statement, 3),
                    authorAvatarAssetName: text(statement, 4),
                    authorAvatarData: data(statement, 5),
                    text: text(statement, 6),
                    createdAt: Date(
                        timeIntervalSince1970: sqlite3_column_double(statement, 7)
                    )
                )
            )
        }
        return result.filter { comment in
            guard let authorID = comment.authorID else { return true }
            return isUserVisible(authorID, to: userID)
        }
    }

    @discardableResult
    func addVideoComment(
        videoID: String,
        authorID: String,
        text: String
    ) throws -> RunQVideoCommentRecord {
        guard let video = videos.first(where: { $0.id == videoID }),
              isUserVisible(video.authorID, to: authorID) else {
            throw RunQDataError.invalidCredentials
        }
        let id = UUID().uuidString.lowercased()
        try execute(
            """
            INSERT INTO video_comments
            (id, video_id, author_id, text, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            values: [
                .text(id), .text(videoID), .text(authorID), .text(text),
                .double(Date().timeIntervalSince1970)
            ]
        )
        try refresh()
        guard let comment = videoComments(for: videoID).first(where: { $0.id == id })
        else { throw RunQDataError.persistenceFailure }
        return comment
    }

    func itineraries(for userID: String) -> [RunQItineraryRecord] {
        guard let statement = try? prepare(
            """
            SELECT id, date_text, details, sort_order
            FROM itineraries WHERE user_id = ? ORDER BY sort_order
            """,
            values: [.text(userID)]
        ) else { return [] }
        defer { sqlite3_finalize(statement) }
        var records: [RunQItineraryRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            records.append(
                RunQItineraryRecord(
                    id: text(statement, 0),
                    dateText: text(statement, 1),
                    details: text(statement, 2),
                    sortOrder: Int(sqlite3_column_int(statement, 3))
                )
            )
        }
        return records
    }

    func posts(
        for userID: String,
        visibleTo viewerUserID: String? = nil
    ) -> [RunQPostRecord] {
        guard isUserVisible(userID, to: viewerUserID) else { return [] }
        return visiblePosts(
            posts.filter { $0.authorID == userID },
            userID: viewerUserID
        )
    }

    func likedPosts(
        by userID: String,
        visibleTo viewerUserID: String? = nil
    ) -> [RunQPostRecord] {
        guard isUserVisible(userID, to: viewerUserID) else { return [] }
        guard let statement = try? prepare(
            """
            SELECT post_id FROM post_likes
            WHERE user_id = ? ORDER BY created_at DESC
            """,
            values: [.text(userID)]
        ) else { return [] }
        defer { sqlite3_finalize(statement) }
        let postsByID = Dictionary(uniqueKeysWithValues: posts.map { ($0.id, $0) })
        var result: [RunQPostRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let post = postsByID[text(statement, 0)] {
                result.append(post)
            }
        }
        return visiblePosts(result, userID: viewerUserID)
    }

    func isPostLiked(postID: String, userID: String) -> Bool {
        guard let statement = try? prepare(
            """
            SELECT 1 FROM post_likes
            WHERE post_id = ? AND user_id = ? LIMIT 1
            """,
            values: [.text(postID), .text(userID)]
        ) else { return false }
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW
    }

    func setPostLiked(postID: String, userID: String, isLiked: Bool) throws {
        if isLiked {
            guard let post = posts.first(where: { $0.id == postID }),
                  isUserVisible(post.authorID, to: userID) else {
                throw RunQDataError.invalidCredentials
            }
        }
        let currentlyLiked = isPostLiked(postID: postID, userID: userID)
        guard currentlyLiked != isLiked else { return }
        try transaction {
            if isLiked {
                try execute(
                    """
                    INSERT INTO post_likes (user_id, post_id, created_at)
                    VALUES (?, ?, ?)
                    """,
                    values: [
                        .text(userID), .text(postID),
                        .double(Date().timeIntervalSince1970)
                    ]
                )
                try execute(
                    "UPDATE posts SET like_count = like_count + 1 WHERE id = ?",
                    values: [.text(postID)]
                )
            } else {
                try execute(
                    "DELETE FROM post_likes WHERE user_id = ? AND post_id = ?",
                    values: [.text(userID), .text(postID)]
                )
                try execute(
                    "UPDATE posts SET like_count = MAX(0, like_count - 1) WHERE id = ?",
                    values: [.text(postID)]
                )
            }
        }
        try refresh()
    }

    func post(id: String?) -> RunQPostRecord? {
        guard let id else { return posts.first }
        return posts.first { $0.id == id }
    }

    func searchUsers(
        query: String,
        excluding userID: String?
    ) -> [RunQUserRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return users.filter { user in
            !user.isGuest
                && user.id != userID
                && isUserVisible(user.id, to: userID)
                && (trimmed.isEmpty
                    || user.username.localizedCaseInsensitiveContains(trimmed)
                    || user.category.localizedCaseInsensitiveContains(trimmed))
        }
    }

    func searchPosts(
        query: String,
        visibleTo userID: String? = nil
    ) -> [RunQPostRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let results = posts.filter { post in
            post.authorName.localizedCaseInsensitiveContains(trimmed)
                || post.text.localizedCaseInsensitiveContains(trimmed)
                || post.tags.contains {
                    $0.localizedCaseInsensitiveContains(trimmed)
                }
        }
        return visiblePosts(results, userID: userID)
    }

    func followingUsers(for userID: String) -> [RunQUserRecord] {
        relationUsers(
            sql: """
            SELECT u.id, u.email, u.username, u.gender, u.age, u.category,
                   u.certificate, u.avatar_asset_name, u.biography, u.is_guest
            FROM user_relations r JOIN users u ON u.id = r.target_user_id
            WHERE r.source_user_id = ? AND r.kind = 'follow'
            ORDER BY r.created_at DESC
            """,
            userID: userID
        ).filter { isUserVisible($0.id, to: userID) }
    }

    func followerUsers(for userID: String) -> [RunQUserRecord] {
        relationUsers(
            sql: """
            SELECT u.id, u.email, u.username, u.gender, u.age, u.category,
                   u.certificate, u.avatar_asset_name, u.biography, u.is_guest
            FROM user_relations r JOIN users u ON u.id = r.source_user_id
            WHERE r.target_user_id = ? AND r.kind = 'follow'
            ORDER BY r.created_at DESC
            """,
            userID: userID
        ).filter { isUserVisible($0.id, to: userID) }
    }

    func blockedUsers(for userID: String) -> [RunQUserRecord] {
        relationUsers(
            sql: """
            SELECT u.id, u.email, u.username, u.gender, u.age, u.category,
                   u.certificate, u.avatar_asset_name, u.biography, u.is_guest
            FROM user_relations r JOIN users u ON u.id = r.target_user_id
            WHERE r.source_user_id = ? AND r.kind = 'block'
            ORDER BY r.created_at DESC
            """,
            userID: userID
        )
    }

    func isBlocked(sourceUserID: String, targetUserID: String) -> Bool {
        (try? relationExists(
            sourceUserID: sourceUserID,
            targetUserID: targetUserID,
            kind: "block"
        )) ?? false
    }

    func isUserVisible(_ targetUserID: String, to viewerUserID: String?) -> Bool {
        guard user(id: targetUserID) != nil else { return false }
        guard let viewerUserID,
              viewerUserID != targetUserID else { return true }
        return !isBlocked(
            sourceUserID: viewerUserID,
            targetUserID: targetUserID
        ) && !isBlocked(
            sourceUserID: targetUserID,
            targetUserID: viewerUserID
        )
    }

    func setBlocked(
        sourceUserID: String,
        targetUserID: String,
        isBlocked: Bool
    ) throws {
        guard sourceUserID != targetUserID else { return }
        if isBlocked {
            try transaction {
                try execute(
                    """
                    INSERT OR IGNORE INTO user_relations
                    (id, source_user_id, target_user_id, kind, created_at)
                    VALUES (?, ?, ?, 'block', ?)
                    """,
                    values: [
                        .text("block-\(sourceUserID)-\(targetUserID)"),
                        .text(sourceUserID), .text(targetUserID),
                        .double(Date().timeIntervalSince1970)
                    ]
                )
                try execute(
                    """
                    DELETE FROM user_relations
                    WHERE kind = 'follow'
                      AND ((source_user_id = ? AND target_user_id = ?)
                        OR (source_user_id = ? AND target_user_id = ?))
                    """,
                    values: [
                        .text(sourceUserID), .text(targetUserID),
                        .text(targetUserID), .text(sourceUserID)
                    ]
                )
            }
        } else {
            try execute(
                """
                DELETE FROM user_relations
                WHERE source_user_id = ? AND target_user_id = ? AND kind = 'block'
                """,
                values: [.text(sourceUserID), .text(targetUserID)]
            )
        }
        NotificationCenter.default.post(
            name: .runQSocialDataDidChange,
            object: self,
            userInfo: [
                "sourceUserID": sourceUserID,
                "targetUserID": targetUserID,
                "isBlocked": isBlocked
            ]
        )
        NotificationCenter.default.post(
            name: .runQChatRoomsDidChange,
            object: self
        )
    }

    func isFollowing(sourceUserID: String, targetUserID: String) -> Bool {
        (try? relationExists(
            sourceUserID: sourceUserID,
            targetUserID: targetUserID,
            kind: "follow"
        )) ?? false
    }

    func areMutuallyFollowing(userID: String, otherUserID: String) -> Bool {
        guard userID != otherUserID else { return false }
        return isFollowing(
            sourceUserID: userID,
            targetUserID: otherUserID
        ) && isFollowing(
            sourceUserID: otherUserID,
            targetUserID: userID
        )
    }

    func setFollowing(
        sourceUserID: String,
        targetUserID: String,
        isFollowing: Bool
    ) throws {
        guard sourceUserID != targetUserID else { return }
        if isFollowing {
            guard isUserVisible(targetUserID, to: sourceUserID) else {
                throw RunQDataError.invalidCredentials
            }
            try execute(
                """
                INSERT OR IGNORE INTO user_relations
                (id, source_user_id, target_user_id, kind, created_at)
                VALUES (?, ?, ?, 'follow', ?)
                """,
                values: [
                    .text("follow-\(sourceUserID)-\(targetUserID)"),
                    .text(sourceUserID), .text(targetUserID),
                    .double(Date().timeIntervalSince1970)
                ]
            )
        } else {
            try execute(
                """
                DELETE FROM user_relations
                WHERE source_user_id = ? AND target_user_id = ? AND kind = 'follow'
                """,
                values: [.text(sourceUserID), .text(targetUserID)]
            )
        }
        NotificationCenter.default.post(
            name: .runQSocialDataDidChange,
            object: self,
            userInfo: [
                "sourceUserID": sourceUserID,
                "targetUserID": targetUserID,
                "isFollowing": isFollowing
            ]
        )
    }

    func removeFollower(userID: String, followerID: String) throws {
        try setFollowing(
            sourceUserID: followerID,
            targetUserID: userID,
            isFollowing: false
        )
    }

    func ensureSocialData(for userID: String) throws {
        let markerKey = "social-data-v2-\(userID)"
        let blockCleanupKey = "social-block-cleanup-v1-\(userID)"
        let seedIDs = users
            .filter { $0.id.hasPrefix("seed-user-") && $0.id != userID }
            .map(\.id)
        if try metadataValue(for: markerKey) == nil {
            let followingIDs = Array(seedIDs.prefix(3))
            for targetID in followingIDs {
                try setFollowing(
                    sourceUserID: userID,
                    targetUserID: targetID,
                    isFollowing: true
                )
            }
            let followerIDs = Array(followingIDs.prefix(1))
                + Array(seedIDs.dropFirst(3).prefix(2))
            for followerID in followerIDs {
                try setFollowing(
                    sourceUserID: followerID,
                    targetUserID: userID,
                    isFollowing: true
                )
            }
            try execute(
                "INSERT OR REPLACE INTO metadata (key, value) VALUES (?, '1')",
                values: [.text(markerKey)]
            )
        }
        if try metadataValue(for: blockCleanupKey) == nil {
            for targetID in seedIDs.reversed().prefix(3) {
                try execute(
                    """
                    DELETE FROM user_relations
                    WHERE source_user_id = ? AND target_user_id = ? AND kind = 'block'
                    """,
                    values: [.text(userID), .text(targetID)]
                )
            }
            try execute(
                "INSERT OR REPLACE INTO metadata (key, value) VALUES (?, '1')",
                values: [.text(blockCleanupKey)]
            )
        }
        try execute(
            """
            INSERT OR REPLACE INTO ai_messages
            (id, user_id, text, is_from_user, created_at)
            VALUES (?, ?, ?, 0, 1)
            """,
            values: [
                .text("seed-ai-\(userID)-welcome"),
                .text(userID),
                .text(
                    "Hello, is there anything you would like to ask me about outdoor fitness or outdoor sports such as surfing, skydiving, rock climbing, etc.?"
                )
            ]
        )
    }

    func profileDetails(for userID: String) -> RunQProfileDetails {
        guard let statement = try? prepare(
            "SELECT birthday, location, avatar_data FROM user_profiles WHERE user_id = ?",
            values: [.text(userID)]
        ) else {
            return RunQProfileDetails(birthday: "", location: "", avatarData: nil)
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return RunQProfileDetails(birthday: "", location: "", avatarData: nil)
        }
        return RunQProfileDetails(
            birthday: text(statement, 0),
            location: text(statement, 1),
            avatarData: data(statement, 2)
        )
    }

    func updateProfile(
        userID: String,
        name: String,
        gender: String,
        birthday: String,
        location: String,
        biography: String,
        avatarData: Data?
    ) throws -> RunQUserRecord {
        try transaction {
            try execute(
                "UPDATE users SET username = ?, gender = ?, biography = ? WHERE id = ?",
                values: [
                    .text(name), .text(gender.lowercased()),
                    .text(biography), .text(userID)
                ]
            )
            try execute(
                """
                INSERT OR REPLACE INTO user_profiles
                (user_id, birthday, location, avatar_data) VALUES (?, ?, ?, ?)
                """,
                values: [
                    .text(userID), .text(birthday), .text(location),
                    avatarData.map(SQLiteValue.blob) ?? .null
                ]
            )
        }
        try refresh()
        return try requiredUser(id: userID)
    }

    func comments(
        for postID: String,
        visibleTo userID: String? = nil
    ) -> [RunQCommentRecord] {
        guard let statement = try? prepare(
            """
            SELECT c.id, c.post_id, c.author_id, COALESCE(u.username, 'Member'),
                   COALESCE(u.avatar_asset_name, 'runq_square_author_avatar'),
                   p.avatar_data, c.text, c.created_at
            FROM comments c LEFT JOIN users u ON u.id = c.author_id
            LEFT JOIN user_profiles p ON p.user_id = c.author_id
            WHERE c.post_id = ? ORDER BY c.created_at
            """,
            values: [.text(postID)]
        ) else { return [] }
        defer { sqlite3_finalize(statement) }
        var result: [RunQCommentRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(
                RunQCommentRecord(
                    id: text(statement, 0), postID: text(statement, 1),
                    authorID: nullableText(statement, 2),
                    authorName: text(statement, 3),
                    authorAvatarAssetName: text(statement, 4),
                    authorAvatarData: data(statement, 5),
                    text: text(statement, 6),
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))
                )
            )
        }
        return result.filter { comment in
            guard let authorID = comment.authorID else { return true }
            return isUserVisible(authorID, to: userID)
        }
    }

    @discardableResult
    func addComment(
        postID: String,
        authorID: String,
        text: String
    ) throws -> RunQCommentRecord {
        guard let post = posts.first(where: { $0.id == postID }),
              isUserVisible(post.authorID, to: authorID) else {
            throw RunQDataError.invalidCredentials
        }
        let id = UUID().uuidString.lowercased()
        let createdAt = Date()
        try execute(
            """
            INSERT INTO comments (id, post_id, author_id, text, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            values: [
                .text(id), .text(postID), .text(authorID), .text(text),
                .double(createdAt.timeIntervalSince1970)
            ]
        )
        try refresh()
        guard let comment = comments(
            for: postID,
            visibleTo: authorID
        ).first(where: { $0.id == id }) else {
            throw RunQDataError.persistenceFailure
        }
        return comment
    }

    func createPost(
        authorID: String,
        text: String,
        tags: [String],
        imageDataItems: [Data],
        type: RunQPostType
    ) throws {
        let postID = UUID().uuidString.lowercased()
        try transaction {
            try execute(
                """
                INSERT INTO posts
                (id, author_id, text, image_source, image_asset_name,
                 created_at, like_count, post_type)
                VALUES (?, ?, ?, '', 'runq_square_surf_photo', ?, 0, ?)
                """,
                values: [
                    .text(postID), .text(authorID), .text(text),
                    .double(Date().timeIntervalSince1970), .text(type.rawValue)
                ]
            )
            for (index, imageData) in imageDataItems.prefix(3).enumerated() {
                try execute(
                    "INSERT INTO post_media (post_id, sort_order, image_data) VALUES (?, ?, ?)",
                    values: [
                        .text(postID), .integer(index), .blob(imageData)
                    ]
                )
            }
            for rawTag in tags.prefix(5) {
                let tag = rawTag.hasPrefix("#") ? rawTag : "#\(rawTag)"
                let tagID = "tag-\(Self.slug(tag))"
                try execute(
                    "INSERT OR IGNORE INTO tags (id, name) VALUES (?, ?)",
                    values: [.text(tagID), .text(tag)]
                )
                try execute(
                    "INSERT OR IGNORE INTO post_tags (post_id, tag_id) VALUES (?, ?)",
                    values: [.text(postID), .text(tagID)]
                )
            }
        }
        try refresh()
    }

    func chatRooms(visibleTo userID: String? = nil) -> [RunQChatRoomRecord] {
        guard let statement = try? prepare(
            """
            SELECT c.id, c.name, c.participant_limit,
                   (SELECT COUNT(*) FROM chatbox_members m WHERE m.chatbox_id = c.id),
                   c.avatar_data, c.created_by,
                   COALESCE(owner.avatar_asset_name, 'runq_square_buddy_avatar'),
                   owner_profile.avatar_data,
                   (SELECT COUNT(*)
                    FROM chatbox_members male_member
                    JOIN users male_user ON male_user.id = male_member.user_id
                    WHERE male_member.chatbox_id = c.id
                      AND LOWER(male_user.gender) = 'male'),
                   (SELECT COUNT(*)
                    FROM chatbox_members female_member
                    JOIN users female_user ON female_user.id = female_member.user_id
                    WHERE female_member.chatbox_id = c.id
                      AND LOWER(female_user.gender) = 'female')
            FROM chatboxes c
            LEFT JOIN users owner ON owner.id = c.created_by
            LEFT JOIN user_profiles owner_profile ON owner_profile.user_id = c.created_by
            ORDER BY c.created_at DESC
            """
        ) else { return [] }
        defer { sqlite3_finalize(statement) }
        var result: [RunQChatRoomRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(
                RunQChatRoomRecord(
                    id: text(statement, 0), name: text(statement, 1),
                    participantLimit: Int(sqlite3_column_int(statement, 2)),
                    participantCount: Int(sqlite3_column_int(statement, 3)),
                    avatarData: data(statement, 4),
                    createdBy: text(statement, 5),
                    ownerAvatarAssetName: text(statement, 6),
                    ownerAvatarData: data(statement, 7),
                    maleParticipantCount: Int(sqlite3_column_int(statement, 8)),
                    femaleParticipantCount: Int(sqlite3_column_int(statement, 9))
                )
            )
        }
        let visibleRooms = result.filter {
            isUserVisible($0.createdBy, to: userID)
        }
        guard let userID else { return visibleRooms }
        return visibleRooms.map { room in
            let visibleMembers = chatRoomMembers(
                roomID: room.id,
                visibleTo: userID
            )
            return RunQChatRoomRecord(
                id: room.id,
                name: room.name,
                participantLimit: room.participantLimit,
                participantCount: visibleMembers.count,
                avatarData: room.avatarData,
                createdBy: room.createdBy,
                ownerAvatarAssetName: room.ownerAvatarAssetName,
                ownerAvatarData: room.ownerAvatarData,
                maleParticipantCount: visibleMembers.filter {
                    $0.gender.lowercased() == "male"
                }.count,
                femaleParticipantCount: visibleMembers.filter {
                    $0.gender.lowercased() == "female"
                }.count
            )
        }
    }

    func nextChatRoomID() -> String {
        guard let statement = try? prepare(
            "SELECT COALESCE(MAX(CAST(id AS INTEGER)), 1000783) + 1 FROM chatboxes"
        ) else { return "1000784" }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return "1000784" }
        return String(sqlite3_column_int64(statement, 0))
    }

    func createChatRoom(
        id: String,
        ownerID: String,
        name: String,
        key: String,
        participantLimit: Int,
        avatarData: Data?
    ) throws {
        try transaction {
            try execute(
                """
                INSERT INTO chatboxes
                (id, name, access_key, participant_limit, avatar_data, created_by, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                values: [
                    .text(id), .text(name), .text(key), .integer(participantLimit),
                    avatarData.map(SQLiteValue.blob) ?? .null,
                    .text(ownerID), .double(Date().timeIntervalSince1970)
                ]
            )
            try execute(
                "INSERT INTO chatbox_members (chatbox_id, user_id, joined_at) VALUES (?, ?, ?)",
                values: [.text(id), .text(ownerID), .double(Date().timeIntervalSince1970)]
            )
        }
        NotificationCenter.default.post(
            name: .runQChatRoomsDidChange,
            object: self,
            userInfo: ["roomID": id]
        )
    }

    func joinChatRoom(roomID: String, userID: String, key: String) throws {
        let statement = try prepare(
            "SELECT access_key FROM chatboxes WHERE id = ?",
            values: [.text(roomID)]
        )
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              text(statement, 0) == key else {
            throw RunQDataError.invalidCredentials
        }
        try execute(
            "INSERT OR IGNORE INTO chatbox_members (chatbox_id, user_id, joined_at) VALUES (?, ?, ?)",
            values: [.text(roomID), .text(userID), .double(Date().timeIntervalSince1970)]
        )
        NotificationCenter.default.post(
            name: .runQChatRoomsDidChange,
            object: self,
            userInfo: ["roomID": roomID]
        )
    }

    func isChatRoomMember(roomID: String, userID: String) -> Bool {
        guard let statement = try? prepare(
            "SELECT 1 FROM chatbox_members WHERE chatbox_id = ? AND user_id = ? LIMIT 1",
            values: [.text(roomID), .text(userID)]
        ) else { return false }
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW
    }

    func chatRoomMembers(
        roomID: String,
        visibleTo userID: String? = nil
    ) -> [RunQUserRecord] {
        guard let statement = try? prepare(
            """
            SELECT u.id, u.email, u.username, u.gender, u.age, u.category,
                   u.certificate, u.avatar_asset_name, u.biography, u.is_guest
            FROM chatbox_members m
            JOIN chatboxes c ON c.id = m.chatbox_id
            JOIN users u ON u.id = m.user_id
            WHERE m.chatbox_id = ?
            ORDER BY CASE WHEN u.id = c.created_by THEN 0 ELSE 1 END,
                     m.joined_at, u.created_at
            """,
            values: [.text(roomID)]
        ) else { return [] }
        defer { sqlite3_finalize(statement) }
        var result: [RunQUserRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(userRecord(from: statement))
        }
        return result.filter { isUserVisible($0.id, to: userID) }
    }

    func chatMessages(
        roomID: String,
        visibleTo userID: String? = nil
    ) -> [RunQChatMessageRecord] {
        guard let statement = try? prepare(
            """
            SELECT m.id, m.chatbox_id, m.author_id, u.username,
                   u.avatar_asset_name, m.text, m.audio_data,
                   m.audio_duration, m.created_at
            FROM chatbox_messages m
            JOIN users u ON u.id = m.author_id
            WHERE m.chatbox_id = ?
            ORDER BY m.created_at
            """,
            values: [.text(roomID)]
        ) else { return [] }
        defer { sqlite3_finalize(statement) }
        var result: [RunQChatMessageRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(
                RunQChatMessageRecord(
                    id: text(statement, 0), roomID: text(statement, 1),
                    authorID: text(statement, 2), authorName: text(statement, 3),
                    authorAvatarAssetName: text(statement, 4), text: text(statement, 5),
                    audioData: data(statement, 6),
                    audioDuration: sqlite3_column_double(statement, 7),
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 8))
                )
            )
        }
        return result.filter { isUserVisible($0.authorID, to: userID) }
    }

    func sendChatMessage(roomID: String, authorID: String, text: String) throws {
        guard isChatRoomMember(roomID: roomID, userID: authorID),
              chatRooms(visibleTo: authorID).contains(where: { $0.id == roomID }) else {
            throw RunQDataError.invalidCredentials
        }
        try execute(
            """
            INSERT INTO chatbox_messages
            (id, chatbox_id, author_id, text, created_at) VALUES (?, ?, ?, ?, ?)
            """,
            values: [
                .text(UUID().uuidString.lowercased()), .text(roomID), .text(authorID),
                .text(text), .double(Date().timeIntervalSince1970)
            ]
        )
    }

    func sendChatVoiceMessage(
        roomID: String,
        authorID: String,
        audioData: Data,
        duration: TimeInterval
    ) throws {
        guard !audioData.isEmpty, duration > 0,
              isChatRoomMember(roomID: roomID, userID: authorID),
              chatRooms(visibleTo: authorID).contains(where: { $0.id == roomID }) else {
            throw RunQDataError.invalidCredentials
        }
        try execute(
            """
            INSERT INTO chatbox_messages
            (id, chatbox_id, author_id, text, audio_data, audio_duration, created_at)
            VALUES (?, ?, ?, '', ?, ?, ?)
            """,
            values: [
                .text(UUID().uuidString.lowercased()),
                .text(roomID),
                .text(authorID),
                .blob(audioData),
                .double(duration),
                .double(Date().timeIntervalSince1970)
            ]
        )
    }

    func directMessages(userID: String, peerID: String) -> [RunQDirectMessageRecord] {
        guard isUserVisible(peerID, to: userID) else { return [] }
        guard let statement = try? prepare(
            """
            SELECT m.id, m.sender_id, m.receiver_id, u.username,
                   u.avatar_asset_name, m.text, m.audio_data,
                   m.audio_duration, m.created_at
            FROM direct_messages m
            JOIN users u ON u.id = m.sender_id
            WHERE (m.sender_id = ? AND m.receiver_id = ?)
               OR (m.sender_id = ? AND m.receiver_id = ?)
            ORDER BY m.created_at
            """,
            values: [.text(userID), .text(peerID), .text(peerID), .text(userID)]
        ) else { return [] }
        defer { sqlite3_finalize(statement) }
        var result: [RunQDirectMessageRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(
                RunQDirectMessageRecord(
                    id: text(statement, 0),
                    senderID: text(statement, 1),
                    receiverID: text(statement, 2),
                    senderName: text(statement, 3),
                    senderAvatarAssetName: text(statement, 4),
                    text: text(statement, 5),
                    audioData: data(statement, 6),
                    audioDuration: sqlite3_column_double(statement, 7),
                    createdAt: Date(
                        timeIntervalSince1970: sqlite3_column_double(statement, 8)
                    )
                )
            )
        }
        return result
    }

    func directConversations(userID: String) -> [RunQDirectConversationRecord] {
        guard let statement = try? prepare(
            """
            SELECT u.id, u.email, u.username, u.gender, u.age, u.category,
                   u.certificate, u.avatar_asset_name, u.biography, u.is_guest,
                   m.text, m.audio_data IS NOT NULL, m.created_at
            FROM users u
            JOIN direct_messages m ON m.rowid = (
                SELECT dm.rowid
                FROM direct_messages dm
                WHERE (dm.sender_id = ? AND dm.receiver_id = u.id)
                   OR (dm.sender_id = u.id AND dm.receiver_id = ?)
                ORDER BY dm.created_at DESC, dm.rowid DESC
                LIMIT 1
            )
            WHERE u.id != ?
            ORDER BY m.created_at DESC, m.rowid DESC
            """,
            values: [.text(userID), .text(userID), .text(userID)]
        ) else { return [] }
        defer { sqlite3_finalize(statement) }
        var result: [RunQDirectConversationRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let textPreview = text(statement, 10)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let isVoiceMessage = sqlite3_column_int(statement, 11) == 1
            result.append(
                RunQDirectConversationRecord(
                    peer: userRecord(from: statement),
                    preview: isVoiceMessage ? "[Voice]" : textPreview,
                    createdAt: Date(
                        timeIntervalSince1970: sqlite3_column_double(statement, 12)
                    )
                )
            )
        }
        return result.filter { isUserVisible($0.peer.id, to: userID) }
    }

    func sendDirectMessage(senderID: String, receiverID: String, text: String) throws {
        try insertDirectMessage(
            senderID: senderID,
            receiverID: receiverID,
            text: text,
            audioData: nil,
            audioDuration: 0
        )
    }

    func sendDirectVoiceMessage(
        senderID: String,
        receiverID: String,
        audioData: Data,
        duration: TimeInterval
    ) throws {
        guard !audioData.isEmpty, duration > 0 else {
            throw RunQDataError.persistenceFailure
        }
        try insertDirectMessage(
            senderID: senderID,
            receiverID: receiverID,
            text: "",
            audioData: audioData,
            audioDuration: duration
        )
    }

    private func insertDirectMessage(
        senderID: String,
        receiverID: String,
        text: String,
        audioData: Data?,
        audioDuration: TimeInterval
    ) throws {
        guard isUserVisible(receiverID, to: senderID) else {
            throw RunQDataError.invalidCredentials
        }
        try execute(
            """
            INSERT INTO direct_messages
            (id, sender_id, receiver_id, text, audio_data, audio_duration, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            values: [
                .text(UUID().uuidString.lowercased()),
                .text(senderID), .text(receiverID), .text(text),
                audioData.map(SQLiteValue.blob) ?? .null,
                .double(audioDuration), .double(Date().timeIntervalSince1970)
            ]
        )
    }

    func aiMessages(for userID: String) -> [RunQAIMessageRecord] {
        guard let statement = try? prepare(
            "SELECT id, text, is_from_user, created_at FROM ai_messages WHERE user_id = ? ORDER BY created_at",
            values: [.text(userID)]
        ) else { return [] }
        defer { sqlite3_finalize(statement) }
        var result: [RunQAIMessageRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(
                RunQAIMessageRecord(
                    id: text(statement, 0), text: text(statement, 1),
                    isFromCurrentUser: sqlite3_column_int(statement, 2) == 1,
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
                )
            )
        }
        return result
    }

    func addAIExchange(
        userID: String,
        userText: String,
        replyText: String
    ) throws {
        let createdAt = Date().timeIntervalSince1970
        try transaction {
            try execute(
                """
                INSERT INTO ai_messages
                (id, user_id, text, is_from_user, created_at)
                VALUES (?, ?, ?, 1, ?)
                """,
                values: [
                    .text(UUID().uuidString.lowercased()),
                    .text(userID), .text(userText), .double(createdAt)
                ]
            )
            try execute(
                """
                INSERT INTO ai_messages
                (id, user_id, text, is_from_user, created_at)
                VALUES (?, ?, ?, 0, ?)
                """,
                values: [
                    .text(UUID().uuidString.lowercased()),
                    .text(userID), .text(replyText),
                    .double(createdAt + 0.001)
                ]
            )
        }
    }

    func walletBalance(for userID: String) -> Int {
        guard let statement = try? prepare(
            "SELECT balance FROM wallet_accounts WHERE user_id = ?",
            values: [.text(userID)]
        ) else { return 0 }
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW
            ? Int(sqlite3_column_int(statement, 0))
            : 0
    }

    func setWalletBalance(_ balance: Int, for userID: String) throws {
        guard balance >= 0 else {
            throw RunQDataError.persistenceFailure
        }
        try execute(
            """
            INSERT INTO wallet_accounts (user_id, balance) VALUES (?, ?)
            ON CONFLICT(user_id) DO UPDATE SET balance = excluded.balance
            """,
            values: [.text(userID), .integer(balance)]
        )
    }

    func createReservation(_ reservation: RunQReservationRecord) throws {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "MMM,d"
        let dateText = dateFormatter.string(from: reservation.startDate)
        let activity = reservation.activity
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
        let attendanceText = reservation.attendance >= 4
            ? "4+ attendees"
            : "\(reservation.attendance) attendee\(reservation.attendance == 1 ? "" : "s")"
        let location = reservation.location.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let details = location.isEmpty
            ? "\(activity) reservation with \(attendanceText)"
            : "\(activity) reservation with \(attendanceText) at \(location)"

        try transaction {
            try execute(
                """
                INSERT INTO reservations
                (id, requester_id, target_user_id, activity, start_date, end_date,
                 attendance, location, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                values: [
                    .text(reservation.id), .text(reservation.requesterID),
                    .text(reservation.targetUserID),
                    .text(reservation.activity),
                    .double(reservation.startDate.timeIntervalSince1970),
                    .double(reservation.endDate.timeIntervalSince1970),
                    .integer(reservation.attendance),
                    .text(reservation.location),
                    .double(reservation.createdAt.timeIntervalSince1970)
                ]
            )
            try execute(
                """
                INSERT INTO itineraries
                (id, user_id, date_text, details, sort_order)
                VALUES (?, ?, ?, ?, ?)
                """,
                values: [
                    .text("reservation-\(reservation.id)"),
                    .text(reservation.targetUserID),
                    .text(dateText),
                    .text(details),
                    .integer(-Int(reservation.createdAt.timeIntervalSince1970))
                ]
            )
        }
        NotificationCenter.default.post(
            name: .runQReservationsDidChange,
            object: self,
            userInfo: [
                "requesterID": reservation.requesterID,
                "targetUserID": reservation.targetUserID
            ]
        )
        NotificationCenter.default.post(
            name: .runQItinerariesDidChange,
            object: self,
            userInfo: ["userID": reservation.targetUserID]
        )
    }

    func reservations(for userID: String) -> [RunQReservationRecord] {
        guard let statement = try? prepare(
            """
            SELECT id, requester_id, target_user_id, activity, start_date,
                   end_date, attendance, location, created_at
            FROM reservations
            WHERE requester_id = ? OR target_user_id = ?
            ORDER BY created_at DESC
            """,
            values: [.text(userID), .text(userID)]
        ) else { return [] }
        defer { sqlite3_finalize(statement) }
        var records: [RunQReservationRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            records.append(
                RunQReservationRecord(
                    id: text(statement, 0),
                    requesterID: text(statement, 1),
                    targetUserID: text(statement, 2),
                    activity: text(statement, 3),
                    startDate: Date(
                        timeIntervalSince1970: sqlite3_column_double(statement, 4)
                    ),
                    endDate: Date(
                        timeIntervalSince1970: sqlite3_column_double(statement, 5)
                    ),
                    attendance: Int(sqlite3_column_int(statement, 6)),
                    location: text(statement, 7),
                    createdAt: Date(
                        timeIntervalSince1970: sqlite3_column_double(statement, 8)
                    )
                )
            )
        }
        return records
    }

    func deactivateUser(id: String) throws {
        try execute(
            "UPDATE users SET is_deleted = 1 WHERE id = ? AND is_deleted = 0",
            values: [.text(id)]
        )
        guard sqlite3_changes(database) > 0 else {
            throw RunQDataError.accountNotFound
        }
        try refresh()
        NotificationCenter.default.post(
            name: .runQSocialDataDidChange,
            object: self,
            userInfo: ["deactivatedUserID": id]
        )
        NotificationCenter.default.post(
            name: .runQChatRoomsDidChange,
            object: self,
            userInfo: ["deactivatedUserID": id]
        )
        NotificationCenter.default.post(
            name: .runQReservationsDidChange,
            object: self,
            userInfo: ["deactivatedUserID": id]
        )
    }

    private func createSchema() throws {
        try execute("PRAGMA foreign_keys = ON")
        try executeScript(
            """
            CREATE TABLE IF NOT EXISTS metadata (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY NOT NULL,
                email TEXT UNIQUE NOT NULL,
                username TEXT NOT NULL,
                password TEXT NOT NULL,
                gender TEXT NOT NULL,
                age INTEGER NOT NULL,
                category TEXT NOT NULL,
                certificate TEXT NOT NULL,
                avatar_source TEXT NOT NULL,
                avatar_asset_name TEXT NOT NULL,
                biography TEXT NOT NULL,
                affinities TEXT NOT NULL,
                is_guest INTEGER NOT NULL,
                is_deleted INTEGER NOT NULL DEFAULT 0,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS itineraries (
                id TEXT PRIMARY KEY NOT NULL,
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                date_text TEXT NOT NULL,
                details TEXT NOT NULL,
                sort_order INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS posts (
                id TEXT PRIMARY KEY NOT NULL,
                author_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                text TEXT NOT NULL,
                image_source TEXT NOT NULL,
                image_asset_name TEXT NOT NULL,
                created_at REAL NOT NULL,
                like_count INTEGER NOT NULL,
                post_type TEXT NOT NULL DEFAULT 'news'
            );
            CREATE TABLE IF NOT EXISTS tags (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT UNIQUE NOT NULL
            );
            CREATE TABLE IF NOT EXISTS post_tags (
                post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
                tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
                PRIMARY KEY (post_id, tag_id)
            );
            CREATE TABLE IF NOT EXISTS post_likes (
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
                created_at REAL NOT NULL,
                PRIMARY KEY (user_id, post_id)
            );
            CREATE TABLE IF NOT EXISTS comments (
                id TEXT PRIMARY KEY NOT NULL,
                post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
                author_id TEXT,
                text TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS videos (
                id TEXT PRIMARY KEY NOT NULL,
                author_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                feed_section TEXT NOT NULL DEFAULT 'recommend',
                media_file_name TEXT NOT NULL,
                fallback_image_asset_name TEXT NOT NULL,
                caption TEXT NOT NULL,
                created_at REAL NOT NULL,
                like_count INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS video_tags (
                video_id TEXT NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
                tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
                PRIMARY KEY (video_id, tag_id)
            );
            CREATE TABLE IF NOT EXISTS video_likes (
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                video_id TEXT NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
                created_at REAL NOT NULL,
                PRIMARY KEY (user_id, video_id)
            );
            CREATE TABLE IF NOT EXISTS video_comments (
                id TEXT PRIMARY KEY NOT NULL,
                video_id TEXT NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
                author_id TEXT REFERENCES users(id) ON DELETE SET NULL,
                text TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS user_relations (
                id TEXT PRIMARY KEY NOT NULL,
                source_user_id TEXT NOT NULL,
                target_user_id TEXT NOT NULL,
                kind TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS user_profiles (
                user_id TEXT PRIMARY KEY NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                birthday TEXT NOT NULL,
                location TEXT NOT NULL,
                avatar_data BLOB
            );
            CREATE TABLE IF NOT EXISTS post_media (
                post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
                sort_order INTEGER NOT NULL,
                image_data BLOB NOT NULL,
                PRIMARY KEY (post_id, sort_order)
            );
            CREATE TABLE IF NOT EXISTS chatboxes (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                access_key TEXT NOT NULL,
                participant_limit INTEGER NOT NULL,
                avatar_data BLOB,
                created_by TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS chatbox_members (
                chatbox_id TEXT NOT NULL REFERENCES chatboxes(id) ON DELETE CASCADE,
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                joined_at REAL NOT NULL,
                PRIMARY KEY (chatbox_id, user_id)
            );
            CREATE TABLE IF NOT EXISTS chatbox_messages (
                id TEXT PRIMARY KEY NOT NULL,
                chatbox_id TEXT NOT NULL REFERENCES chatboxes(id) ON DELETE CASCADE,
                author_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                text TEXT NOT NULL,
                audio_data BLOB,
                audio_duration REAL NOT NULL DEFAULT 0,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS direct_messages (
                id TEXT PRIMARY KEY NOT NULL,
                sender_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                receiver_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                text TEXT NOT NULL,
                audio_data BLOB,
                audio_duration REAL NOT NULL DEFAULT 0,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS ai_messages (
                id TEXT PRIMARY KEY NOT NULL,
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                text TEXT NOT NULL,
                is_from_user INTEGER NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS wallet_accounts (
                user_id TEXT PRIMARY KEY NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                balance INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS reservations (
                id TEXT PRIMARY KEY NOT NULL,
                requester_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                target_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                activity TEXT NOT NULL DEFAULT 'other',
                start_date REAL NOT NULL,
                end_date REAL NOT NULL,
                attendance INTEGER NOT NULL DEFAULT 1,
                location TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            """
        )
        try migrateLegacyPasswordColumnIfNeeded()
        try migrateVideoFeedSectionIfNeeded()
        try migratePostMediaSortOrderIfNeeded()
        try migratePostTypeIfNeeded()
        try migrateChatboxVoiceColumnsIfNeeded()
        try migrateReservationColumnsIfNeeded()
        try migrateUserDeletionColumnIfNeeded()
    }

    private func migrateLegacyPasswordColumnIfNeeded() throws {
        guard try !tableHasColumn("password", in: "users") else { return }
        try execute(
            "ALTER TABLE users ADD COLUMN password TEXT NOT NULL DEFAULT ''"
        )
        try execute(
            "UPDATE users SET password = '123456' WHERE id LIKE 'seed-user-%'"
        )
    }

    private func migrateVideoFeedSectionIfNeeded() throws {
        guard try !tableHasColumn("feed_section", in: "videos") else { return }
        try execute(
            "ALTER TABLE videos ADD COLUMN feed_section TEXT NOT NULL DEFAULT 'recommend'"
        )
    }

    private func migratePostMediaSortOrderIfNeeded() throws {
        guard try !tableHasColumn("sort_order", in: "post_media") else {
            return
        }
        try execute("ALTER TABLE post_media RENAME TO post_media_legacy")
        try executeScript(
            """
            CREATE TABLE post_media (
                post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
                sort_order INTEGER NOT NULL,
                image_data BLOB NOT NULL,
                PRIMARY KEY (post_id, sort_order)
            );
            INSERT INTO post_media (post_id, sort_order, image_data)
            SELECT post_id, 0, image_data FROM post_media_legacy;
            DROP TABLE post_media_legacy;
            """
        )
    }

    private func migratePostTypeIfNeeded() throws {
        guard try !tableHasColumn("post_type", in: "posts") else { return }
        try execute(
            "ALTER TABLE posts ADD COLUMN post_type TEXT NOT NULL DEFAULT 'news'"
        )
    }

    private func migrateChatboxVoiceColumnsIfNeeded() throws {
        if try !tableHasColumn("audio_data", in: "chatbox_messages") {
            try execute("ALTER TABLE chatbox_messages ADD COLUMN audio_data BLOB")
        }
        if try !tableHasColumn("audio_duration", in: "chatbox_messages") {
            try execute(
                "ALTER TABLE chatbox_messages ADD COLUMN audio_duration REAL NOT NULL DEFAULT 0"
            )
        }
    }

    private func migrateReservationColumnsIfNeeded() throws {
        if try !tableHasColumn("activity", in: "reservations") {
            try execute(
                "ALTER TABLE reservations ADD COLUMN activity TEXT NOT NULL DEFAULT 'other'"
            )
        }
        if try !tableHasColumn("attendance", in: "reservations") {
            try execute(
                "ALTER TABLE reservations ADD COLUMN attendance INTEGER NOT NULL DEFAULT 1"
            )
        }
    }

    private func migrateUserDeletionColumnIfNeeded() throws {
        guard try !tableHasColumn("is_deleted", in: "users") else { return }
        try execute(
            "ALTER TABLE users ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0"
        )
    }

    private func tableHasColumn(_ column: String, in table: String) throws -> Bool {
        let statement = try prepare("PRAGMA table_info(\(table))")
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            if text(statement, 1) == column { return true }
        }
        return false
    }

    private func migrateLegacyDefaultAvatar() throws {
        try execute(
            "UPDATE users SET avatar_asset_name = ? WHERE avatar_asset_name = ?",
            values: [
                .text("runq_profile_default_avatar"),
                .text("runq_profile_avatar_refresh")
            ]
        )
    }

    private func seedSharedReferenceData() throws {
        try execute(
            "UPDATE users SET email = 'test@gmail.com' WHERE id = 'seed-user-1'"
        )
        for (index, avatarAssetName) in avatarAssets.enumerated() {
            try execute(
                "UPDATE users SET avatar_asset_name = ? WHERE id = ?",
                values: [
                    .text(avatarAssetName),
                    .text("seed-user-\(index + 1)")
                ]
            )
        }
        try execute(
            "DELETE FROM ai_messages WHERE id LIKE 'seed-ai-%-activities'"
        )
        try execute(
            """
            INSERT OR IGNORE INTO user_profiles (user_id, birthday, location, avatar_data)
            SELECT id, '', '', NULL FROM users
            """
        )
        try execute(
            """
            INSERT OR IGNORE INTO wallet_accounts (user_id, balance)
            SELECT id, 0 FROM users
            """
        )
        let zeroBalanceMigrationKey = "wallet-initial-zero-v1"
        if try metadataValue(for: zeroBalanceMigrationKey) == nil {
            try execute(
                "INSERT OR REPLACE INTO metadata (key, value) VALUES (?, '1')",
                values: [.text(zeroBalanceMigrationKey)]
            )
        }
        let starterPostAssetMigrationKey = "starter-post-assets-1-through-8-v1"
        if try metadataValue(for: starterPostAssetMigrationKey) == nil {
            for (index, assetName) in postAssets.enumerated() {
                try execute(
                    "UPDATE posts SET image_asset_name = ? WHERE id = ?",
                    values: [
                        .text(assetName),
                        .text("seed-post-\(index + 1)")
                    ]
                )
            }
            try execute(
                "INSERT OR REPLACE INTO metadata (key, value) VALUES (?, '1')",
                values: [.text(starterPostAssetMigrationKey)]
            )
        }
        for userIndex in 1...8 {
            for offset in 1...2 {
                let postIndex = ((userIndex + offset - 1) % 8) + 1
                try execute(
                    """
                    INSERT OR IGNORE INTO post_likes
                    (user_id, post_id, created_at) VALUES (?, ?, ?)
                    """,
                    values: [
                        .text("seed-user-\(userIndex)"),
                        .text("seed-post-\(postIndex)"),
                        .double(Double(10 - offset))
                    ]
                )
            }
        }
        try execute(
            """
            INSERT OR IGNORE INTO chatboxes
            (id, name, access_key, participant_limit, avatar_data, created_by, created_at)
            VALUES ('1000784', 'ANYONE GOING SURFING AT ZUMA BEACH THIS WEEKEND?',
                    '123456', 44, NULL, 'seed-user-1', 1)
            """
        )
        try execute(
            """
            UPDATE chatbox_messages
            SET author_id = 'seed-user-2',
                text = 'I checked the forecast. Saturday morning looks great.'
            WHERE id = 'seed-chat-message-1'
            """
        )
        try execute(
            """
            INSERT OR IGNORE INTO direct_messages
            (id, sender_id, receiver_id, text, audio_data, audio_duration, created_at)
            VALUES ('seed-direct-message-1', 'seed-user-1', 'seed-user-2',
                    'Hey there! I noticed you are interested in skiing.', NULL, 0, 1)
            """
        )
        try execute(
            """
            INSERT OR IGNORE INTO direct_messages
            (id, sender_id, receiver_id, text, audio_data, audio_duration, created_at)
            VALUES ('seed-direct-message-2', 'seed-user-1', 'seed-user-2',
                    'I am planning a trip to Snow Summit this weekend. Would you like to join?', NULL, 0, 2)
            """
        )
        try execute(
            """
            INSERT OR IGNORE INTO direct_messages
            (id, sender_id, receiver_id, text, audio_data, audio_duration, created_at)
            VALUES ('seed-direct-message-3', 'seed-user-2', 'seed-user-1',
                    'Hi! Thanks for reaching out. I have been wanting to go skiing for ages! I would love to join you.', NULL, 0, 3)
            """
        )
        try execute(
            """
            INSERT OR IGNORE INTO direct_messages
            (id, sender_id, receiver_id, text, audio_data, audio_duration, created_at)
            VALUES ('seed-direct-message-4', 'seed-user-3', 'seed-user-1',
                    'Hi Ethan! Are you available for a diving session this weekend?', NULL, 0, 4)
            """
        )
        try execute(
            """
            INSERT OR IGNORE INTO direct_messages
            (id, sender_id, receiver_id, text, audio_data, audio_duration, created_at)
            VALUES ('seed-direct-message-5', 'seed-user-1', 'seed-user-3',
                    'That sounds great. Which dive site are you considering?', NULL, 0, 5)
            """
        )
        try execute(
            """
            INSERT OR IGNORE INTO direct_messages
            (id, sender_id, receiver_id, text, audio_data, audio_duration, created_at)
            VALUES ('seed-direct-message-6', 'seed-user-3', 'seed-user-1',
                    'Catalina Island. The conditions should be perfect on Saturday morning.', NULL, 0, 6)
            """
        )
        try execute(
            """
            INSERT OR IGNORE INTO chatboxes
            (id, name, access_key, participant_limit, avatar_data, created_by, created_at)
            VALUES ('1000785', 'LOOKING FOR ROCK CLIMBERS',
                    '123456', 44, NULL, 'seed-user-7', 2)
            """
        )
        let seededRoomMembers: [(String, String, Double)] = [
            ("1000784", "seed-user-1", 0),
            ("1000784", "seed-user-2", 1),
            ("1000784", "seed-user-4", 2),
            ("1000784", "seed-user-6", 3),
            ("1000784", "seed-user-8", 4),
            ("1000785", "seed-user-7", 0),
            ("1000785", "seed-user-1", 1),
            ("1000785", "seed-user-3", 2),
            ("1000785", "seed-user-5", 3)
        ]
        for member in seededRoomMembers {
            try execute(
                """
                INSERT OR IGNORE INTO chatbox_members
                (chatbox_id, user_id, joined_at) VALUES (?, ?, ?)
                """,
                values: [.text(member.0), .text(member.1), .double(member.2)]
            )
        }
        let seededRoomMessages: [(String, String, String, String, Double)] = [
            ("seed-chat-message-1", "1000784", "seed-user-2", "I checked the forecast. Saturday morning looks great.", 1),
            ("seed-chat-message-2", "1000784", "seed-user-1", "Perfect. Let us meet near the north parking lot at eight.", 2),
            ("seed-chat-message-3", "1000784", "seed-user-4", "I can bring an extra board if anyone needs one.", 3),
            ("seed-chat-message-4", "1000784", "seed-user-6", "Thanks! I will bring drinks for everyone.", 4),
            ("seed-chat-message-5", "1000785", "seed-user-7", "Who is available for a climbing session this Sunday?", 1),
            ("seed-chat-message-6", "1000785", "seed-user-3", "I am in. Which route are you considering?", 2),
            ("seed-chat-message-7", "1000785", "seed-user-5", "The west wall has several good intermediate routes.", 3),
            ("seed-chat-message-8", "1000785", "seed-user-1", "Sounds good. I can bring ropes and quickdraws.", 4)
        ]
        for message in seededRoomMessages {
            try execute(
                """
                INSERT OR IGNORE INTO chatbox_messages
                (id, chatbox_id, author_id, text, created_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                values: [
                    .text(message.0), .text(message.1), .text(message.2),
                    .text(message.3), .double(message.4)
                ]
            )
        }
    }

    private func seedIfNeeded() throws {
        if try metadataValue(for: Self.seedKey) == String(Self.starterDataVersion) {
            return
        }
        try transaction {
            let legacyPasswordColumn = try tableHasColumn(
                "password_hash",
                in: "users"
            )
            for (index, item) in Self.starterUsers.enumerated() {
                let userID = "seed-user-\(index + 1)"
                let legacyColumn = legacyPasswordColumn ? ", password_hash" : ""
                let legacyValue = legacyPasswordColumn ? ", ''" : ""
                try execute(
                    """
                    INSERT OR IGNORE INTO users (
                        id, email, username, password\(legacyColumn), gender, age, category,
                        certificate, avatar_source, avatar_asset_name, biography,
                        affinities, is_guest, created_at
                    ) VALUES (?, ?, ?, ?\(legacyValue), ?, ?, ?, ?, ?, ?, ?, '', 0, ?)
                    """,
                    values: [
                        .text(userID),
                        .text(
                            index == 0
                                ? "test@gmail.com"
                                : "\(item.username.lowercased())@gmail.com"
                        ),
                        .text(item.username), .text("123456"),
                        .text(item.gender), .integer(item.age),
                        .text(item.category), .text(item.certificate),
                        .text(item.avatarSource), .text(avatarAssets[index]),
                        .text(item.biography),
                        .double(Date().timeIntervalSince1970 + Double(index))
                    ]
                )
                try execute(
                    "INSERT OR IGNORE INTO wallet_accounts (user_id, balance) VALUES (?, 0)",
                    values: [.text(userID)]
                )
                try execute(
                    """
                    INSERT OR IGNORE INTO user_profiles
                    (user_id, birthday, location, avatar_data) VALUES (?, '', '', NULL)
                    """,
                    values: [.text(userID)]
                )
                try execute(
                    """
                    INSERT OR REPLACE INTO ai_messages
                    (id, user_id, text, is_from_user, created_at)
                    VALUES (?, ?, ?, 0, ?)
                    """,
                    values: [
                        .text("seed-ai-\(userID)-welcome"),
                        .text(userID),
                        .text(
                            "Hello, is there anything you would like to ask me about outdoor fitness or outdoor sports such as surfing, skydiving, rock climbing, etc.?"
                        ),
                        .double(1)
                    ]
                )
                for (itineraryIndex, line) in item.itinerary
                    .split(separator: "\n").map(String.init).enumerated() {
                    let parts = line.split(separator: ":", maxSplits: 1)
                        .map(String.init)
                    try execute(
                        """
                        INSERT OR IGNORE INTO itineraries
                        (id, user_id, date_text, details, sort_order)
                        VALUES (?, ?, ?, ?, ?)
                        """,
                        values: [
                            .text("\(userID)-itinerary-\(itineraryIndex + 1)"),
                            .text(userID), .text(parts.first ?? ""),
                            .text(parts.count > 1
                                ? parts[1].trimmingCharacters(in: .whitespaces)
                                : line),
                            .integer(itineraryIndex)
                        ]
                    )
                }

                let postID = "seed-post-\(index + 1)"
                try execute(
                    """
                    INSERT OR IGNORE INTO posts
                    (id, author_id, text, image_source, image_asset_name, created_at, like_count)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    values: [
                        .text(postID), .text(userID),
                        .text(item.postText.trimmingCharacters(in: .whitespacesAndNewlines)),
                        .text(item.postImageSource), .text(postAssets[index]),
                        .double(Date().timeIntervalSince1970 - Double(index * 86_400)),
                        .integer(18 + index * 7)
                    ]
                )
                for tagName in Self.parseTags(item.postTags) {
                    let tagID = "tag-\(Self.slug(tagName))"
                    try execute(
                        "INSERT OR IGNORE INTO tags (id, name) VALUES (?, ?)",
                        values: [.text(tagID), .text(tagName)]
                    )
                    try execute(
                        "INSERT OR IGNORE INTO post_tags (post_id, tag_id) VALUES (?, ?)",
                        values: [.text(postID), .text(tagID)]
                    )
                }
                let comment = item.comment.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                if !comment.isEmpty {
                    let commentAuthorID = "seed-user-\(max(1, index))"
                    try execute(
                        """
                        INSERT OR IGNORE INTO comments
                        (id, post_id, author_id, text, created_at)
                        VALUES (?, ?, ?, ?, ?)
                        """,
                        values: [
                            .text("seed-comment-\(index + 1)"),
                            .text(postID), .text(commentAuthorID), .text(comment),
                            .double(Date().timeIntervalSince1970)
                        ]
                    )
                    try execute(
                        """
                        UPDATE comments SET author_id = ?
                        WHERE id = ? AND author_id IS NULL
                        """,
                        values: [
                            .text(commentAuthorID),
                            .text("seed-comment-\(index + 1)")
                        ]
                    )
                }
                if !item.videoFileName.isEmpty {
                    let videoID = "seed-video-\(index + 1)"
                    try execute(
                        """
                        INSERT OR IGNORE INTO videos
                        (id, author_id, feed_section, media_file_name,
                         fallback_image_asset_name,
                         caption, created_at, like_count)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        values: [
                            .text(videoID), .text(userID),
                            .text(Self.videoFeedSection(
                                for: item.videoFileName
                            ).rawValue),
                            .text(item.videoFileName), .text(postAssets[index]),
                            .text(item.videoCaption),
                            .double(Date().timeIntervalSince1970 - Double(index * 43_200)),
                            .integer(13 + index * 3)
                        ]
                    )
                    for tagName in Self.parseTags(item.videoTags) {
                        let tagID = "tag-\(Self.slug(tagName))"
                        try execute(
                            "INSERT OR IGNORE INTO tags (id, name) VALUES (?, ?)",
                            values: [.text(tagID), .text(tagName)]
                        )
                        try execute(
                            "INSERT OR IGNORE INTO video_tags (video_id, tag_id) VALUES (?, ?)",
                            values: [.text(videoID), .text(tagID)]
                        )
                    }
                    let videoComment = item.videoComment.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    if !videoComment.isEmpty {
                        let commentAuthorID = "seed-user-\(max(1, index))"
                        try execute(
                            """
                            INSERT OR IGNORE INTO video_comments
                            (id, video_id, author_id, text, created_at)
                            VALUES (?, ?, ?, ?, ?)
                            """,
                            values: [
                                .text("seed-video-comment-\(index + 1)"),
                                .text(videoID), .text(commentAuthorID),
                                .text(videoComment),
                                .double(Date().timeIntervalSince1970)
                            ]
                        )
                        try execute(
                            """
                            UPDATE video_comments SET author_id = ?
                            WHERE id = ? AND author_id IS NULL
                            """,
                            values: [
                                .text(commentAuthorID),
                                .text("seed-video-comment-\(index + 1)")
                            ]
                        )
                    }
                }
            }
            try execute(
                """
                UPDATE videos SET feed_section = 'nearby'
                WHERE id IN ('seed-video-1', 'seed-video-5')
                """
            )
            try execute(
                """
                UPDATE videos SET feed_section = 'recommend'
                WHERE id IN ('seed-video-7', 'seed-video-8')
                """
            )
            try seedSharedReferenceData()
            for memberIndex in 1...8 {
                let roomID = memberIndex.isMultiple(of: 2) ? "1000784" : "1000785"
                try execute(
                    """
                    INSERT OR IGNORE INTO chatbox_members
                    (chatbox_id, user_id, joined_at) VALUES (?, ?, ?)
                    """,
                    values: [
                        .text(roomID),
                        .text("seed-user-\(memberIndex)"),
                        .double(Double(memberIndex))
                    ]
                )
            }
            try execute(
                "INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)",
                values: [
                    .text(Self.seedKey),
                    .text(String(Self.starterDataVersion))
                ]
            )
        }
    }

    private func refresh() throws {
        users = try fetchUsers()
        posts = try fetchPosts()
        videos = try fetchVideos()
    }

    private func fetchUsers() throws -> [RunQUserRecord] {
        let statement = try prepare(
            """
            SELECT id, email, username, gender, age, category, certificate,
                   avatar_asset_name, biography, is_guest
            FROM users WHERE is_deleted = 0 ORDER BY created_at
            """
        )
        defer { sqlite3_finalize(statement) }
        var result: [RunQUserRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(userRecord(from: statement))
        }
        return result
    }

    private func fetchPosts() throws -> [RunQPostRecord] {
        let statement = try prepare(
            """
            SELECT p.id, u.id, u.username, u.avatar_asset_name, p.text,
                   COALESCE(GROUP_CONCAT(t.name, '|'), ''), p.image_asset_name,
                   (SELECT image_data FROM post_media pm WHERE pm.post_id = p.id LIMIT 1),
                   p.created_at, p.like_count,
                   (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id),
                   p.post_type
            FROM posts p
            JOIN users u ON u.id = p.author_id
            LEFT JOIN post_tags pt ON pt.post_id = p.id
            LEFT JOIN tags t ON t.id = pt.tag_id
            GROUP BY p.id
            ORDER BY p.created_at DESC
            """
        )
        defer { sqlite3_finalize(statement) }
        var result: [RunQPostRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let postID = text(statement, 0)
            let mediaItems = try fetchPostMedia(for: postID)
            result.append(
                RunQPostRecord(
                    id: postID,
                    authorID: text(statement, 1),
                    authorName: text(statement, 2),
                    authorAvatarAssetName: text(statement, 3),
                    text: text(statement, 4),
                    tags: text(statement, 5).split(separator: "|").map(String.init),
                    imageAssetName: text(statement, 6),
                    imageDataItems: mediaItems.isEmpty
                        ? data(statement, 7).map { [$0] } ?? []
                        : mediaItems,
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 8)),
                    likeCount: Int(sqlite3_column_int(statement, 9)),
                    commentCount: Int(sqlite3_column_int(statement, 10)),
                    type: RunQPostType(rawValue: text(statement, 11)) ?? .news
                )
            )
        }
        return result
    }

    private func fetchPostMedia(for postID: String) throws -> [Data] {
        let statement = try prepare(
            """
            SELECT image_data FROM post_media
            WHERE post_id = ? ORDER BY sort_order
            """,
            values: [.text(postID)]
        )
        defer { sqlite3_finalize(statement) }
        var result: [Data] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = data(statement, 0) { result.append(item) }
        }
        return result
    }

    private func fetchVideos() throws -> [RunQVideoRecord] {
        let statement = try prepare(
            """
            SELECT v.id, u.id, u.username, u.avatar_asset_name,
                   v.feed_section, v.media_file_name,
                   v.fallback_image_asset_name, v.caption,
                   COALESCE(GROUP_CONCAT(t.name, '|'), ''), v.created_at,
                   v.like_count,
                   (SELECT COUNT(*) FROM video_comments c WHERE c.video_id = v.id)
            FROM videos v
            JOIN users u ON u.id = v.author_id
            LEFT JOIN video_tags vt ON vt.video_id = v.id
            LEFT JOIN tags t ON t.id = vt.tag_id
            GROUP BY v.id
            ORDER BY v.created_at DESC
            """
        )
        defer { sqlite3_finalize(statement) }
        var result: [RunQVideoRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(
                RunQVideoRecord(
                    id: text(statement, 0),
                    authorID: text(statement, 1),
                    authorName: text(statement, 2),
                    authorAvatarAssetName: text(statement, 3),
                    feedSection: RunQVideoFeedSection(
                        rawValue: text(statement, 4)
                    ) ?? .recommend,
                    mediaFileName: text(statement, 5),
                    fallbackImageAssetName: text(statement, 6),
                    caption: text(statement, 7),
                    tags: text(statement, 8).split(separator: "|").map(String.init),
                    createdAt: Date(
                        timeIntervalSince1970: sqlite3_column_double(statement, 9)
                    ),
                    likeCount: Int(sqlite3_column_int(statement, 10)),
                    commentCount: Int(sqlite3_column_int(statement, 11))
                )
            )
        }
        return result
    }

    private func requiredUser(id: String) throws -> RunQUserRecord {
        let statement = try prepare(
            """
            SELECT id, email, username, gender, age, category, certificate,
                   avatar_asset_name, biography, is_guest
            FROM users WHERE id = ? AND is_deleted = 0 LIMIT 1
            """,
            values: [.text(id)]
        )
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw RunQDataError.accountNotFound
        }
        return userRecord(from: statement)
    }

    private func user(email: String) throws -> RunQUserRecord? {
        let statement = try prepare(
            """
            SELECT id, email, username, gender, age, category, certificate,
                   avatar_asset_name, biography, is_guest
            FROM users WHERE email = ? LIMIT 1
            """,
            values: [.text(email)]
        )
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW
            ? userRecord(from: statement)
            : nil
    }

    private func userRecord(from statement: OpaquePointer) -> RunQUserRecord {
        RunQUserRecord(
            id: text(statement, 0), email: text(statement, 1),
            username: text(statement, 2), gender: text(statement, 3),
            age: Int(sqlite3_column_int(statement, 4)),
            category: text(statement, 5), certificate: text(statement, 6),
            avatarAssetName: text(statement, 7), biography: text(statement, 8),
            isGuest: sqlite3_column_int(statement, 9) == 1
        )
    }

    private func relationUsers(
        sql: String,
        userID: String
    ) -> [RunQUserRecord] {
        guard let statement = try? prepare(sql, values: [.text(userID)]) else {
            return []
        }
        defer { sqlite3_finalize(statement) }
        var result: [RunQUserRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(userRecord(from: statement))
        }
        return result
    }

    private func visiblePosts(
        _ records: [RunQPostRecord],
        userID: String?
    ) -> [RunQPostRecord] {
        records.filter {
            isUserVisible($0.authorID, to: userID)
        }.map { post in
            guard userID != nil else { return post }
            return RunQPostRecord(
                id: post.id,
                authorID: post.authorID,
                authorName: post.authorName,
                authorAvatarAssetName: post.authorAvatarAssetName,
                text: post.text,
                tags: post.tags,
                imageAssetName: post.imageAssetName,
                imageDataItems: post.imageDataItems,
                createdAt: post.createdAt,
                likeCount: post.likeCount,
                commentCount: comments(
                    for: post.id,
                    visibleTo: userID
                ).count,
                type: post.type
            )
        }
    }

    private func relationExists(
        sourceUserID: String,
        targetUserID: String,
        kind: String
    ) throws -> Bool {
        let statement = try prepare(
            """
            SELECT 1 FROM user_relations
            WHERE source_user_id = ? AND target_user_id = ? AND kind = ? LIMIT 1
            """,
            values: [.text(sourceUserID), .text(targetUserID), .text(kind)]
        )
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func metadataValue(for key: String) throws -> String? {
        let statement = try prepare(
            "SELECT value FROM metadata WHERE key = ? LIMIT 1",
            values: [.text(key)]
        )
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW ? text(statement, 0) : nil
    }

    private func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try body()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func execute(
        _ sql: String,
        values: [SQLiteValue] = []
    ) throws {
        let statement = try prepare(sql, values: values)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw RunQDataError.persistenceFailure
        }
    }

    private func executeScript(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(
            database,
            sql,
            nil,
            nil,
            &errorMessage
        )
        if let errorMessage {
            sqlite3_free(errorMessage)
        }
        guard result == SQLITE_OK else {
            throw RunQDataError.persistenceFailure
        }
    }

    private func prepare(
        _ sql: String,
        values: [SQLiteValue] = []
    ) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw RunQDataError.persistenceFailure
        }
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case .text(let text):
                sqlite3_bind_text(
                    statement,
                    index,
                    text,
                    -1,
                    Self.transient
                )
            case .integer(let integer):
                sqlite3_bind_int64(statement, index, Int64(integer))
            case .double(let double):
                sqlite3_bind_double(statement, index, double)
            case .blob(let data):
                _ = data.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(
                        statement,
                        index,
                        bytes.baseAddress,
                        Int32(data.count),
                        Self.transient
                    )
                }
            case .null:
                sqlite3_bind_null(statement, index)
            }
        }
        return statement
    }

    private func text(_ statement: OpaquePointer, _ index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: value)
    }

    private func nullableText(
        _ statement: OpaquePointer,
        _ index: Int32
    ) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return text(statement, index)
    }

    private func data(_ statement: OpaquePointer, _ index: Int32) -> Data? {
        guard let bytes = sqlite3_column_blob(statement, index) else {
            return nil
        }
        let count = Int(sqlite3_column_bytes(statement, index))
        return Data(bytes: bytes, count: count)
    }

    private static func openDatabase(at path: String) -> OpaquePointer? {
        var database: OpaquePointer?
        guard sqlite3_open(path, &database) == SQLITE_OK else {
            if let database { sqlite3_close(database) }
            return nil
        }
        return database
    }

    private func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func parseTags(_ value: String) -> [String] {
        value.split(separator: "#")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { "#\($0)" }
    }

    private static func slug(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    private enum SQLiteValue {
        case text(String)
        case integer(Int)
        case double(Double)
        case blob(Data)
        case null
    }

    private let avatarAssets = [
        "001", "002", "003", "004",
        "9acaf34580e4f3d59a7617e47608c042",
        "da2e56813ff3e991ea73d8c4cf5db3dc",
        "792ca100a6210ffea138b1bc634f276b",
        "415fbe35da611f8c33f2e1dfce403129"
    ]

    private let postAssets = [
        "1", "2", "3", "4", "5", "6", "7", "8"
    ]

    private struct StarterUser {
        let username: String
        let gender: String
        let age: Int
        let category: String
        let certificate: String
        let avatarSource: String
        let biography: String
        let itinerary: String
        let postText: String
        let postTags: String
        let postImageSource: String
        let comment: String
        let videoFileName: String
        let videoCaption: String
        let videoTags: String
        let videoComment: String
    }

    private static let starterDataVersion = 7

    private static func videoFeedSection(
        for fileName: String
    ) -> RunQVideoFeedSection {
        ["8es.mp4", "sp8.mp4"].contains(fileName) ? .nearby : .recommend
    }

    private static let starterUsers: [StarterUser] = [
        StarterUser(
            username: "Ethan",
            gender: "male",
            age: 26,
            category: "GYM BUDDY",
            certificate: "NASM Certified Personal Trainer",
            avatarSource: "001.jpg",
            biography: "CSCS & NASM certified trainer based in LA. Obsessed with functional strength training and bodyweight movement. Looking for early-bird workout partners at Equinox!",
            itinerary: "Jun, 12: Morning Heavy Deadlift session @ Gold's Gym\nJun, 08: HIIT & Calisthenics group training in Venice",
            postText: "Heavy deadlift day. Focus on form, not just weight. Hit a new PR today and feeling great.",
            postTags: "#MorningWorkout #GymLife #FitnessMotivation",
            postImageSource: "1.jpg",
            comment: "",
            videoFileName: "8es.mp4",
            videoCaption: "Own the gym, own the day.",
            videoTags: "#Workout #Gym",
            videoComment: ""
        ),
        StarterUser(
            username: "Bennett",
            gender: "female",
            age: 24,
            category: "GYM BUDDY",
            certificate: "ACE Certified Fitness Nutrition Specialist",
            avatarSource: "002.jpg",
            biography: "Powerlifting beginner & pilates lover. UC Berkeley alumna. Always down for a post-workout protein smoothie or a heavy leg day hype partner!",
            itinerary: "Jun, 15: Glute & Core hypertrophy session @ MetroFlex\nJun, 10: Mat Pilates session @ Downtown Studio",
            postText: "Leg day complete! 🦵 Tried out a new hypertrophy routine today. That burn is so real, but consistency is key. 🔥",
            postTags: "#LegDay #Hypertrophy #FitnessLifestyle #PostWorkout",
            postImageSource: "2.jpg",
            comment: "Great work",
            videoFileName: "",
            videoCaption: "",
            videoTags: "",
            videoComment: ""
        ),
        StarterUser(
            username: "Miller",
            gender: "male",
            age: 29,
            category: "DIVING BUDDY",
            certificate: "PADI Master Scuba Diver & AIDA 3 Freediver",
            avatarSource: "003.jpg",
            biography: "Marine biology enthusiast. PADI Master Scuba Diver with 300+ logged dives. Exploring underwater caves and reef conservation.",
            itinerary: "Jun, 20: Deep sea wreck exploration @ Catalina Island\nJun, 14: Freediving static apnea practice @ Local Aquatic Center",
            postText: "Freediving static apnea practice today. Managed to hit a personal best breath-hold time! Testing limits safely and staying calm underwater. 🌊",
            postTags: "#Freediving #StaticApnea #UnderwaterLife #OceanMind",
            postImageSource: "3.jpg",
            comment: "So impressive",
            videoFileName: "",
            videoCaption: "",
            videoTags: "",
            videoComment: ""
        ),
        StarterUser(
            username: "Vance",
            gender: "female",
            age: 25,
            category: "DIVING BUDDY",
            certificate: "SSI Advanced Open Water Diver",
            avatarSource: "004.jpg",
            biography: "Underwater photographer & sun chaser. Love night diving and kelp forest navigation. Let’s buddy up for the next coastal dive trip!",
            itinerary: "Jun, 18: Kelp forest macro photography dive @ Shaw's Cove\nJun, 11: Sunset scuba dive & gear testing",
            postText: "Testing out some new macro lens settings underwater. Found this vibrant little creature! The ocean never ceases to amaze me.",
            postTags: "#UnderwaterPhotography #MacroDive #OceanLover #ScubaLife",
            postImageSource: "4.jpg",
            comment: "Amazing",
            videoFileName: "",
            videoCaption: "",
            videoTags: "",
            videoComment: ""
        ),
        StarterUser(
            username: "Carter",
            gender: "male",
            age: 23,
            category: "SURF BUDDY",
            certificate: "ISA Certified Surf Instructor Level 1",
            avatarSource: "9acaf34580e4f3d59a7617e47608c042.jpg",
            biography: "Born and raised in San Diego. Chasing swells from dawn till dusk. Shortboard enthusiast, always down for an early morning surf line-up.",
            itinerary: "Jun, 22: Dawn patrol surf session @ Black's Beach\nJun, 16: Weekend road trip & point break session @ Malibu",
            postText: "Dawn patrol session. The swell was consistent and clean. Nothing beats watching the sunrise right from the line-up. Perfect start to the day.",
            postTags: "#DawnPatrol #SunriseSurfing #SurferLife #OceanVibes",
            postImageSource: "5.jpg",
            comment: "Perfect way to start the day!",
            videoFileName: "sp8.mp4",
            videoCaption: "Pure composure inside the heavy tube.",
            videoTags: "#Surfing",
            videoComment: "Living on the edge, literally!"
        ),
        StarterUser(
            username: "Hayes",
            gender: "female",
            age: 27,
            category: "SURF BUDDY",
            certificate: "Surf Lifesaving First Aid Certified",
            avatarSource: "da2e56813ff3e991ea73d8c4cf5db3dc.jpg",
            biography: "Longboard cross-stepper and ocean lover. Surfing easy sunset waves and catching good vibes. Coffee and surf chat afterwards?",
            itinerary: "Jun, 19: Sunset noseriding session @ San Onofre\nJun, 13: Board shaping workshop & casual paddle out",
            postText: "Perfect sunset noseriding session. The waves were gentle and the vibes were unmatched. Pure bliss on the water today. ✨",
            postTags: "#Noseriding #SunsetVibes #LongboardSurf #OceanLovers",
            postImageSource: "6.jpg",
            comment: "",
            videoFileName: "",
            videoCaption: "",
            videoTags: "",
            videoComment: ""
        ),
        StarterUser(
            username: "Noah",
            gender: "male",
            age: 28,
            category: "CLIMBING BUDDY",
            certificate: "AMGA Single Pitch Instructor",
            avatarSource: "792ca100a6210ffea138b1bc634f276b.jpg",
            biography: "Bouldering (V7+) and lead climbing junkie. Outdoor crag trips on weekends, indoor bouldering on weeknights. Belay partner needed!",
            itinerary: "Jun, 21: Outdoor lead climbing @ Stoney Point Park\nJun, 17: Moonboard project session @ Sender One Gym",
            postText: "Finally sent my lead climbing project! The top-out was a bit sketchy but the view at the top made it all worth it. 🧗‍♂️🔥",
            postTags: "#LeadClimbing #SendIt #ClimbingLife #Bouldering",
            postImageSource: "7.jpg",
            comment: "",
            videoFileName: "a459a4b6cf105b0eb4ed6cb6ccbcccc5.mp4",
            videoCaption: "Climbing mountains is a lot like life, it's tough but the view from the top is worth it",
            videoTags: "#RockClimbingLife",
            videoComment: "Every climb is a lesson."
        ),
        StarterUser(
            username: "Ross",
            gender: "female",
            age: 26,
            category: "SKYDIVING BUDDY",
            certificate: "USPA B-License Skydiver",
            avatarSource: "415fbe35da611f8c33f2e1dfce403129.jpg",
            biography: "150+ jumps and counting! USPA B-license holder. Freeflying learner and sunset tracking lover. Blue skies and high vibes!",
            itinerary: "Jun, 25: 4-Way formation skydive @ Skydive Perris\nJun, 05: Canopy control clinic & hop-and-pop jump",
            postText: "Successful 4-Way formation jump today! Nothing compares to the feeling of freefall and clear skies. Pure adrenaline.",
            postTags: "#FormationSkydiving #BlueSkies #AdrenalineJunkie #Skydiver",
            postImageSource: "8.jpg",
            comment: "",
            videoFileName: "3e962f1e7f240097965103d81d089d29.mp4",
            videoCaption: "Unleash Your Inner Explorer: Adventure Awaits in the Sky!",
            videoTags: "#Skydiving",
            videoComment: "The view from up there must be unreal. Absolutely bucket list worthy!"
        )
    ]
}

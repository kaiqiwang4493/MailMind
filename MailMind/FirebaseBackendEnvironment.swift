import Foundation

enum FirebaseBackendEnvironment {
    static func configureEmulatorsIfNeeded() {
        // Debug builds intentionally use the deployed Firebase backend by default.
    }
}

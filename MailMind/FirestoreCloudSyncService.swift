import FirebaseFunctions
import Foundation

protocol CloudSyncServicing {
    func loadMailRecords(ownerID: String) async throws -> [MailRecordDTO]
    func loadTodoItems(ownerID: String) async throws -> [TodoItemDTO]
    func saveMailRecord(_ record: MailRecordDTO, ownerID: String) async throws
    func saveTodoItem(_ todo: TodoItemDTO, ownerID: String) async throws
    func deleteTodoItem(remoteID: String, ownerID: String) async throws
}

struct FirestoreCloudSyncService: CloudSyncServicing {
    func loadMailRecords(ownerID: String) async throws -> [MailRecordDTO] {
        let result = try await functions.httpsCallable("listMailRecords").call()
        return try decodeDTOArray(result.data, makeDTO: MailRecordDTO.init(id:data:))
    }

    func loadTodoItems(ownerID: String) async throws -> [TodoItemDTO] {
        let result = try await functions.httpsCallable("listTodoItems").call()
        return try decodeDTOArray(result.data, makeDTO: TodoItemDTO.init(id:data:))
    }

    func saveMailRecord(_ record: MailRecordDTO, ownerID: String) async throws {
        _ = try await functions.httpsCallable("saveMailRecord").call(record.callableData)
    }

    func saveTodoItem(_ todo: TodoItemDTO, ownerID: String) async throws {
        _ = try await functions.httpsCallable("saveTodoItem").call(todo.callableData)
    }

    func deleteTodoItem(remoteID: String, ownerID: String) async throws {
        _ = try await functions.httpsCallable("deleteTodoItem").call(["id": remoteID])
    }

    private var functions: Functions {
        Functions.functions(region: "us-central1")
    }

    private func decodeDTOArray<T>(_ data: Any, makeDTO: (String, [String: Any]) -> T?) throws -> [T] {
        guard let rawItems = data as? [[String: Any]] else {
            throw BackendCloudSyncError.invalidResponse
        }

        return rawItems.compactMap { item in
            guard let id = item["id"] as? String else {
                return nil
            }
            return makeDTO(id, item)
        }
    }
}

enum BackendCloudSyncError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        "后台同步返回了无法识别的数据。"
    }
}

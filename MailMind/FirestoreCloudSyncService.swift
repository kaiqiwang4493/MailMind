import FirebaseFirestore
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
        let snapshot = try await userCollection(ownerID: ownerID, name: "mailRecords").getDocuments()
        return snapshot.documents.compactMap { document in
            MailRecordDTO(id: document.documentID, data: document.data())
        }
    }

    func loadTodoItems(ownerID: String) async throws -> [TodoItemDTO] {
        let snapshot = try await userCollection(ownerID: ownerID, name: "todoItems").getDocuments()
        return snapshot.documents.compactMap { document in
            TodoItemDTO(id: document.documentID, data: document.data())
        }
    }

    func saveMailRecord(_ record: MailRecordDTO, ownerID: String) async throws {
        try await userCollection(ownerID: ownerID, name: "mailRecords")
            .document(record.id)
            .setData(record.firestoreData, merge: true)
    }

    func saveTodoItem(_ todo: TodoItemDTO, ownerID: String) async throws {
        try await userCollection(ownerID: ownerID, name: "todoItems")
            .document(todo.id)
            .setData(todo.firestoreData, merge: true)
    }

    func deleteTodoItem(remoteID: String, ownerID: String) async throws {
        try await userCollection(ownerID: ownerID, name: "todoItems")
            .document(remoteID)
            .delete()
    }

    private func userCollection(ownerID: String, name: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(ownerID).collection(name)
    }
}

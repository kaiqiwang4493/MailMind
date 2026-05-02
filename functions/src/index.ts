import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {requireUID} from "./auth";
import {
  mailRecordFromFirestore,
  mailRecordToFirestore,
  MailRecordDTO,
  requireID,
  todoItemFromFirestore,
  todoItemToFirestore,
  TodoItemDTO,
} from "./dtos";
import {analyzeMailWithGemini} from "./gemini";
import {productionFieldEncryptionKey, productionGeminiAPIKey} from "./secrets";

initializeApp();

const db = getFirestore();
const publicCallableOptions = {
  region: "us-central1",
  invoker: "public" as const,
};

function userCollection(uid: string, name: "mailRecords" | "todoItems") {
  return db.collection("users").doc(uid).collection(name);
}

function mapError(error: unknown): HttpsError {
  if (error instanceof HttpsError) {
    return error;
  }

  const message = error instanceof Error ? error.message : "Unexpected backend error";
  return new HttpsError("invalid-argument", message);
}

export const analyzeMail = onCall({...publicCallableOptions, secrets: [productionGeminiAPIKey]}, async (request) => {
  try {
    requireUID(request.auth);

    const text = request.data?.text;
    const createdAt = request.data?.createdAt;
    if (typeof text !== "string" || typeof createdAt !== "string") {
      throw new HttpsError("invalid-argument", "text and createdAt are required strings.");
    }

    return await analyzeMailWithGemini(text, createdAt);
  } catch (error) {
    throw mapError(error);
  }
});

export const listMailRecords = onCall({...publicCallableOptions, secrets: [productionFieldEncryptionKey]}, async (request) => {
  try {
    const uid = requireUID(request.auth);
    const snapshot = await userCollection(uid, "mailRecords").get();
    return snapshot.docs.map((doc) => mailRecordFromFirestore(doc.id, doc.data()));
  } catch (error) {
    throw mapError(error);
  }
});

export const saveMailRecord = onCall({...publicCallableOptions, secrets: [productionFieldEncryptionKey]}, async (request) => {
  try {
    const uid = requireUID(request.auth);
    const record = request.data as MailRecordDTO;
    const id = requireID(record?.id);
    await userCollection(uid, "mailRecords").doc(id).set(mailRecordToFirestore(record, uid), {merge: true});
    return {id};
  } catch (error) {
    throw mapError(error);
  }
});

export const listTodoItems = onCall({...publicCallableOptions, secrets: [productionFieldEncryptionKey]}, async (request) => {
  try {
    const uid = requireUID(request.auth);
    const snapshot = await userCollection(uid, "todoItems").get();
    return snapshot.docs.map((doc) => todoItemFromFirestore(doc.id, doc.data()));
  } catch (error) {
    throw mapError(error);
  }
});

export const saveTodoItem = onCall({...publicCallableOptions, secrets: [productionFieldEncryptionKey]}, async (request) => {
  try {
    const uid = requireUID(request.auth);
    const todo = request.data as TodoItemDTO;
    const id = requireID(todo?.id);
    await userCollection(uid, "todoItems").doc(id).set(todoItemToFirestore(todo, uid), {merge: true});
    return {id};
  } catch (error) {
    throw mapError(error);
  }
});

export const deleteTodoItem = onCall(publicCallableOptions, async (request) => {
  try {
    const uid = requireUID(request.auth);
    const id = requireID(request.data?.id);
    await userCollection(uid, "todoItems").doc(id).delete();
    return {success: true};
  } catch (error) {
    throw mapError(error);
  }
});

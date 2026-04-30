import {describe, expect, it} from "vitest";
import {randomBytes} from "node:crypto";
import {Timestamp} from "firebase-admin/firestore";
import {decryptString} from "./crypto";
import {mailRecordFromFirestore, mailRecordToFirestore, todoItemFromFirestore, todoItemToFirestore} from "./dtos";

describe("encrypted Firestore DTOs", () => {
  it("encrypts sensitive mail record fields and restores API shape", () => {
    process.env.MAILMIND_FIELD_ENCRYPTION_KEY = randomBytes(32).toString("base64");
    const record = {
      id: "mail-1",
      ownerID: "client-supplied-user",
      sourceTypeRawValue: "sample",
      sourceNames: ["Sample"],
      pageCount: 1,
      summary: "同步摘要。",
      categoryRawValue: "government",
      suggestedTodoTitles: ["缴费"],
      suggestedTodoDeadlines: ["2026-04-30T12:00:00.000Z"],
      createdAt: "2026-04-30T12:00:00.000Z",
      updatedAt: "2026-04-30T12:00:00.000Z",
    };

    const firestore = mailRecordToFirestore(record, "auth-user");
    expect(firestore.ownerID).toBe("auth-user");
    expect(JSON.stringify(firestore)).not.toContain("同步摘要。");
    expect(JSON.stringify(firestore)).not.toContain("缴费");
    expect(decryptString(firestore.summary)).toBe("同步摘要。");

    const restored = mailRecordFromFirestore("mail-1", firestore);
    expect(restored.summary).toBe("同步摘要。");
    expect(restored.suggestedTodoTitles).toEqual(["缴费"]);
    expect(restored.createdAt).toBe("2026-04-30T12:00:00.000Z");
  });

  it("encrypts sensitive todo fields and restores API shape", () => {
    process.env.MAILMIND_FIELD_ENCRYPTION_KEY = randomBytes(32).toString("base64");
    const todo = {
      id: "todo-1",
      ownerID: "client-supplied-user",
      mailRecordID: "mail-1",
      title: "Pay fee",
      deadline: "2026-05-01T12:00:00.000Z",
      mailSummary: "同步摘要。",
      isCompleted: false,
      createdAt: "2026-04-30T12:00:00.000Z",
      updatedAt: "2026-04-30T12:00:00.000Z",
    };

    const firestore = todoItemToFirestore(todo, "auth-user");
    expect(firestore.ownerID).toBe("auth-user");
    expect(JSON.stringify(firestore)).not.toContain("Pay fee");
    expect(JSON.stringify(firestore)).not.toContain("同步摘要。");
    expect(firestore.deadline).toBeInstanceOf(Timestamp);

    const restored = todoItemFromFirestore("todo-1", firestore);
    expect(restored.title).toBe("Pay fee");
    expect(restored.mailSummary).toBe("同步摘要。");
    expect(restored.deadline).toBe("2026-05-01T12:00:00.000Z");
  });
});

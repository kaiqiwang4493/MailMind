import {Timestamp} from "firebase-admin/firestore";
import {
  decryptString,
  decryptStringArray,
  encryptString,
  encryptStringArray,
  EncryptedField,
} from "./crypto";

export type TodoDraftDTO = {
  title: string;
  deadline: string | null;
};

export type MailRecordDTO = {
  id: string;
  ownerID?: string;
  sourceTypeRawValue: string;
  sourceNames: string[];
  pageCount: number;
  summary: string;
  categoryRawValue: string;
  suggestedTodoTitles: string[];
  suggestedTodoDeadlines: string[];
  createdAt: string;
  updatedAt: string;
};

export type TodoItemDTO = {
  id: string;
  ownerID?: string;
  mailRecordID?: string;
  title: string;
  deadline: string;
  mailSummary: string;
  isCompleted: boolean;
  createdAt: string;
  completedAt?: string;
  updatedAt: string;
};

type EncryptedMailRecordDocument = Omit<
  MailRecordDTO,
  "id" | "summary" | "suggestedTodoTitles" | "suggestedTodoDeadlines" | "createdAt" | "updatedAt"
> & {
  ownerID: string;
  summary: EncryptedField;
  suggestedTodoTitles: EncryptedField[];
  suggestedTodoDeadlines: Timestamp[];
  createdAt: Timestamp;
  updatedAt: Timestamp;
};

type EncryptedTodoItemDocument = Omit<
  TodoItemDTO,
  "id" | "title" | "deadline" | "mailSummary" | "createdAt" | "completedAt" | "updatedAt"
> & {
  ownerID: string;
  title: EncryptedField;
  deadline: Timestamp;
  mailSummary: EncryptedField;
  createdAt: Timestamp;
  completedAt?: Timestamp;
  updatedAt: Timestamp;
};

export function mailRecordToFirestore(record: MailRecordDTO, uid: string): EncryptedMailRecordDocument {
  return {
    ownerID: uid,
    sourceTypeRawValue: requireString(record.sourceTypeRawValue, "sourceTypeRawValue"),
    sourceNames: requireStringArray(record.sourceNames, "sourceNames"),
    pageCount: requireNumber(record.pageCount, "pageCount"),
    summary: encryptString(requireString(record.summary, "summary")),
    categoryRawValue: requireString(record.categoryRawValue, "categoryRawValue"),
    suggestedTodoTitles: encryptStringArray(requireStringArray(record.suggestedTodoTitles, "suggestedTodoTitles")),
    suggestedTodoDeadlines: requireStringArray(record.suggestedTodoDeadlines, "suggestedTodoDeadlines").map(toTimestamp),
    createdAt: toTimestamp(record.createdAt),
    updatedAt: toTimestamp(record.updatedAt),
  };
}

export function mailRecordFromFirestore(id: string, data: FirebaseFirestore.DocumentData): MailRecordDTO {
  return {
    id,
    ownerID: requireString(data.ownerID, "ownerID"),
    sourceTypeRawValue: requireString(data.sourceTypeRawValue, "sourceTypeRawValue"),
    sourceNames: requireStringArray(data.sourceNames, "sourceNames"),
    pageCount: requireNumber(data.pageCount, "pageCount"),
    summary: decryptString(data.summary as EncryptedField),
    categoryRawValue: requireString(data.categoryRawValue, "categoryRawValue"),
    suggestedTodoTitles: decryptStringArray(data.suggestedTodoTitles as EncryptedField[]),
    suggestedTodoDeadlines: requireTimestampArray(data.suggestedTodoDeadlines, "suggestedTodoDeadlines").map(fromTimestamp),
    createdAt: fromTimestamp(requireTimestamp(data.createdAt, "createdAt")),
    updatedAt: fromTimestamp(requireTimestamp(data.updatedAt, "updatedAt")),
  };
}

export function todoItemToFirestore(todo: TodoItemDTO, uid: string): EncryptedTodoItemDocument {
  const data: EncryptedTodoItemDocument = {
    ownerID: uid,
    mailRecordID: optionalString(todo.mailRecordID, "mailRecordID"),
    title: encryptString(requireString(todo.title, "title")),
    deadline: toTimestamp(todo.deadline),
    mailSummary: encryptString(requireString(todo.mailSummary, "mailSummary")),
    isCompleted: requireBoolean(todo.isCompleted, "isCompleted"),
    createdAt: toTimestamp(todo.createdAt),
    updatedAt: toTimestamp(todo.updatedAt),
  };

  if (todo.completedAt) {
    data.completedAt = toTimestamp(todo.completedAt);
  }

  return data;
}

export function todoItemFromFirestore(id: string, data: FirebaseFirestore.DocumentData): TodoItemDTO {
  const todo: TodoItemDTO = {
    id,
    ownerID: requireString(data.ownerID, "ownerID"),
    mailRecordID: optionalString(data.mailRecordID, "mailRecordID"),
    title: decryptString(data.title as EncryptedField),
    deadline: fromTimestamp(requireTimestamp(data.deadline, "deadline")),
    mailSummary: decryptString(data.mailSummary as EncryptedField),
    isCompleted: requireBoolean(data.isCompleted, "isCompleted"),
    createdAt: fromTimestamp(requireTimestamp(data.createdAt, "createdAt")),
    updatedAt: fromTimestamp(requireTimestamp(data.updatedAt, "updatedAt")),
  };

  if (data.completedAt) {
    todo.completedAt = fromTimestamp(requireTimestamp(data.completedAt, "completedAt"));
  }

  return todo;
}

export function requireID(value: unknown): string {
  const id = requireString(value, "id").trim();
  if (!id) {
    throw new Error("id is required");
  }
  return id;
}

function toTimestamp(value: string): Timestamp {
  const date = new Date(requireString(value, "date"));
  if (Number.isNaN(date.getTime())) {
    throw new Error(`Invalid date: ${value}`);
  }
  return Timestamp.fromDate(date);
}

function fromTimestamp(value: Timestamp): string {
  return value.toDate().toISOString();
}

function requireString(value: unknown, name: string): string {
  if (typeof value !== "string") {
    throw new Error(`${name} must be a string`);
  }
  return value;
}

function optionalString(value: unknown, name: string): string | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  return requireString(value, name);
}

function requireStringArray(value: unknown, name: string): string[] {
  if (!Array.isArray(value) || value.some((item) => typeof item !== "string")) {
    throw new Error(`${name} must be a string array`);
  }
  return value;
}

function requireNumber(value: unknown, name: string): number {
  if (typeof value !== "number") {
    throw new Error(`${name} must be a number`);
  }
  return value;
}

function requireBoolean(value: unknown, name: string): boolean {
  if (typeof value !== "boolean") {
    throw new Error(`${name} must be a boolean`);
  }
  return value;
}

function requireTimestamp(value: unknown, name: string): Timestamp {
  if (!(value instanceof Timestamp)) {
    throw new Error(`${name} must be a Firestore Timestamp`);
  }
  return value;
}

function requireTimestampArray(value: unknown, name: string): Timestamp[] {
  if (!Array.isArray(value) || value.some((item) => !(item instanceof Timestamp))) {
    throw new Error(`${name} must be a Firestore Timestamp array`);
  }
  return value;
}

import {createCipheriv, createDecipheriv, randomBytes} from "node:crypto";
import {productionFieldEncryptionKey, secretValue} from "./secrets";

export type EncryptedField = {
  v: 1;
  alg: "AES-256-GCM";
  iv: string;
  ct: string;
  tag: string;
};

const algorithm = "aes-256-gcm";

export function getEncryptionKey(): Buffer {
  const value = secretValue(productionFieldEncryptionKey, "MAILMIND_FIELD_ENCRYPTION_KEY");
  if (!value) {
    throw new Error("MAILMIND_FIELD_ENCRYPTION_KEY is not configured");
  }

  const key = Buffer.from(value, "base64");
  if (key.length !== 32) {
    throw new Error("MAILMIND_FIELD_ENCRYPTION_KEY must be a base64-encoded 32-byte key");
  }
  return key;
}

export function encryptString(plaintext: string, key = getEncryptionKey()): EncryptedField {
  const iv = randomBytes(12);
  const cipher = createCipheriv(algorithm, key, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);

  return {
    v: 1,
    alg: "AES-256-GCM",
    iv: iv.toString("base64"),
    ct: ciphertext.toString("base64"),
    tag: cipher.getAuthTag().toString("base64"),
  };
}

export function decryptString(field: EncryptedField, key = getEncryptionKey()): string {
  if (field.v !== 1 || field.alg !== "AES-256-GCM") {
    throw new Error("Unsupported encrypted field format");
  }

  const decipher = createDecipheriv(algorithm, key, Buffer.from(field.iv, "base64"));
  decipher.setAuthTag(Buffer.from(field.tag, "base64"));
  const plaintext = Buffer.concat([
    decipher.update(Buffer.from(field.ct, "base64")),
    decipher.final(),
  ]);

  return plaintext.toString("utf8");
}

export function encryptStringArray(values: string[], key = getEncryptionKey()): EncryptedField[] {
  return values.map((value) => encryptString(value, key));
}

export function decryptStringArray(fields: EncryptedField[], key = getEncryptionKey()): string[] {
  return fields.map((field) => decryptString(field, key));
}

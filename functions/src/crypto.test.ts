import {describe, expect, it} from "vitest";
import {randomBytes} from "node:crypto";
import {decryptString, encryptString} from "./crypto";

describe("field encryption", () => {
  it("round trips encrypted strings without plaintext ciphertext", () => {
    const key = randomBytes(32);
    const plaintext = "敏感摘要 Pay the renewal bill";

    const encrypted = encryptString(plaintext, key);
    const decrypted = decryptString(encrypted, key);

    expect(decrypted).toBe(plaintext);
    expect(encrypted.ct).not.toContain("Pay the renewal bill");
    expect(encrypted.alg).toBe("AES-256-GCM");
  });
});

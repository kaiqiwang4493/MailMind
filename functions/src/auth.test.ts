import {describe, expect, it} from "vitest";
import {HttpsError} from "firebase-functions/v2/https";
import {requireUID} from "./auth";

describe("callable auth", () => {
  it("rejects missing auth context", () => {
    expect(() => requireUID(undefined)).toThrow(HttpsError);
  });

  it("returns the authenticated uid", () => {
    expect(requireUID({uid: "user-1"})).toBe("user-1");
  });
});

import {describe, expect, it, vi} from "vitest";
import {analyzeMailWithGemini, parseGeminiAnalysisText} from "./gemini";

describe("Gemini mail analysis", () => {
  it("parses structured Gemini responses into the existing DTO shape", async () => {
    const generateContent = vi.fn(async () => ({
      text: JSON.stringify({
        summary: "这是一封账单提醒。",
        category: "bill",
        todoItems: [{title: "缴纳账单", deadline: "2026-05-31"}],
      }),
    }));

    const result = await analyzeMailWithGemini(
      "Please pay by May 31, 2026.",
      "2026-05-02T12:00:00.000Z",
      {models: {generateContent}}
    );

    expect(result).toEqual({
      summary: "这是一封账单提醒。",
      category: "bill",
      todoItems: [{title: "缴纳账单", deadline: "2026-05-31"}],
    });
    expect(generateContent).toHaveBeenCalledWith(expect.objectContaining({
      model: "gemini-3-flash-preview",
      config: expect.objectContaining({
        responseMimeType: "application/json",
        responseJsonSchema: expect.any(Object),
      }),
    }));
  });

  it("rejects unsupported categories", () => {
    expect(() => parseGeminiAnalysisText(JSON.stringify({
      summary: "摘要",
      category: "unsupported",
      todoItems: [],
    }))).toThrow("Unsupported category");
  });

  it("rejects missing response text", () => {
    expect(() => parseGeminiAnalysisText(undefined)).toThrow("Gemini response did not contain text");
  });

  it("rejects invalid JSON response text", () => {
    expect(() => parseGeminiAnalysisText("not-json")).toThrow("Gemini response was not valid JSON");
  });
});

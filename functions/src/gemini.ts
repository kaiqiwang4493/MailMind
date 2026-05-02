import {GoogleGenAI} from "@google/genai";
import {TodoDraftDTO} from "./dtos";
import {productionGeminiAPIKey, secretValue} from "./secrets";

type GeminiGenerateContentClient = {
  models: {
    generateContent: (params: GeminiGenerateContentParams) => Promise<{text?: string}>;
  };
};

type GeminiGenerateContentParams = {
  model: string;
  contents: string;
  config: {
    systemInstruction: string;
    responseMimeType: "application/json";
    responseJsonSchema: unknown;
  };
};

type GeminiMailAnalysisPayload = {
  summary: string;
  category: string;
  todoItems: TodoDraftDTO[];
};

const categories = [
  "bill",
  "government",
  "banking",
  "insurance",
  "healthcare",
  "tax",
  "legal",
  "school",
  "advertisement",
  "personal",
  "other",
];

const responseJsonSchema = {
  type: "object",
  additionalProperties: false,
  required: ["summary", "category", "todoItems"],
  properties: {
    summary: {
      type: "string",
      description: "A short Simplified Chinese summary of the English mail.",
    },
    category: {
      type: "string",
      enum: categories,
    },
    todoItems: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["title", "deadline"],
        properties: {
          title: {
            type: "string",
            description: "A concise Simplified Chinese action item.",
          },
          deadline: {
            type: ["string", "null"],
            description: "ISO date YYYY-MM-DD if present, otherwise null.",
          },
        },
      },
    },
  },
};

export async function analyzeMailWithGemini(
  text: string,
  createdAt: string,
  client?: GeminiGenerateContentClient
): Promise<GeminiMailAnalysisPayload> {
  const ai = client ?? new GoogleGenAI({apiKey: requireGeminiAPIKey()});
  const model = process.env.GEMINI_MODEL || "gemini-3-flash-preview";
  const currentDate = currentDateFrom(createdAt);

  const response = await ai.models.generateContent({
    model,
    contents: `Analyze this OCR text from one mail item:\n\n${text}`,
    config: {
      systemInstruction: [
        "You analyze English physical mail for Chinese-speaking older adults.",
        "Return concise Simplified Chinese.",
        "Extract only action items that the recipient actually needs to do.",
        "If the mail does not require action, return an empty todoItems array.",
        "Deadlines must use ISO date format YYYY-MM-DD. If the mail has no clear deadline, use null.",
        `Categories must be one of: ${categories.join(", ")}.`,
        `Current date: ${currentDate}.`,
      ].join("\n"),
      responseMimeType: "application/json",
      responseJsonSchema,
    },
  });

  return parseGeminiAnalysisText(response.text);
}

export function parseGeminiAnalysisText(outputText: string | undefined): GeminiMailAnalysisPayload {
  if (!outputText) {
    throw new Error("Gemini response did not contain text");
  }

  let payload: unknown;
  try {
    payload = JSON.parse(outputText);
  } catch {
    throw new Error("Gemini response was not valid JSON");
  }

  return validatePayload(payload);
}

function requireGeminiAPIKey(): string {
  const apiKey = secretValue(productionGeminiAPIKey, "GEMINI_API_KEY");
  if (!apiKey) {
    throw new Error("GEMINI_API_KEY is not configured");
  }
  return apiKey;
}

function currentDateFrom(createdAt: string): string {
  const createdDate = new Date(createdAt);
  return Number.isNaN(createdDate.getTime()) ?
    new Date().toISOString().slice(0, 10) :
    createdDate.toISOString().slice(0, 10);
}

function validatePayload(payload: unknown): GeminiMailAnalysisPayload {
  if (!isRecord(payload)) {
    throw new Error("Gemini response must be an object");
  }

  const summary = payload.summary;
  const category = payload.category;
  const todoItems = payload.todoItems;

  if (typeof summary !== "string") {
    throw new Error("Gemini response summary must be a string");
  }
  if (typeof category !== "string" || !categories.includes(category)) {
    throw new Error(`Unsupported category: ${String(category)}`);
  }
  if (!Array.isArray(todoItems)) {
    throw new Error("Gemini response todoItems must be an array");
  }

  return {
    summary,
    category,
    todoItems: todoItems.map(validateTodoDraft),
  };
}

function validateTodoDraft(value: unknown): TodoDraftDTO {
  if (!isRecord(value)) {
    throw new Error("Gemini todo item must be an object");
  }

  const title = value.title;
  const deadline = value.deadline;
  if (typeof title !== "string") {
    throw new Error("Gemini todo item title must be a string");
  }
  if (deadline !== null && typeof deadline !== "string") {
    throw new Error("Gemini todo item deadline must be a string or null");
  }

  return {title, deadline};
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

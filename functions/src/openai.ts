import {TodoDraftDTO} from "./dtos";
import {productionOpenAIAPIKey, secretValue} from "./secrets";

type OpenAIResponsesResponse = {
  output?: Array<{
    content?: Array<{
      type?: string;
      text?: string;
    }>;
  }>;
};

type OpenAIMailAnalysisPayload = {
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

export async function analyzeMailWithOpenAI(text: string, createdAt: string): Promise<OpenAIMailAnalysisPayload> {
  const apiKey = secretValue(productionOpenAIAPIKey, "OPENAI_API_KEY");
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY is not configured");
  }

  const createdDate = new Date(createdAt);
  const currentDate = Number.isNaN(createdDate.getTime()) ?
    new Date().toISOString().slice(0, 10) :
    createdDate.toISOString().slice(0, 10);

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: process.env.OPENAI_MODEL || "gpt-4.1-mini",
      input: [
        {
          role: "system",
          content: [
            {
              type: "input_text",
              text: [
                "You analyze English physical mail for Chinese-speaking older adults.",
                "Return concise Simplified Chinese. Extract only action items that the recipient actually needs to do.",
                "If the mail does not require action, return an empty todoItems array.",
                "Deadlines must use ISO date format YYYY-MM-DD. If the mail has no clear deadline, use null.",
                `Categories must be one of: ${categories.join(", ")}.`,
                `Current date: ${currentDate}.`,
              ].join("\n"),
            },
          ],
        },
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: `Analyze this OCR text from one mail item:\n\n${text}`,
            },
          ],
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "mail_analysis",
          strict: true,
          schema: {
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
                      anyOf: [
                        {type: "string"},
                        {type: "null"},
                      ],
                      description: "ISO date YYYY-MM-DD if present, otherwise null.",
                    },
                  },
                },
              },
            },
          },
        },
      },
    }),
  });

  const responseText = await response.text();
  if (!response.ok) {
    throw new Error(responseText || `OpenAI HTTP ${response.status}`);
  }

  const responseObject = JSON.parse(responseText) as OpenAIResponsesResponse;
  const outputText = responseObject.output
    ?.flatMap((item) => item.content ?? [])
    .find((content) => content.type === "output_text")
    ?.text;

  if (!outputText) {
    throw new Error("OpenAI response did not contain output_text");
  }

  const payload = JSON.parse(outputText) as OpenAIMailAnalysisPayload;
  if (!categories.includes(payload.category)) {
    throw new Error(`Unsupported category: ${payload.category}`);
  }

  return payload;
}

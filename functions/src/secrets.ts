import {defineSecret} from "firebase-functions/params";

export const productionGeminiAPIKey = defineSecret("MAILMIND_GEMINI_API_KEY");
export const productionFieldEncryptionKey = defineSecret("MAILMIND_ENCRYPTION_KEY");

export function secretValue(secret: {value: () => string}, localEnvName: string): string | undefined {
  return process.env[localEnvName] || secret.value();
}

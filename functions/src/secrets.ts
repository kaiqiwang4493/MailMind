import {defineSecret} from "firebase-functions/params";

export const productionOpenAIAPIKey = defineSecret("MAILMIND_OPENAI_API_KEY");
export const productionFieldEncryptionKey = defineSecret("MAILMIND_ENCRYPTION_KEY");

export function secretValue(secret: {value: () => string}, localEnvName: string): string | undefined {
  return process.env[localEnvName] || secret.value();
}

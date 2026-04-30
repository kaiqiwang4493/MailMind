import {HttpsError} from "firebase-functions/v2/https";

export function requireUID(auth: {uid?: string} | undefined): string {
  const uid = auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Please sign in before using MailMind cloud features.");
  }
  return uid;
}

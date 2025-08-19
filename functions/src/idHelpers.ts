import {createHash} from "crypto";

/**
 * Return a UTC date string in YYYY-MM-DD format.
 * @param {Date} date the input date
 * @return {string} ISO date string in UTC (YYYY-MM-DD)
 */
export function dateStringUTC(date: Date): string {
  const d = new Date(date);
  const yyyy = d.getUTCFullYear();
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

/**
 * Deterministically compute a task id from templateTaskId, checklistId and dateStr.
 * Uses SHA-1 and returns the first 16 hex characters.
 * @param {string} templateTaskId template task id
 * @param {string} checklistId checklist id
 * @param {string} dateStr date string
 * @return {string} deterministic short hex id
 */
export function deterministicTaskId(templateTaskId: string, checklistId: string, dateStr: string): string {
  const digest = createHash("sha1").update(`${templateTaskId}|${checklistId}|${dateStr}`).digest("hex");
  return digest.substring(0, 16);
}

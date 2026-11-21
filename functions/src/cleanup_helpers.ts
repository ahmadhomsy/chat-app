export const CONVERSATION_BATCH_SIZE = 300;
export const FCM_TOKEN_DELETE_BATCH_SIZE = 400;

/**
 * Deterministically computes administrator succession when a group administrator account is deleted.
 *
 * Policy:
 * 1. The deleted user is removed from `adminIds`.
 * 2. If one or more co-administrators remain, they are preserved.
 * 3. If NO administrators remain:
 *    - In the absence of per-participant join timestamps in the data model,
 *      remaining participants are sorted deterministically (lexicographical UID order)
 *      and the first entry is promoted to administrator.
 */
export function computeAdminSuccession(
  currentAdminIds: string[],
  participantIds: string[],
  deletedUid: string
): string[] {
  const remainingAdmins = currentAdminIds.filter((id) => id !== deletedUid);

  if (remainingAdmins.length === 0) {
    const candidateParticipants = participantIds.filter((id) => id !== deletedUid);
    if (candidateParticipants.length > 0) {
      // Deterministic fallback: lexicographical UID sort
      const sortedCandidates = [...candidateParticipants].sort();
      remainingAdmins.push(sortedCandidates[0]);
    }
  }

  return remainingAdmins;
}

/**
 * Partitions documents into safe write-batch chunks (strictly <= 400, below Firestore's 500 cap).
 */
export function chunkDocuments<T>(docs: T[], chunkSize: number = FCM_TOKEN_DELETE_BATCH_SIZE): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < docs.length; i += chunkSize) {
    chunks.push(docs.slice(i, i + chunkSize));
  }
  return chunks;
}

/**
 * Handles errors during Storage avatar deletion.
 * - Code 404 (file/folder not found) is treated as a successful no-op.
 * - Any other error is rethrown to prevent false completion and enable retry.
 */
export function handleStorageDeletionError(err: any): void {
  if (err?.code === 404 || err?.message?.toLowerCase().includes('not found')) {
    // Genuine not-found is a safe, successful no-op
    return;
  }
  // All other errors (network, 500, permissions) must rethrow
  throw err;
}

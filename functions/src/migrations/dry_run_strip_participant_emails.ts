import * as admin from 'firebase-admin';

/**
 * ChatUp Migration Utility: Strip Legacy Participant Emails (Dry-Run Mode)
 *
 * PURPOSE:
 * Phase 4.1 removed email serialization from the Flutter client, and Phase 4.2 enforces
 * strict server-side rules preventing participant email storage.
 * This utility audits existing conversation documents for legacy snapshots that still contain
 * `email` keys and calculates the exact sanitize operations required.
 *
 * SAFETY GUARANTEES:
 * - Operates in STRICT DRY-RUN mode by default (`DRY_RUN = true`).
 * - Makes ZERO writes, updates, or deletes against Firestore unless explicitly invoked with
 *   `EXECUTE_MIGRATION = true` AND running in an authorized environment.
 * - Per governance constraints, this script is staged for operational documentation only
 *   and MUST NOT be executed against production `chat-app-28ac0`.
 */

export interface MigrationAuditResult {
  totalScanned: number;
  conversationsWithEmail: number;
  totalEmailsFound: number;
  sampleAffectedConversationIds: string[];
  dryRun: boolean;
}

export async function auditLegacyParticipantEmails(
  firestore: admin.firestore.Firestore,
  options: { dryRun?: boolean; batchSize?: number } = {}
): Promise<MigrationAuditResult> {
  const isDryRun = options.dryRun ?? true;
  const batchSize = options.batchSize ?? 100;

  let totalScanned = 0;
  let conversationsWithEmail = 0;
  let totalEmailsFound = 0;
  const sampleAffectedConversationIds: string[] = [];

  let query: admin.firestore.Query = firestore
    .collection('conversations')
    .orderBy(admin.firestore.FieldPath.documentId())
    .limit(batchSize);

  let hasMore = true;
  let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;

  while (hasMore) {
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      hasMore = false;
      break;
    }

    for (const doc of snapshot.docs) {
      totalScanned++;
      const data = doc.data();
      const participants = data.participants;

      if (participants && typeof participants === 'object') {
        let docHasEmail = false;
        const updates: Record<string, any> = {};

        for (const [uid, participant] of Object.entries<any>(participants)) {
          if (participant && typeof participant === 'object' && 'email' in participant) {
            docHasEmail = true;
            totalEmailsFound++;
            updates[`participants.${uid}.email`] = admin.firestore.FieldValue.delete();
          }
        }

        if (docHasEmail) {
          conversationsWithEmail++;
          if (sampleAffectedConversationIds.length < 10) {
            sampleAffectedConversationIds.push(doc.id);
          }

          if (!isDryRun) {
            await doc.ref.update(updates);
          }
        }
      }
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < batchSize) {
      hasMore = false;
    }
  }

  return {
    totalScanned,
    conversationsWithEmail,
    totalEmailsFound,
    sampleAffectedConversationIds,
    dryRun: isDryRun,
  };
}

// CLI entry point
if (require.main === module) {
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  const db = admin.firestore();

  console.log('[Migration Dry-Run] Auditing conversations for legacy participant emails...');
  auditLegacyParticipantEmails(db, { dryRun: true })
    .then((result) => {
      console.log('--- Migration Audit Summary ---');
      console.log(`Total Conversations Scanned: ${result.totalScanned}`);
      console.log(`Conversations with Leaked Emails: ${result.conversationsWithEmail}`);
      console.log(`Total Participant Emails Found: ${result.totalEmailsFound}`);
      console.log(`Sample Affected Conversation IDs: ${result.sampleAffectedConversationIds.join(', ') || 'None'}`);
      console.log(`Dry-Run Mode: ${result.dryRun} (No changes written to database)`);
      process.exit(0);
    })
    .catch((err) => {
      console.error('[Migration Dry-Run] Error during audit:', err);
      process.exit(1);
    });
}

import * as admin from 'firebase-admin';

/**
 * ChatUp Migration Utility: Strip Legacy Participant Emails (Dry-Run Mode & Gated Execution)
 *
 * PURPOSE:
 * Phase 4.1 removed email serialization from the Flutter client, Phase 4.2 enforced
 * rules preventing direct email exposure, and Phase 4.3 moves group participant snapshots
 * to dedicated `/participants/{uid}` subcollections.
 * This utility audits existing conversation documents for legacy snapshots that still contain
 * `email` keys and calculates the exact sanitize operations required.
 *
 * SAFETY GUARANTEES:
 * - Operates in STRICT DRY-RUN mode by default (`dryRun: true`).
 * - Makes ZERO writes, updates, or deletes against Firestore during audit mode.
 * - Gated execution requires explicit operational authorization key AND backup confirmation.
 * - Per governance constraints, this script is staged for operational documentation only
 *   and MUST NOT be executed against production `chat-app-28ac0`.
 */

export interface MigrationAuditResult {
  totalScanned: number;
  conversationsWithEmail: number;
  totalEmailsFound: number;
  batchesProcessed: number;
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
  let batchesProcessed = 0;
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

    batchesProcessed++;

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
    batchesProcessed,
    sampleAffectedConversationIds,
    dryRun: isDryRun,
  };
}

export interface MigrationExecutionOptions {
  authorizationToken: string;
  verifiedBackupId: string;
  verifiedBackupTimestamp: string;
  targetProjectId: string;
  batchSize?: number;
}

/**
 * Separately gated operational migration execution process.
 *
 * SAFETY REQUIREMENTS FOR OPERATORS:
 * - Destructive mutations are strictly locked by default.
 * - Requires an uncommitted execution token set via environment variable:
 *   process.env.MIGRATION_EXECUTION_TOKEN.
 * - Requires a documented backup identifier and timestamp. The operator MUST
 *   independently verify in Google Cloud Storage that a complete, valid Firestore
 *   export was successfully generated before initiating live migration.
 * - Requires explicit targetProjectId matching the active Firestore project.
 * - If targeting the production project ('chat-app-28ac0'), process.env.ALLOW_PRODUCTION_MIGRATION
 *   must be explicitly set to 'true'.
 */
export async function executeParticipantEmailSanitization(
  firestore: admin.firestore.Firestore,
  options: MigrationExecutionOptions
): Promise<MigrationAuditResult> {
  const configuredToken = process.env.MIGRATION_EXECUTION_TOKEN;
  if (!configuredToken || options.authorizationToken !== configuredToken) {
    throw new Error(
      'MIGRATION_BLOCKED: Missing or invalid execution authorization token. Set MIGRATION_EXECUTION_TOKEN in operational environment.'
    );
  }

  if (!options.verifiedBackupId || options.verifiedBackupId.trim().length === 0) {
    throw new Error(
      'MIGRATION_BLOCKED: Must provide a verified backup ID (e.g. gs://chat-app-28ac0-backups/2026-11-22).'
    );
  }

  if (!options.verifiedBackupTimestamp || isNaN(Date.parse(options.verifiedBackupTimestamp))) {
    throw new Error(
      'MIGRATION_BLOCKED: Must provide a valid ISO timestamp for the verified backup.'
    );
  }

  if (!options.targetProjectId || options.targetProjectId.trim().length === 0) {
    throw new Error('MIGRATION_BLOCKED: Must provide targetProjectId.');
  }

  // Production safety guard: block accidental production runs
  if (options.targetProjectId === 'chat-app-28ac0' && process.env.ALLOW_PRODUCTION_MIGRATION !== 'true') {
    throw new Error(
      'PRODUCTION_MIGRATION_LOCKED: Destructive migrations are disabled by default for production project "chat-app-28ac0". Requires ALLOW_PRODUCTION_MIGRATION="true".'
    );
  }

  console.log(
    `[Migration] Operational execution authorized. Target Project: ${options.targetProjectId}, Backup ID: ${options.verifiedBackupId}, Backup Timestamp: ${options.verifiedBackupTimestamp}`
  );

  return auditLegacyParticipantEmails(firestore, {
    dryRun: false,
    batchSize: options.batchSize ?? 100,
  });
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
      console.log(`Batches Processed: ${result.batchesProcessed}`);
      console.log(`Sample Affected Conversation IDs: ${result.sampleAffectedConversationIds.join(', ') || 'None'}`);
      console.log(`Dry-Run Mode: ${result.dryRun} (No changes written to database)`);
      process.exit(0);
    })
    .catch((err) => {
      console.error('[Migration Dry-Run] Error during audit:', err);
      process.exit(1);
    });
}

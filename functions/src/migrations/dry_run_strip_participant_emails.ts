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
  verifiedBackupId?: string;
  backupId?: string;
  verifiedBackupTimestamp?: string;
  backupTimestamp?: string;
  targetProjectId: string;
  batchSize?: number;
  /**
   * Explicit operator attestation certifying that a complete, valid Firestore export was
   * independently verified out-of-band in Google Cloud Storage before executing live migration.
   */
  operatorBackupAttestation?: boolean;
}

export const MAX_BACKUP_AGE_MS = 24 * 60 * 60 * 1000; // 24 hours (86,400,000 ms)

/**
 * Strict ISO 8601 timestamp regex requiring full date (YYYY-MM-DD), 'T' separator,
 * time (HH:mm:ss), optional fractional seconds (.sss), and explicit timezone offset
 * ('Z' or '+HH:mm' / '-HH:mm'). Non-ISO formats parseable by Date.parse are rejected.
 */
export const ISO_8601_TIMESTAMP_REGEX =
  /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|[+-]\d{2}:\d{2})$/;

/**
 * Validates actual calendar semantics for a date/time representation to prevent
 * JavaScript Date normalization from accepting impossible calendar dates
 * (e.g. Feb 31, Apr 31, or Feb 29 in non-leap years).
 */
export function isValidCalendarDateTime(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
  second: number,
  tz: string
): boolean {
  if (year < 1970 || year > 9999) return false;
  if (month < 1 || month > 12) return false;

  // Determine actual days in selected month with accurate leap-year handling
  let maxDays = 31;
  if (month === 4 || month === 6 || month === 9 || month === 11) {
    maxDays = 30;
  } else if (month === 2) {
    const isLeapYear = (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
    maxDays = isLeapYear ? 29 : 28;
  }

  if (day < 1 || day > maxDays) return false;
  if (hour < 0 || hour > 23) return false;
  if (minute < 0 || minute > 59) return false;
  if (second < 0 || second > 59) return false;

  if (tz !== 'Z') {
    const offsetMatch = tz.match(/^([+-])(\d{2}):(\d{2})$/);
    if (!offsetMatch) return false;
    const tzHour = parseInt(offsetMatch[2], 10);
    const tzMin = parseInt(offsetMatch[3], 10);
    if (tzHour < 0 || tzHour > 23 || tzMin < 0 || tzMin > 59) return false;
  }

  return true;
}

/**
 * Validates that a backup timestamp is a strictly compliant ISO 8601 string with timezone,
 * possesses valid calendar semantics (no normalized impossible dates), is not in the future,
 * and falls within the required 24-hour freshness window.
 *
 * @param rawTimestamp ISO 8601 timestamp string with timezone (UTC or offset)
 * @param referenceTimeMs Reference timestamp (defaults to Date.now())
 */
export function validateBackupTimestampFreshness(
  rawTimestamp?: string,
  referenceTimeMs: number = Date.now()
): number {
  if (!rawTimestamp || typeof rawTimestamp !== 'string') {
    throw new Error(
      'MIGRATION_BLOCKED: Must provide a valid ISO 8601 timestamp with timezone information for the verified backup (e.g. 2026-11-22T08:00:00.000Z or 2026-11-22T10:00:00.000+02:00).'
    );
  }

  const match = rawTimestamp.match(ISO_8601_TIMESTAMP_REGEX);
  if (!match) {
    throw new Error(
      'MIGRATION_BLOCKED: Must provide a valid ISO 8601 timestamp with timezone information for the verified backup (e.g. 2026-11-22T08:00:00.000Z or 2026-11-22T10:00:00.000+02:00).'
    );
  }

  const year = parseInt(match[1], 10);
  const month = parseInt(match[2], 10);
  const day = parseInt(match[3], 10);
  const hour = parseInt(match[4], 10);
  const minute = parseInt(match[5], 10);
  const second = parseInt(match[6], 10);
  const tz = match[8];

  if (!isValidCalendarDateTime(year, month, day, hour, minute, second, tz)) {
    throw new Error(
      'MIGRATION_BLOCKED: Must provide a valid ISO 8601 timestamp with calendar-valid date and timezone information (e.g. 2026-11-22T08:00:00.000Z or 2026-11-22T10:00:00.000+02:00).'
    );
  }

  const parsedBackupTime = Date.parse(rawTimestamp);
  if (isNaN(parsedBackupTime)) {
    throw new Error(
      'MIGRATION_BLOCKED: Must provide a valid ISO 8601 timestamp with timezone information for the verified backup (e.g. 2026-11-22T08:00:00.000Z or 2026-11-22T10:00:00.000+02:00).'
    );
  }

  // Reject future timestamps
  if (parsedBackupTime > referenceTimeMs) {
    throw new Error(
      'MIGRATION_BLOCKED: Backup timestamp cannot be in the future.'
    );
  }

  // Reject timestamps older than 24 hours
  if (referenceTimeMs - parsedBackupTime > MAX_BACKUP_AGE_MS) {
    throw new Error(
      'MIGRATION_BLOCKED: Backup timestamp is older than 24 hours (stale backup). A fresh backup taken within the last 24 hours is required.'
    );
  }

  return parsedBackupTime;
}

/**
 * Resolves the active Firebase project ID strictly from trusted Admin SDK configuration
 * or trusted runtime environment variables. Caller overrides are explicitly prohibited.
 *
 * Inspects all applicable trusted sources independently:
 * 1. Admin App options attached to the supplied Firestore instance:
 *    - Uses app.options.projectId if present.
 *    - Fallback: If the Firestore instance has an app object with no options.projectId, looks up
 *      an initialized Admin App in admin.apps matching app.name exactly. Does NOT infer identity
 *      from unrelated named Admin Apps.
 *    - Fallback: If no app is attached to the Firestore instance, checks admin.apps[0] if present.
 * 2. process.env.GCLOUD_PROJECT, when configured.
 * 3. projectId parsed from process.env.FIREBASE_CONFIG, when configured (independent of GCLOUD_PROJECT).
 *    Configured but whitespace-only FIREBASE_CONFIG fails closed.
 *
 * Requirements:
 * - Compares all available, applicable trusted identity values.
 * - Fails closed with MIGRATION_BLOCKED if any sources conflict.
 * - Fails closed with MIGRATION_BLOCKED if configured FIREBASE_CONFIG is malformed, whitespace-only, or lacks usable projectId.
 * - Fails closed if no trusted project identity can be determined.
 * - Never infers identity from targetProjectId.
 */
export function resolveActiveProjectId(firestore: admin.firestore.Firestore): string {
  const detectedSources: { source: string; projectId: string }[] = [];

  // 1. Primary: initialized Admin App options attached to firestore instance or matching admin.apps fallback
  let appProject: string | undefined;
  const app = (firestore as any)?.app;
  if (app?.options?.projectId && typeof app.options.projectId === 'string' && app.options.projectId.trim().length > 0) {
    appProject = app.options.projectId.trim();
  } else if (app) {
    // Firestore exposes an app object but options.projectId is missing/empty.
    // Safely look up matching Admin App by exact name only.
    const appName = typeof app.name === 'string' && app.name.trim().length > 0 ? app.name.trim() : '[DEFAULT]';
    const matchingAdminApp = admin.apps && admin.apps.length > 0 ? admin.apps.find((a) => a && a.name === appName) : undefined;
    if (matchingAdminApp?.options?.projectId && typeof matchingAdminApp.options.projectId === 'string' && matchingAdminApp.options.projectId.trim().length > 0) {
      appProject = matchingAdminApp.options.projectId.trim();
    }
  } else if (!app && admin.apps && admin.apps.length > 0 && admin.app()?.options?.projectId) {
    appProject = admin.app()!.options.projectId!.trim();
  }
  if (appProject) {
    detectedSources.push({ source: 'Firebase Admin App', projectId: appProject });
  }

  // 2. Environment: GCLOUD_PROJECT
  if (process.env.GCLOUD_PROJECT && process.env.GCLOUD_PROJECT.trim().length > 0) {
    detectedSources.push({
      source: 'GCLOUD_PROJECT',
      projectId: process.env.GCLOUD_PROJECT.trim(),
    });
  }

  // 3. Environment: FIREBASE_CONFIG (evaluated independently even when GCLOUD_PROJECT is present)
  if (process.env.FIREBASE_CONFIG !== undefined) {
    const trimmedConfig = process.env.FIREBASE_CONFIG.trim();
    if (trimmedConfig.length === 0) {
      throw new Error(
        'MIGRATION_BLOCKED: Configured FIREBASE_CONFIG environment variable is empty or whitespace-only.'
      );
    }
    try {
      const cfg = JSON.parse(trimmedConfig);
      if (cfg && typeof cfg.projectId === 'string' && cfg.projectId.trim().length > 0) {
        detectedSources.push({
          source: 'FIREBASE_CONFIG',
          projectId: cfg.projectId.trim(),
        });
      } else {
        throw new Error('Configured FIREBASE_CONFIG missing or empty "projectId" attribute');
      }
    } catch (err: any) {
      throw new Error(
        `MIGRATION_BLOCKED: Malformed or unparseable FIREBASE_CONFIG environment variable: ${err.message}`
      );
    }
  }

  // Fail closed if no trusted identity sources are available
  if (detectedSources.length === 0) {
    throw new Error(
      'MIGRATION_BLOCKED: Unable to determine active Firebase project identity from trusted Admin SDK configuration or runtime environment.'
    );
  }

  // Conflict detection: all available sources must report the exact same project ID
  const firstProject = detectedSources[0].projectId;
  const hasConflict = detectedSources.some((s) => s.projectId !== firstProject);
  if (hasConflict) {
    const details = detectedSources
      .map((s) => `${s.source}="${s.projectId}"`)
      .join(', ');
    throw new Error(
      `MIGRATION_BLOCKED: Conflicting Firebase project identity sources detected. All configured identity sources must agree: ${details}.`
    );
  }

  return firstProject;
}

/**
 * Separately gated operational migration execution process.
 *
 * SAFETY REQUIREMENTS & OPERATIONAL ATTESTATION:
 * - Destructive mutations are strictly locked by default.
 * - Requires an uncommitted execution token set via environment variable:
 *   process.env.MIGRATION_EXECUTION_TOKEN.
 * - System clock is ALWAYS used to evaluate backup freshness; caller-controlled clock injection is prohibited.
 * - Requires documented backup identifier and ISO timestamp fresh within the previous 24 hours.
 * - Future backup timestamps (> now) and stale timestamps (> 24 hours old) are strictly rejected.
 * - Requires explicit operatorBackupAttestation: true certifying out-of-band GCS export verification.
 *   (The script validates metadata and timestamp freshness; physical existence verification in GCS
 *   is an operator attestation responsibility).
 * - Project identity is resolved strictly from trusted Admin SDK configuration/runtime metadata.
 *   Caller targetProjectId is compared against this independently verified active project.
 * - Accidental production runs cannot be bypassed by supplying a false staging target.
 * - Production execution on 'chat-app-28ac0' requires process.env.ALLOW_PRODUCTION_MIGRATION === 'true'.
 */
export async function executeParticipantEmailSanitization(
  firestore: admin.firestore.Firestore,
  options: MigrationExecutionOptions
): Promise<MigrationAuditResult> {
  // 1. Authorization token verification
  const configuredToken = process.env.MIGRATION_EXECUTION_TOKEN;
  if (!configuredToken || options.authorizationToken !== configuredToken) {
    throw new Error(
      'MIGRATION_BLOCKED: Missing or invalid execution authorization token. Set MIGRATION_EXECUTION_TOKEN in operational environment.'
    );
  }

  // 2. Backup ID verification (supports backupId or verifiedBackupId)
  const backupId = options.backupId || options.verifiedBackupId;
  if (!backupId || backupId.trim().length === 0) {
    throw new Error(
      'MIGRATION_BLOCKED: Must provide a backup ID (e.g. gs://chat-app-28ac0-backups/2026-11-22).'
    );
  }

  // 3. Backup timestamp verification & freshness bounds (always evaluates against system clock)
  const rawTimestamp = options.backupTimestamp || options.verifiedBackupTimestamp;
  validateBackupTimestampFreshness(rawTimestamp, Date.now());

  // 4. Explicit operator attestation check
  if (options.operatorBackupAttestation !== true) {
    throw new Error(
      'MIGRATION_BLOCKED: Operator must explicitly certify out-of-band backup verification via operatorBackupAttestation: true.'
    );
  }

  // 5. Target project ID check
  if (!options.targetProjectId || options.targetProjectId.trim().length === 0) {
    throw new Error('MIGRATION_BLOCKED: Must provide targetProjectId.');
  }

  // 6. Active Firebase project identity check (strictly from Admin App/runtime, prevents bypass)
  const activeProject = resolveActiveProjectId(firestore);

  if (options.targetProjectId !== activeProject) {
    throw new Error(
      `MIGRATION_BLOCKED: Target project ID "${options.targetProjectId}" does not match active Firebase project "${activeProject}".`
    );
  }

  // 7. Production safety guard: checks active project directly
  if (activeProject === 'chat-app-28ac0' && process.env.ALLOW_PRODUCTION_MIGRATION !== 'true') {
    throw new Error(
      'PRODUCTION_MIGRATION_LOCKED: Destructive migrations are disabled by default for production project "chat-app-28ac0". Requires ALLOW_PRODUCTION_MIGRATION="true".'
    );
  }

  console.log(
    `[Migration] Operational execution authorized. Target Project: ${options.targetProjectId}, Backup ID: ${backupId}, Backup Timestamp: ${rawTimestamp}`
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

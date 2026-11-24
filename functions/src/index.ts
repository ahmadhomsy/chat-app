import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK once for all cloud functions
if (!admin.apps.length) {
  admin.initializeApp();
}

export { onNewChatMessage } from './notifications';
export { onUserDeleted } from './cleanup';
export { onUserStatusChanged } from './presence';
export { searchUserByEmail } from './search';

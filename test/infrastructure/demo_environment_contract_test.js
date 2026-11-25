const assert = require('assert');
const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '../..');

describe('Local Demo Environment Isolation Contract Tests', () => {
  it('1. android/app/src/development/google-services.json strictly targets demo-chatup and package com.example.chat_app.dev', () => {
    const filePath = path.join(REPO_ROOT, 'android/app/src/development/google-services.json');
    assert.ok(fs.existsSync(filePath), 'android/app/src/development/google-services.json must exist');

    const json = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    assert.strictEqual(json.project_info?.project_id, 'demo-chatup');
    assert.strictEqual(json.project_info?.project_number, '100000000000');
    assert.strictEqual(json.project_info?.storage_bucket, 'demo-chatup.appspot.com');

    const clients = json.client || [];
    assert.ok(clients.length > 0, 'Must contain at least one client');
    const devClient = clients.find(c => c.client_info?.android_client_info?.package_name === 'com.example.chat_app.dev');
    assert.ok(devClient, 'Client with package com.example.chat_app.dev must exist');

    // Negative assertions: must never match production or staging IDs
    assert.notStrictEqual(json.project_info?.project_id, 'chat-app-28ac0');
    assert.notStrictEqual(json.project_info?.project_id, 'study-buddy-54266');
    assert.notStrictEqual(json.project_info?.project_number, '639830188590');
    assert.notStrictEqual(json.project_info?.project_number, '194789753908');
  });

  it('2. android/app/src/development/AndroidManifest.xml deactivates analytics, crashlytics, and performance reporting', () => {
    const manifestPath = path.join(REPO_ROOT, 'android/app/src/development/AndroidManifest.xml');
    assert.ok(fs.existsSync(manifestPath), 'android/app/src/development/AndroidManifest.xml must exist');

    const content = fs.readFileSync(manifestPath, 'utf8');
    assert.ok(content.includes('android:name="firebase_analytics_collection_enabled"'), 'Must disable analytics');
    assert.ok(content.includes('android:name="firebase_crashlytics_collection_enabled"'), 'Must disable crashlytics');
    assert.ok(content.includes('android:name="firebase_performance_collection_enabled"'), 'Must disable performance');
  });

  it('3. .firebaserc contains development and demo project aliases mapping to demo-chatup', () => {
    const firebasercPath = path.join(REPO_ROOT, '.firebaserc');
    assert.ok(fs.existsSync(firebasercPath), '.firebaserc must exist');

    const json = JSON.parse(fs.readFileSync(firebasercPath, 'utf8'));
    assert.strictEqual(json.projects?.development, 'demo-chatup');
    assert.strictEqual(json.projects?.demo, 'demo-chatup');
    assert.strictEqual(json.projects?.production, 'chat-app-28ac0');
    assert.strictEqual(json.projects?.staging, 'study-buddy-54266');
  });

  it('4. firebase.json contains full emulator configuration on expected ports', () => {
    const firebaseJsonPath = path.join(REPO_ROOT, 'firebase.json');
    assert.ok(fs.existsSync(firebaseJsonPath), 'firebase.json must exist');

    const json = JSON.parse(fs.readFileSync(firebaseJsonPath, 'utf8'));
    const emu = json.emulators || {};
    assert.strictEqual(emu.auth?.port, 9099);
    assert.strictEqual(emu.functions?.port, 5001);
    assert.strictEqual(emu.firestore?.port, 8080);
    assert.strictEqual(emu.database?.port, 9000);
    assert.strictEqual(emu.storage?.port, 9199);
    assert.strictEqual(emu.ui?.port, 4000);
    assert.strictEqual(emu.singleProjectMode, true);
  });

  it('5. android/app/build.gradle.kts contains development credentials guard', () => {
    const gradlePath = path.join(REPO_ROOT, 'android/app/build.gradle.kts');
    assert.ok(fs.existsSync(gradlePath), 'android/app/build.gradle.kts must exist');

    const content = fs.readFileSync(gradlePath, 'utf8');
    assert.ok(content.includes('Missing development credentials'), 'Must include development credentials check');
    assert.ok(content.includes('src/development/google-services.json'), 'Must check src/development/google-services.json existence');
  });
});

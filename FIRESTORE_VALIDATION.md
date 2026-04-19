# Firestore Configuration Validation Checklist

Use this checklist to verify that Firestore is properly configured before deploying to production.

## Pre-Deployment Checklist

### 1. Configuration Files ✅
- [x] `firestore.indexes.json` - Composite indexes defined
- [x] `firestore.rules` - Security rules implemented
- [x] `firebase.json` - References Firestore files

### 2. Index Configuration ✅
- [x] Index 1: `chats` collection
  - Field 1: `participants` (array-contains)
  - Field 2: `lastMessageTime` (Descending)
  - Usage: `streamConversations()` - Get user's chats

- [x] Index 2: `chats` collection
  - Field 1: `participants` (array-contains)
  - Field 2: `chatType` (Ascending)
  - Usage: `streamPendingRequests()` - Filter pending requests

- [x] Index 3: `messages` subcollection
  - Field 1: `timestamp` (Ascending)
  - Usage: `streamMessages()` - Display chat history in order

### 3. Security Rules Validation ✅

#### Authentication
- [x] All operations require `isAuthenticated()` 
- [x] Helper function wraps `request.auth != null`

#### Chat Permissions
- [x] Read: Only participants in `participants` array
- [x] Write: Only participants can create
- [x] Update: User must be participant
- [x] Delete: Disabled from client

#### Message Permissions
- [x] Read: Only chat participants
- [x] Create: Only message sender (senderId == request.auth.uid)
- [x] Update: Only status field changeable (sent → read)
- [x] Delete: Disabled completely

#### Data Validation
- [x] Chat metadata immutable after creation
- [x] Message text and timestamp required
- [x] Status must be "sent" or "read"
- [x] Participants array cannot be modified

## Deployment Checklist

### Before Deploying

- [ ] **Firebase Project Setup**
  - [ ] Firebase project created in Google Cloud Console
  - [ ] Firestore database initialized (production mode recommended)
  - [ ] Firebase CLI installed: `npm install -g firebase-tools`
  - [ ] Logged in: `firebase login`

- [ ] **Local Testing**
  - [ ] `flutter pub get` - Dependencies installed
  - [ ] app builds without errors
  - [ ] Chat feature tested locally with Firebase Emulator

### Deployment Steps

```bash
# Step 1: Validate rule syntax
firebase firestore:validate-rules --path=firestore.rules

# Step 2: Deploy indexes
firebase deploy --only firestore:indexes

# Step 3: Deploy security rules (Test Mode first)
firebase deploy --only firestore:rules

# Step 4: Monitor deployment
firebase logs
```

### Post-Deployment Verification

- [ ] **Verify Indexes Created**
  - Go to Firebase Console → Firestore → Indexes
  - Check that all 3 indexes show "Enabled" status
  - Note: May take 5-15 minutes for index to build

- [ ] **Verify Rules Deployed**
  - Go to Firebase Console → Firestore → Rules
  - Confirm security rules are visible and active

- [ ] **Test Queries**
  ```dart
  // Test 1: Get user's chats (uses Index 1)
  Query q1 = firestore
    .collection('chats')
    .where('participants', arrayContains: userId)
    .orderBy('lastMessageTime', descending: true);
  
  // Test 2: Get pending requests (uses Index 2)
  Query q2 = firestore
    .collection('chats')
    .where('participants', arrayContains: userId)
    .where('chatType', isEqualTo: 'request');
  
  // Test 3: Get messages (uses Index 3)
  Query q3 = firestore
    .collection('chats')
    .doc(chatId)
    .collection('messages')
    .orderBy('timestamp', descending: false);
  ```

- [ ] **Test Security Rules**
  - [ ] Authenticated user can read own chats
  - [ ] Authenticated user can create messages
  - [ ] Unauthenticated user cannot read/write
  - [ ] User cannot read other user's private chats
  - [ ] User cannot modify message content (only status)

## Monitoring Checklist

### Daily Monitoring

- [ ] Check Firestore Usage metrics
  - Firebase Console → Firestore → Usage
  - Monitor read/write counts and costs
  - Should be < 1000 reads/day and < 500 writes/day for 10 users

- [ ] Check Error Logs
  - Firebase Console → Logs
  - Look for permission denied errors
  - Investigate any unexpected errors

### Weekly Monitoring

- [ ] Review Index Statistics
  - Which indexes are being used most?
  - Check index latency metrics
  - Disable unused indexes

- [ ] Backup Status
  - Firebase Console → Firestore → Backups
  - Verify auto-backups are working
  - Check last backup timestamp

### Monthly Monitoring

- [ ] Cost Analysis
  - Review usage trends
  - Optimize queries if needed
  - Check for spike in operations

- [ ] Security Audit
  - Review rule violations log
  - Check for unauthorized access attempts
  - Adjust rules if needed

## Troubleshooting

### Problem: Query Fails with "Missing Index" Error

**Solution:**
```bash
# Firestore will suggest the missing index
# Either:
# 1. Click link in error to create via Console
# 2. Or update firestore.indexes.json and redeploy:

firebase deploy --only firestore:indexes
```

### Problem: Permission Denied Errors

**Diagnostic Steps:**
1. Check user is authenticated
   ```dart
   print(FirebaseAuth.instance.currentUser?.uid);
   ```

2. Verify user is in participants
   ```dart
   final chat = await firestore.collection('chats').doc(chatId).get();
   print(chat.data()['participants']);
   ```

3. Check rule violations in Firebase Console

4. If using Test Mode, ensure 30-day expiration hasn't passed

### Problem: Indexes Taking Too Long to Build

- Firestore can take 5-15 minutes to build composite indexes
- Large collections may take longer
- Check index status: Firebase Console → Firestore → Indexes
- Can continue using app, queries will be slower until index is ready

### Problem: Rules Deployment Failed

```bash
# Validate rules first
firebase firestore:validate-rules --path=firestore.rules

# Check for syntax errors
# Common issues:
# - Missing semicolons
# - Mismatched brackets
# - Invalid field paths
# - Typos in collections/fields
```

## Performance Optimization

### Index-Covered Queries (No Full Scan)
✅ All 3 main queries are fully index-covered:
- `streamConversations()` - uses Index 1
- `streamPendingRequests()` - uses Index 2 + client-side filtering
- `streamMessages()` - uses Index 3

### Cost Optimization
- Indexes reduce query cost by 50-70%
- With these 3 indexes, most queries < 10 document reads
- Estimated cost for 10 concurrent users: $0.30-1.00/month

### Query Performance Targets
- Chat list load: < 500ms
- Pending requests load: < 500ms
- Message history load: < 300ms per 100 messages

## Security Hardening (Optional)

Additional rules for production:

```firestore
// Rate limiting (would require Cloud Functions)
// - Max 10 messages per minute per user
// - Max 100 chats created per day per user

// Data sanitization
// - Strip HTML from message text
// - Validate email/phone formats

// Audit logging
// - log all sensitive operations
// - Track who modified which documents
```

## Rollback Procedure

If issues occur after deployment:

```bash
# Option 1: Revert to previous version
git log --oneline firestore.rules firestore.indexes.json
git checkout <commit-hash> -- firestore.rules firestore.indexes.json
firebase deploy --only firestore:rules,firestore:indexes

# Option 2: Use Firestore backup
# Firebase Console → Firestore → Backups → Restore
# Select backup point and restore

# Option 3: Temporarily disable problematic rules
# Deploy permissive rules (Test Mode) while investigating
# Firebase Console → Firestore → Rules → Edit
```

## Sign-Off

- [ ] Configuration reviewed and validated
- [ ] All indexes created and enabled
- [ ] Security rules deployed and tested
- [ ] Performance meets targets
- [ ] Cost estimates acceptable
- [ ] Monitoring configured
- [ ] Team trained on maintenance
- [ ] Rollback procedure documented

**Date Configured:** April 17, 2026
**Last Verified:** [Update as needed]
**Verified By:** [Team member name]

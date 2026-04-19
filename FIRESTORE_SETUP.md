# Firestore Configuration Guide

This document explains the Firestore setup for the Triozy chat feature, including indexes and security rules.

## Files Overview

### `firestore.indexes.json`
Defines composite indexes required for efficient chat queries.

**Indexes Created:**
1. **chats** - `participants` (array-contains) + `lastMessageTime` (DESC)
   - Used by: `streamConversations()` to get user's chats ordered by recency
   - Query: `participants array-contains userId` + `orderBy lastMessageTime DESC`

2. **chats** - `participants` (array-contains) + `chatType` (ASC)
   - Used by: `streamPendingRequests()` to get pending requests
   - Query: `participants array-contains userId` + `chatType == 'request'`

3. **messages** (subcollection) - `timestamp` (ASC)
   - Used by: `streamMessages()` to display chat history
   - Query: `orderBy timestamp ASC`

### `firestore.rules`
Security rules protecting the Firestore database.

**Key Rules:**
- Users can only read/write chats they are participants in
- Users can only create messages in their own name
- Chat metadata cannot be modified after creation
- Messages can only be marked as read, not modified
- No document deletion from client (prevents accidental data loss)

## Deployment Instructions

### Option 1: Using Firebase Console (Recommended for Testing)

1. **Deploy Indexes:**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select your project → Firestore → Indexes
   - Indexes may auto-create when first running queries
   - Or manually create them by clicking "Create Index"
   - Use the `firestore.indexes.json` as reference

2. **Deploy Security Rules:**
   - Go to Firebase Console → Firestore → Rules
   - Copy contents from `firestore.rules`
   - Click "Publish" (test mode shows warning initially)

### Option 2: Using Firebase CLI (Production-Recommended)

#### Prerequisites:
```bash
npm install -g firebase-tools
firebase login
```

#### Deploy Configuration:
```bash
# Navigate to project directory
cd c:\Users\HP\Desktop\triozy\triozy_app

# Deploy both indexes and rules
firebase deploy --only firestore:indexes,firestore:rules

# Or deploy individually:
firebase deploy --only firestore:indexes
firebase deploy --only firestore:rules
```

## Query Performance Notes

### Covered Queries
These queries are fully optimized with the configured indexes:

```dart
// Query 1: Get user's chats (covered by index 1)
.where('participants', arrayContains: userId)
.orderBy('lastMessageTime', descending: true)

// Query 2: Get pending request chats (covered by index 2)
.where('participants', arrayContains: userId)
.where('chatType', isEqualTo: 'request')

// Query 3: Get messages in order (covered by index 3)
.orderBy('timestamp', descending: false)
```

### Read Cost Estimation
For a user with ~5 active chats:
- **streamConversations()**: ~1 read operation (list operation)
- **streamPendingRequests()**: ~1 read operation
- **streamMessages()**: ~1 read operation per conversation
- **sendMessage()**: 2 write operations (message + conversation metadata)
- **markAsRead()**: 2 write operations

**Daily Estimate** (10 active users, 50 messages/day):
- ~500 read operations
- ~150 write operations
- Total: **Cost < $1/month** (within free tier limits)

## Firestore Database Structure

```
chats/
├── {chatId}  [Composite Index 1 & 2]
│   ├── participants: [uid1, uid2]
│   ├── chatType: "mate" | "service" | "request"
│   ├── referenceId: string
│   ├── lastMessage: string
│   ├── lastMessageTime: Timestamp  [Indexed DESC]
│   ├── lastSenderId: string
│   ├── lastReadAt: {uid1: Timestamp, uid2: Timestamp}
│   ├── createdAt: Timestamp
│   ├── otherUserId: string
│   ├── otherUserName: string
│   ├── otherUserPhoto: string
│   └── otherUserLocation: string
│
│   messages/  [Composite Index 3]
│   └── {messageId}
│       ├── senderId: string
│       ├── receiverId: string
│       ├── text: string
│       ├── timestamp: Timestamp  [Indexed ASC]
│       └── status: "sent" | "read"
```

## Security Rule Breakdown

### Authentication
- All operations require user authentication
- `isAuthenticated()` checks if user is signed in

### Chat Access
- Two-way permission: only participants can read/write
- `isParticipant()` verifies user is in participants array

### Message Creation
- Only user who owns the message (senderId) can create it
- Receiver must be the other participant
- Text and timestamp are required
- Status must be "sent" or "read"

### Message Updates
- Messages can only change status from "sent" to "read"
- All other fields are immutable
- Prevents data corruption

### Data Protection
- Users cannot modify chat metadata after creation
- No client-side deletion allowed
- Prevents accidental or malicious data loss

## Testing the Rules

### With Firebase Emulator (Local Development)

```bash
# Start emulator
firebase emulators:start --only firestore

# In your Flutter app, use the emulator:
// Update main.dart or test configuration to point to emulator
// This allows testing without affecting production data
```

### Using Firebase Console Test Mode

1. Deploy rules in "Test Mode" (30 days expiration)
2. Allows read/write for development
3. Remember to switch to production rules before going live

## Rollback Procedure

If issues occur after deployment:

```bash
# Revert to previous rules version
firebase firestore:backups:restore

# Or manually redeploy from backup:
git checkout HEAD~1 -- firestore.rules
firebase deploy --only firestore:rules
```

## Monitoring & Optimization

### View Index Usage
- Firebase Console → Firestore → Indexes
- Check "Index Statistics" for read count and latency
- Disable unused indexes to reduce costs

### Monitor Security Rule Denials
- Firebase Console → Firestore → Rules
- Check "Rule Violations" in real-time
- Helps identify permission or data structure issues

### Enable Audit Logging
```bash
firebase firestore:indexes --project={PROJECT_ID}
```

## Next Steps

1. ✅ Configure indexes in firebase.json
2. ✅ Review firestore.rules
3. ⬜ Deploy via Firebase CLI:
   ```bash
   firebase deploy --only firestore:indexes,firestore:rules
   ```
4. ⬜ Test with Firebase Console or emulator
5. ⬜ Monitor performance metrics
6. ⬜ Switch from test mode to production rules

## Support & Resources

- [Firestore Indexes Documentation](https://firebase.google.com/docs/firestore/query-data/index-overview)
- [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/start)
- [Firebase CLI Documentation](https://firebase.google.com/docs/cli)
- [Firestore Pricing Calculator](https://firebase.google.com/pricing/calculator)

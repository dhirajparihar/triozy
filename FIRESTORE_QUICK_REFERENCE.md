# Firestore Configuration Quick Reference

## What Was Configured

✅ **3 Composite Indexes** for optimal query performance
✅ **Security Rules** protecting chat data 
✅ **Firebase CLI** configuration in `firebase.json`
✅ **Documentation** for deployment and monitoring

## Quick Deploy Checklist

### 1. Install Firebase CLI (One-time)
```bash
npm install -g firebase-tools
firebase login
```

### 2. Deploy Configuration
```bash
cd c:\Users\HP\Desktop\triozy\triozy_app

# Deploy indexes and rules
firebase deploy --only firestore:indexes,firestore:rules
```

### 3. Verify in Firebase Console
- Go to https://console.firebase.google.com
- Check Firestore → Indexes (should show 3 indexes)
- Check Firestore → Rules (should see security rules)

## Indexes Summary

| Collection | Fields | Usage |
|-----------|--------|-------|
| `chats` | `participants` (array) + `lastMessageTime` (DESC) | Get user's chats by recency |
| `chats` | `participants` (array) + `chatType` (ASC) | Filter pending requests |
| `messages` | `timestamp` (ASC) | Display chat history |

## Security Model

**Who can access what?**
- Users can read/write only chats they're participants in
- Messages are immutable (except status field)
- Only senders can create messages
- Chat metadata is locked after creation

**Cost Estimate:**
- ~500 reads/month for 10 active users
- ~150 writes/month for 10 active users
- **Total: < $1/month** (free tier safe)

## Files Created

```
triozy_app/
├── firestore.indexes.json       ← Composite indexes
├── firestore.rules              ← Security rules
├── firebase.json                ← Updated with Firestore config
└── FIRESTORE_SETUP.md            ← Detailed documentation
```

## Deployment Methods

### Via Firebase Console (GUI)
1. Manual index creation: Firebase Console → Firestore → Indexes
2. Manual rule update: Firebase Console → Firestore → Rules

### Via Firebase CLI (Recommended)
```bash
firebase deploy --only firestore:indexes,firestore:rules
```

### Just Rules or Just Indexes
```bash
# Rules only
firebase deploy --only firestore:rules

# Indexes only
firebase deploy --only firestore:indexes
```

## After Deployment

1. **Monitor Indexes**
   - Firebase Console → Firestore → Indexes
   - Verify all 3 indexes are "Enabled"

2. **Test Security Rules**
   - Firebase Console → Firestore → Rules → "Test" mode
   - Run queries to ensure they work

3. **Check Firestore Metrics**
   - Firebase Console → Firestore → Usage
   - Monitor read/write operations

## Production Checklist

- [ ] Deploy indexes and rules via Firebase CLI
- [ ] Verify all 3 indexes are enabled in Console
- [ ] Test chat creation in development
- [ ] Test message sending
- [ ] Verify pending requests filter works
- [ ] Switch rules from Test Mode to Production
- [ ] Monitor daily operations costs
- [ ] Enable backups (Firebase Console → Backups)

## Troubleshooting

### Indexes Not Created
```bash
# Manually trigger index creation
firebase firestore:indexes:resolve

# Deploy with verbose output
firebase deploy --only firestore:indexes --debug
```

### Rules Deployment Failed
```bash
# Validate rules syntax
firebase firestore:validate-rules --path=firestore.rules

# Check current rules on server
firebase firestore:download-rules
```

### Queries Failing
- Check browser console for exact error
- Verify user is authenticated (`isAuthenticated()`)
- Ensure user is in `participants` array
- Check Firestore Rules violations logs

## Next: Additional Optimizations

Consider implementing:
1. **Caching** - LocalStorage for offline chat history
2. **Pagination** - Load messages in batches
3. **Full-text Search** - Add Algolia for message search
4. **Message Deletion** - Soft delete (mark as deleted)
5. **Read Receipts** - Track when messages are read
6. **Typing Indicators** - Show when user is typing

## References

- 📖 [Firestore Indexes Guide](https://firebase.google.com/docs/firestore/query-data/index-overview)
- 🔐 [Security Rules Guide](https://firebase.google.com/docs/firestore/security/start)
- 💰 [Pricing Calculator](https://firebase.google.com/pricing/calculator)
- 🚀 [Firebase CLI Docs](https://firebase.google.com/docs/cli)

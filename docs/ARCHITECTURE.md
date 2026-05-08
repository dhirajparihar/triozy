# Triozy Flutter App Architecture

## Overview

Triozy is a Flutter app backed by Firebase and Cloudinary. The app uses `provider`
for dependency injection and shared state, Firebase Auth for authentication,
Cloud Firestore for app data, Firebase Cloud Messaging for notifications, and
Cloudinary for image uploads.

The current architecture is a service-oriented Flutter structure:

```text
Flutter screens and widgets
  -> Provider / ChangeNotifier state
  -> Service classes
  -> Firebase, Cloudinary, geocoding, and device APIs
```

Most screens own their local UI state with `StatefulWidget` and `setState`.
Shared cross-screen state is held in a small number of `ChangeNotifier` classes.

## Runtime Flow

```text
lib/main.dart
  -> Firebase initialization
  -> Firestore mobile persistence setup
  -> MultiProvider service registration
  -> MaterialApp
  -> _DeepLinkGate
  -> AuthGate
  -> _RoleRouter
  -> MainShell
  -> tab screens and pushed feature screens
```

Startup behavior:

- Firebase is initialized before `runApp`.
- Firestore offline persistence is enabled on non-web platforms.
- Android in-app update checks run after startup.
- A splash animation is shown before routing continues.
- Web deep links currently support `/account-delete`.
- First-time users are routed to onboarding.
- Authentication state is streamed from Firebase Auth.
- Logged-in users are routed based on their Firestore `users/{uid}` profile state.

## Project Layout

```text
lib/
  config/       Cloudinary configuration
  models/       Firestore/domain models
  providers/    ChangeNotifier shared state
  screens/      App screens and feature flows
  services/     Firebase, Cloudinary, location, chat, session services
  theme/        App colors and typography helpers
  utils/        Utility helpers and validators
  widgets/      Reusable UI components
```

Platform folders:

```text
android/        Android host project and Firebase config
ios/            iOS host project and Firebase config
web/            Web host files, manifest, and icons
assets/         App logos and category images
test/           Flutter tests
```

## Dependency Injection And State

Global dependencies are registered in `MultiProvider` in `lib/main.dart`.

Service providers:

- `AuthService`
- `CloudinaryService`
- `DatabaseService`
- `LocationService`
- `ChatService`

Shared state providers:

- `SessionService`
- `LocationProvider`
- `ChatProvider`

Provider roles:

- `SessionService` tracks guest mode.
- `LocationProvider` tracks current latitude, longitude, address, loading, and errors.
- `ChatProvider` tracks conversations, the active conversation, active messages, and unread count.

## Navigation

Navigation is mostly imperative and uses Flutter's built-in navigator:

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => SomeScreen()),
);
```

The only centralized route handling is in `MaterialApp.onGenerateRoute`, currently
for the account deletion deep link.

The authenticated app shell is `MainShell`, which uses an `IndexedStack` for tab
navigation. This keeps tab screens alive while switching tabs.

Main tabs:

- `HomeScreen`
- `ServicesScreen`
- `ChatListScreen`
- `UserProfileScreen`

Common pushed screens include:

- `ListingDetailScreen`
- `PostListingScreen`
- `HousingFeedScreen`
- `RequirementFormScreen`
- `ChatDetailScreen`
- `EditProfileScreen`
- `MyListingsScreen`
- `SavedListingsScreen`

## Backend Services

### AuthService

`AuthService` wraps Firebase Auth and user profile operations.

Responsibilities:

- Google sign-in
- Sign-out
- Starter user document creation
- User data fetch and stream
- Profile completion

Primary collection:

```text
users/{uid}
```

### DatabaseService

`DatabaseService` wraps listing and saved-listing Firestore access.

Responsibilities:

- Create listings
- Fetch all, featured, recent, saved, and user-owned listings
- Search listings
- Fetch a single listing
- Delete a listing with owner validation
- Toggle saved listings

Primary collections:

```text
listings/{listingId}
users/{uid}
```

### ChatService

`ChatService` wraps chat conversations and messages.

Responsibilities:

- Create or reuse listing chat conversations
- Send messages
- Stream conversations
- Stream messages
- Mark conversations/messages as read

Primary collections:

```text
chats/{chatId}
chats/{chatId}/messages/{messageId}
```

### LocationService

`LocationService` wraps device location and geocoding.

Responsibilities:

- Request/check location permission
- Read current GPS position
- Reverse geocode coordinates
- Resolve address text into coordinates
- Fall back to OpenStreetMap Nominatim when platform geocoding fails

### CloudinaryService

`CloudinaryService` uploads image bytes to Cloudinary and returns secure image URLs.

Used by:

- Listing image uploads
- Profile image uploads

## Domain Models

### ListingModel

`ListingModel` represents housing and marketplace listings.

Related enums:

- `ListingType`
- `PropertyType`
- `ListingPurpose`

Supported listing categories include:

- Housing posts
- Flatmate/roommate requirements
- Marketplace item posts

The model includes Firestore mapping with `fromMap` and `toMap`.

### RequirementModel

`RequirementModel` represents structured details for users looking for housing.
It is embedded in a listing through the `requirementDetails` field.

### Chat Models

`ConversationModel` and `MessageModel` represent chat metadata and individual
messages. Chat messages are stored as a subcollection under each chat document.

## Main Feature Flows

### Auth And Profile

```text
WelcomeScreen
  -> AuthService.signInWithGoogle
  -> users/{uid} starter document
  -> _RoleRouter streams users/{uid}
  -> CompleteProfileScreen if profile is incomplete
  -> MainShell when profile is complete
```

Guest users can enter `MainShell`, but authenticated-only actions prompt sign-in.

### Listings

```text
HomeScreen / HousingFeedScreen
  -> DatabaseService fetch/search listings
  -> ListingCard displays summary
  -> ListingDetailScreen displays full detail
```

Saved listings are stored on the user document as `savedListingIds`.

### Posting A Listing

```text
PostListingScreen
  -> ImagePicker selects images
  -> CloudinaryService uploads images
  -> ListingModel is created
  -> DatabaseService.createListing
  -> Firestore listings/{listingId}
```

### Chat

```text
ListingDetailScreen
  -> ChatProvider.createOrGetChat
  -> ChatService creates/reuses chat
  -> ChatDetailScreen opens conversation
  -> ChatProvider streams messages
  -> ChatService writes messages
```

Unread counts are computed in `ChatProvider` from conversation metadata.

### Location

```text
MainShell
  -> LocationProvider.fetchLocation
  -> LocationService.getCurrentPosition
  -> reverse geocoding
  -> TriozyTopAppBar displays address
```

If location fails, `MainShell` shows a dialog that can open device settings.

## Firestore Collections

Current app collections:

```text
users
listings
chats
chats/{chatId}/messages
```

Important user fields:

- `uid`
- `email`
- `name`
- `occupation`
- `organizationName`
- `gender`
- `isProfileComplete`
- `savedListingIds`
- `fcmTokens`

Important listing fields:

- `ownerId`
- `ownerName`
- `ownerPhotoUrl`
- `title`
- `description`
- `location`
- `latitude`
- `longitude`
- `price`
- `type`
- `propertyType`
- `purpose`
- `imageUrls`
- `highlights`
- `requirementDetails`
- `isFeatured`
- `createdAt`

Important chat fields:

- `participants`
- `chatType`
- `referenceId`
- `lastMessage`
- `lastMessageTime`
- `lastSenderId`
- `lastReadAt`
- `createdAt`

Important message fields:

- `senderId`
- `receiverId`
- `text`
- `timestamp`
- `status`

## UI Layer

Reusable UI components are in `lib/widgets`.

Key shared widgets:

- `TriozyTopAppBar`
- `AppBottomNavBar`
- `ListingCard`

Theme code is centralized in:

- `lib/theme/app_colors.dart`
- `lib/theme/app_theme.dart`

Screens generally combine UI rendering, local screen state, form handling, and
navigation. Larger screens may contain private helper widgets in the same file.

## Current Architectural Characteristics

Strengths:

- Clear folder separation by responsibility.
- Services isolate most backend operations.
- Provider keeps global dependency registration simple.
- Firestore streams are used for auth profile routing, user listings, chat lists, and messages.
- The tab shell preserves screen state with `IndexedStack`.

Tradeoffs:

- Some screens still call `FirebaseAuth.instance` and `FirebaseFirestore.instance` directly.
- Navigation is spread across screens instead of a centralized app router.
- `DatabaseService.getAllListings` fetches up to 300 listings and filters in memory.
- Several screens mix presentation, form state, service calls, and navigation.
- Model classes contain both domain behavior and Firestore serialization.

## Suggested Future Improvements

- Move all direct Firebase calls from screens into services or repositories.
- Introduce a small routing layer if deep links and navigation flows grow.
- Add query-based Firestore filtering for large listing datasets.
- Split larger screens into feature widgets when they become difficult to maintain.
- Add focused tests for services, model mapping, and critical feature flows.

# Triozy

> **Your local network, for everything.**

Triozy is a hyperlocal community connection platform built with Flutter and Firebase. It connects users directly with nearby service professionals, lets them post open requests, and enables peer-to-peer connections for roommates, helpmates, and ride sharing — all in one app.

No booking fees. No middlemen. Just direct, instant, human-to-human access.

---

## Core Pillars

### 🔧 Services
Browse and search local professionals across 30+ categories — electricians, plumbers, AC repair, tailors, and more. Tap a profile and call directly. No appointment booking, no platform fee.

### 📋 Requests
Can't find what you need? Post a public service request. The community sees it in the Requests tab and responds. Supports budget tiers, photos, and location tagging.

### 👥 Mates
Three unique peer-to-peer connection types:

| Type | Purpose |
|---|---|
| **Roommate** | Find a compatible flatmate nearby with budget, gender preference, and lifestyle filters |
| **Helpmate** | Connect with someone nearby who can help in any situation — errands, emergencies, medical, moving |
| **Ridemate** | Match with someone sharing your daily commute route on a bike or car |

---

## Features

- **Direct Call Model** — No transactions flow through the app. Users call service providers directly from their profile.
- **Location-Based Discovery** — GPS-powered nearby worker search using geospatial queries (`geoflutterfire_plus`), within a 25km radius.
- **Mates Hub** — Dedicated tab with sub-tabs, live search, and per-type filters (gender, availability, vehicle type, frequency).
- **Request Board** — Public job board where customers post requests visible to all workers.
- **Worker Dashboard** — Professionals manage their profile, availability toggle, location refresh, and mate listings.
- **My Mate Posts** — Users and workers can manage, review, and delete their own Roommate / Helpmate / Ridemate listings.
- **Firebase Auth** — Google Sign-In with role-based routing (customer vs. worker).
- **Real-Time Streams** — Firestore live streams for requests and mates listings.
- **Premium Design System** — "Tactile Concierge" design language: Manrope + Inter typography, glassmorphism, tonal surface hierarchy, ambient shadows.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) `^3.11.3` |
| Auth | Firebase Authentication (Google Sign-In) |
| Database | Cloud Firestore |
| Storage | Firebase Storage (profile photos) |
| Geolocation | `geolocator`, `geocoding`, `geoflutterfire_plus` |
| State | `provider` (LocationProvider) |
| Fonts | `google_fonts` (Manrope, Inter) |
| Payments | Razorpay (key configured, integration pending) |

---

## App Structure

```
lib/
├── constants/
│   └── app_categories.dart       # Single source of truth for all 30+ service categories
├── models/
│   ├── worker_model.dart         # Service professional data + geohash
│   ├── request_model.dart        # Customer job request data
│   └── mate_model.dart           # Roommate / Helpmate / Ridemate listings
├── providers/
│   └── location_provider.dart    # Shared GPS state (prevents duplicate requests)
├── screens/
│   ├── home_screen.dart          # Main feed: 3-pillar strip, categories, mates preview, top pros
│   ├── search_results_screen.dart
│   ├── requests_screen.dart
│   ├── mate_screen.dart          # Mates hub with sub-tabs, search, per-type filters
│   ├── add_mate_screen.dart      # Post a Roommate / Helpmate / Ridemate listing
│   ├── my_mates_screen.dart      # Manage own mate listings (delete)
│   ├── worker_list_screen.dart
│   ├── worker_profile_screen.dart
│   ├── worker_setup_screen.dart
│   ├── worker_dashboard_screen.dart
│   ├── user_profile_screen.dart
│   ├── add_request_screen.dart
│   └── all_categories_screen.dart
├── services/
│   ├── auth_service.dart         # Firebase auth + user role management
│   ├── database_service.dart     # Firestore CRUD: workers, requests, mates
│   └── location_service.dart     # GPS, reverse geocoding, geospatial queries
├── theme/
│   ├── app_colors.dart           # Full Material 3 color token set
│   └── app_theme.dart            # Typography scale (Manrope headlines, Inter body)
└── widgets/
    ├── bottom_nav_bar.dart       # 5-tab nav: Home | Search | Requests | Mates | Profile
    └── top_app_bar.dart          # Location display + avatar
```

---

## Navigation

```
Bottom Nav (5 tabs):
  0 → Home         — Feed with 3-pillar strip, mates preview, nearby pros
  1 → Search       — Filter workers by category + location
  2 → Requests     — All/my job requests board
  3 → Mates        — Roommate | Helpmate | Ridemate hub
  4 → Profile      — Account settings, my requests, my mates, logout
```

---

## Getting Started

### Prerequisites

- Flutter SDK `^3.11.3`
- Android Studio / VS Code
- Active Firebase project (Auth + Firestore + Storage enabled)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository_url>
   cd triozy_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Place `google-services.json` in `android/app/`
   - Place `GoogleService-Info.plist` in `ios/Runner/`

4. Run the app:
   ```bash
   flutter run
   ```

---

## Firestore Collections

| Collection | Purpose |
|---|---|
| `users` | User accounts with role (`customer` / `worker`) |
| `workers` | Professional profiles with geohash for spatial queries |
| `jobs` | Customer service requests (public board) |
| `mates` | Roommate, Helpmate, Ridemate listings |

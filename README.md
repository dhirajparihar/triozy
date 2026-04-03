# Triozy

Triozy is a location-based service professional discovery built with Flutter and Firebase. It enables customers to find, view, and connect with nearby workers (plumbers, electricians, cleaners, etc.) in real-time, leveraging spatial queries and GPS capabilities.

## Features

* **Location-Based Discovery**: Find nearby service professionals using spatial queries (`geoflutterfire_plus`).
* **Real-Time GPS**: Access current location dynamically using the device's GPS (`geolocator`).
* **Firebase Authentication**: Secure user authentication via Email/Password and Google Sign-In.
* **Worker Dashboard**: Service professionals can sign up, manage their profiles, and update their working location dynamically.
* **Modern UI**: Clean and intuitive user interface built with Flutter, utilizing custom fonts (`google_fonts`) and optimized image caching (`cached_network_image`).

## Tech Stack

* **Framework**: Flutter (Dart)
* **Backend service**: Firebase (Authentication, Cloud Firestore)
* **Geolocation & Mapping**: 
  * `geolocator` for device GPS access
  * `geocoding` for reverse geocoding addresses
  * `geoflutterfire_plus` for querying Firestore documents by geographical proximity

## Getting Started

### Prerequisites

* Flutter SDK (version `^3.11.3` or greater)
* Android Studio / VS Code
* An active Firebase project configured for Android and iOS

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
   * Ensure you have `google-services.json` in the `android/app` directory.
   * Ensure you have `GoogleService-Info.plist` in the `ios/Runner` directory.

4. Run the app:
   ```bash
   flutter run
   ```

## Architecture

The app is structured cleanly using service-based architecture:
* `lib/services/auth_service.dart`: Handles Firebase initialization and user authentication logic.
* `lib/services/database_service.dart`: Manages CRUD operations and spatial queries with Cloud Firestore.
* `lib/services/location_service.dart`: Encapsulates getting device permissions and fetching coordinates.
* `lib/models/worker_model.dart`: Structured data model for service professionals containing their coordinates for geo-hashing.

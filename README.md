# Kinnect Admin Dashboard

**Desktop & Web Administration Console for the Kinnect Platform**

[![Flutter](https://img.shields.io/badge/Flutter-Desktop%20%26%20Web-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)

---

## Overview

`kinnect_admin` is the dedicated administration and moderation dashboard for the **[Kinnect](https://github.com/emreceylantr/kinnect)** social discovery ecosystem. Built with Flutter for macOS, Windows, and Web, it provides real-time visibility into platform metrics, user profiles, AI matching telemetry, and community safety reports.

## Key Capabilities

- **Executive Dashboard (`dashboard_screen.dart`):** Real-time KPIs including total users, active sessions, post volume, AI match generation metrics, and platform growth trends.
- **User Management (`users_screen.dart` & `user_profile_detail_screen.dart`):** Search, inspect, verify, or moderate user accounts, view their posts, connected music services, and synthesized AI behavioral profiles.
- **AI Matching Inspector (`ai_matching_screen.dart`):** Audit AI compatibility scores, inspect `user_ai_profiles`, trigger profile re-analysis, and review evidence-backed match explanations across user pairs.
- **Moderation & Safety Reports (`reports_screen.dart`):** Review user-submitted reports and automated toxicity flags to keep the community safe.

## Project Structure

```text
lib/
├── core/                        # Core utilities & constants
├── models/                      # Admin data models
├── screens/
│   ├── ai_matching_screen.dart          # AI profile & compatibility inspector
│   ├── dashboard_screen.dart            # Real-time analytics overview
│   ├── login_screen.dart                # Admin authentication
│   ├── main_layout.dart                 # Responsive sidebar & navigation shell
│   ├── reports_screen.dart              # Content & user moderation queue
│   ├── user_profile_detail_screen.dart  # Deep-dive user profile & post viewer
│   └── users_screen.dart                # Searchable user directory
├── services/                    # Supabase admin data services
├── widgets/                     # Reusable dashboard cards, charts & tables
├── admin_theme.dart             # Custom dark glassmorphic design system
└── main.dart                    # Application entry point
```

## Getting Started

```bash
flutter pub get
flutter run -d macos   # or -d chrome / -d windows
```

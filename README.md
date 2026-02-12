# 🕒 ChronosLink: Smart Attendance System
**A high-performance, multi-platform attendance solution built with Flutter & Supabase.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)](https://nodejs.org)

---

## 📖 Overview
ChronosLink is a development-ready attendance ecosystem. It bridges the gap between mobile convenience and administrative oversight, offering seamless camera-based check-ins and automated reporting for teams of any size.

### ✨ Key Features
* **📸 Camera Check-in:** Instant daily presence tracking with integrated camera support.
* **🔐 Secure Auth:** Robust email signup and login powered by Supabase.
* **📊 Admin Intelligence:** Dedicated dashboard to create/edit employees and monitor activity.
* **📄 Monthly Reports:** One-click exportable summaries and per-employee breakdowns.
* **🌍 Multiplatform:** Runs natively on **Android, iOS, Windows, macOS, and Linux**.

---

## 🛠️ Tech Stack

| Layer | Technology | Role |
| :--- | :--- | :--- |
| **Frontend** | **Flutter (Dart)** | UI/UX & Cross-platform logic |
| **Database** | **Supabase (PostgreSQL)** | Real-time data storage |
| **Auth** | **Supabase Auth** | Session management & Security |
| **Backend** | **Node.js** | Specialized server-side scaffolding |

---

## 📂 Project Roadmap

```bash
├── lib/
│   ├── main.dart            # Application Entry Point
│   ├── screens/             # UI Layer (Auth, Admin, Home)
│   ├── services/            # API & Supabase logic
│   └── models/              # Data structures
├── backend/
│   ├── index.js             # Node.js server logic
│   └── package.json         # Backend dependencies
└── assets/                  # Images, Icons & SVG Screenshots
```
## 🚀 Getting Started

### 1. Prerequisites
* **Flutter SDK:** [Install here](https://flutter.dev/docs/get-started/install)
* **Node.js:** v16+ recommended
* **Supabase Project:** Required for Auth & Database

### 2. Environment Setup
Create a `.env` file in your `backend/` directory and configure your Supabase credentials in your Flutter `lib/services/` (or via a `.env` in the root).

### 3. Installation & Run

#### Frontend
```bash
# Get dependencies
flutter pub get

# Run the app
flutter run
```
<p align="center">
  <img src="https://github.com/user-attachments/assets/66f0322f-dbef-4cc5-b5a4-0951282f9026" width="250"/>
  <img src="https://github.com/user-attachments/assets/8c4b2dd6-8546-4c49-a5b4-c2e25ed1c5e9" width="250"/>
  <img src="https://github.com/user-attachments/assets/a54849cb-3cb0-429c-bfa3-e072554f98a4" width="250"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/04762cc8-b0dd-4b1a-bb21-7c37975da32f" width="250"/>
  <img src="https://github.com/user-attachments/assets/c7fed88b-2ede-419d-a0e9-beb465311f15" width="250"/>
  <img src="https://github.com/user-attachments/assets/52d62faf-e89a-4552-8de4-ae77af95bdf9" width="250"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/fd925cd7-b9d5-4c50-95af-e6c3001aeef9" width="250"/>
</p>


                                                                                                                                                                           Developed with ❤️ by Bholakumar186

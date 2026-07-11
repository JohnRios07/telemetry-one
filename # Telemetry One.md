# Telemetry One

### Technical Project Document (TPD)

**Version:** 1.0
**Date:** July 2026
**Project Status:** Planning Phase

---

# 1. Executive Summary

Telemetry One is a cross-platform mobile application designed to provide real-time telemetry visualization, driving analysis, and AI-assisted coaching for sim racing players using PlayStation 5.

The platform will initially support:

* Gran Turismo 7 (GT7)
* F1 25
* Assetto Corsa Competizione (Future Phase)

The product aims to become a complete racing companion, allowing users to monitor sessions, improve driving consistency, and receive intelligent recommendations based on telemetry data.

---

# 2. Vision

> Become the leading mobile telemetry and coaching platform for console sim racers.

---

# 3. Mission

Provide console players with professional-grade telemetry tools traditionally available only on PC simulators.

---

# 4. Product Goals

## Short-Term Goals

* Real-time telemetry dashboard
* Session recording
* Support for GT7 and F1

## Mid-Term Goals

* Advanced driving analytics
* Engineer recommendations
* Historical performance tracking

## Long-Term Goals

* AI coaching assistant
* Cloud synchronization
* Community and competitive features

---

# 5. Product Scope

## Included

### Connectivity

* UDP telemetry reception
* Automatic game detection
* Network diagnostics

### Telemetry

* Real-time dashboard
* Session recording
* Lap analysis

### Analytics

* Performance reports
* Driving consistency metrics

---

## Excluded (Initial Versions)

* PC integration
* Multiplayer synchronization
* Setup sharing marketplace
* Online leaderboards

---

# 6. Target Users

## Primary Users

* Casual sim racers
* Intermediate drivers
* Console players without access to professional telemetry software

## Secondary Users

* League drivers
* Streamers
* Competitive players

---

# 7. Product Architecture

```text
PS5
 ↓ UDP
Telemetry One Mobile App
 ├── UDP Receiver
 ├── Telemetry Decoder
 ├── Session Engine
 ├── Analytics Engine
 ├── AI Coach Engine
 └── UI Dashboard
```

---

# 8. Technology Stack

## Mobile

### Framework

* Flutter

### Language

* Dart

### State Management

* Riverpod

### Dependency Injection

* Riverpod Providers

### Local Storage

* SQLite
* Hive

### Charts & Rendering

* CustomPainter
* fl_chart

---

## Future Backend

### API

* Spring Boot 3

### Language

* Java 21

### Database

* PostgreSQL

### Cache

* Redis

### Cloud

* Google Cloud Platform

---

# 9. High Level Architecture

```text
┌─────────────────────┐
│       PS5           │
└─────────┬───────────┘
          │ UDP
          ▼
┌─────────────────────┐
│ UDP Communication   │
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│ Telemetry Parser    │
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│ Domain Models       │
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│ Analytics Engine    │
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│ Presentation Layer  │
└─────────────────────┘
```

---

# 10. Module Architecture

---

# 10.1 UDP Module

## Responsibilities

* Open UDP sockets
* Listen to telemetry packets
* Connection diagnostics
* Packet loss management

## Main Components

```text
UdpService
NetworkScanner
ConnectionManager
```

---

# 10.2 Telemetry Parser

Pattern:

```text
TelemetryParser
├── GT7Parser
├── F1Parser
└── ACCParser
```

Interface:

```dart
abstract class TelemetryParser {
  TelemetryData parse(Uint8List bytes);
}
```

---

# 10.3 Session Engine

Responsibilities:

* Start Session
* Stop Session
* Persist Data
* Export Sessions

---

# 10.4 Analytics Engine

Responsibilities:

* Lap comparison
* Tire analysis
* Fuel analysis
* Consistency metrics

---

# 10.5 AI Engine (Future)

Responsibilities:

* Coaching recommendations
* Driver profiling
* Predictive analysis

---

# 11. Domain Model

## TelemetryData

```yaml
timestamp
speed
rpm
gear
throttle
brake
steeringAngle
fuel
lapNumber
lapTime
bestLap
sector1
sector2
sector3
tireTemperatureFL
tireTemperatureFR
tireTemperatureRL
tireTemperatureRR
gForceX
gForceY
positionX
positionY
positionZ
```

---

# 12. Non-Functional Requirements

## Performance

* Dashboard refresh ≤ 50 ms
* Data latency ≤ 100 ms
* 30-60 FPS rendering

## Reliability

* Automatic reconnection
* Graceful error handling
* Session recovery

## Scalability

Architecture prepared for:

* Cloud services
* Multiple games
* Social features

---

# 13. Product Roadmap

---

# Iteration 1

# Telemetry Dashboard (MVP)

## Objective

Receive telemetry and display it in real time.

## Features

### Connectivity

* UDP communication
* Auto discovery
* Manual IP configuration

### Dashboard

* Speed
* RPM
* Gear indicator
* Shift lights
* Fuel indicator
* Tire temperatures
* Lap times

### Persistence

* Save sessions locally

## Deliverables

* Flutter application
* GT7 support
* F1 support
* Session storage

---

# Iteration 2

# Telemetry One Engineer

## Objective

Analyze telemetry and provide engineering feedback.

## Features

### Analysis

* Tire degradation
* Fuel strategy
* Lap consistency
* Driver comparison
* Corner performance

### Recommendations

Examples:

* Braking too late in Turn 4.
* Excessive steering input.
* Front tires overheating.

## Deliverables

* Analytics Engine
* Session Reports
* Engineering Recommendations

---

# Iteration 3

# Telemetry One Coach

## Objective

Provide intelligent driving guidance.

## Features

### Coaching

* Weak corner identification
* Progress tracking
* Driving style profiling
* Personalized recommendations

### AI Features

Examples:

* You lose 0.4s in slow corners.
* Aggressive throttle application detected.
* Inconsistent racing line.

## Deliverables

* AI Coach
* Improvement Tracking
* Driver Scoring System

---

# Iteration 4

# Telemetry One Cloud

## Features

* Account System
* Cloud Sync
* Backup & Restore
* Multi-device support

---

# Iteration 5

# Community Platform

## Features

* Share Sessions
* Compare Drivers
* League Integrations
* Leaderboards

---

# 14. Product Epics

## EPIC-01

Connectivity Platform

## EPIC-02

Telemetry Dashboard

## EPIC-03

Session Management

## EPIC-04

Analytics & Engineer

## EPIC-05

AI Coach

## EPIC-06

Cloud Platform

## EPIC-07

Community Features

---

# 15. Monetization Strategy

## Free Tier

* Basic dashboard
* Session history
* GT7 and F1 support

## Premium Tier

* Advanced analytics
* AI coach
* Cloud synchronization
* Unlimited history

---

# 16. Potential Risks

## Technical Risks

1. GT7 protocol changes.
2. iOS networking restrictions.
3. Battery consumption.
4. Telemetry packet loss.
5. Reverse engineering requirements.

---

# 17. Success Metrics

## MVP Metrics

* Dashboard latency < 100 ms
* Crash rate < 1%
* Session success rate > 95%

## Business Metrics

* Monthly active users
* Premium conversion rate
* Average session duration
* User retention

---

# 18. Product Tagline

**Telemetry One**

> *Your race engineer in your pocket.*

Alternative:

> *Transform telemetry into speed.*

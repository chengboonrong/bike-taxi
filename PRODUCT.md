# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

The customer and driver apps are native Android builds (Flutter, product flavors `customer` and `driver`). The admin panel is the same Flutter codebase built for the web and must work on a phone browser; it shares the apps' design language.

## Users

- **Riders**: people who want a quick, cheap motorbike ride across town and book it from their phone, often while standing on a sidewalk.
- **Drivers**: motorbike drivers who switch online, take nearby requests, ride to pickup, run the trip and collect cash. They use the app on a phone, often mounted on the bike, outdoors and between rides.
- **Operator/admin**: one person who approves drivers, watches today's rides and cancels stuck ones, from a phone or a laptop.

## Product Purpose

A bike-only taxi service MVP: phone OTP login, pick pickup and drop on a map, see the fare, book a bike, track the driver live; drivers accept, start and end rides and see earnings; an admin panel approves drivers and oversees rides.

This build is a demo / portfolio piece. It must look and behave launch-ready, but no real operations, riders or drivers are behind it.

## Positioning

Bike-only: one vehicle type, so there is no vehicle picker, no tiers and no surge menus. Booking is a single decision: where from, where to, go.

## Operating Context

- Target market: the US (inferred from "US most probably"; no city confirmed). Prices in US dollars, distances in miles, phone numbers in +1 format.
- Payment is cash, handed to the driver at drop-off.
- Maps are OpenStreetMap tiles; pickup and drop are set by tapping the map (no address search).
- Runs locally against the Firebase emulators for demos (`--dart-define=EMULATOR_HOST=...`).

## Capabilities and Constraints

- Stack: Flutter 3.38 (Material 3), Firebase Auth (phone OTP) + Cloud Firestore, flutter_map + latlong2, geolocator. No other packages so far; new dependencies need a reason.
- Fare = base + per-distance rate on straight-line distance (no routing).
- Location is shared only while the driver app is in the foreground.
- Ride states: requested → accepted → started → completed, or cancelled.
- Not in the MVP: address search, road routes, online payment, push notifications, ratings.
- Undecided: launch city (the map falls back to a default centre when location is unavailable).

## Brand Commitments

- Name: **Bike Taxi** (user decision; keep it). App labels: "Bike Taxi" and "Bike Taxi Driver"; the web panel is "Bike Taxi Admin".
- No logo or brand assets exist yet.

## Evidence on Hand

None. There are no riders, drivers, testimonials, ratings, trip counts or press. Do not invent any of them in the UI or copy.

## Product Principles

1. One decision to book: pickup, drop, go. Never add choices the bike-only model doesn't need.
2. Status is the product while a ride is live: whoever is looking should know in one glance what is happening and what to do next.
3. Built for outdoors and one hand: the driver app must work in sunlight, on a mount, with a thumb.
4. Money is plain: the fare is shown before booking and is the same number collected at the end.
5. Honest demo: it looks real, but it never fakes social proof or data.

## Accessibility & Inclusion

No product-specific standard was set. The baseline is WCAG AA contrast, 48 dp touch targets and screen-reader labels on map markers and status, with extra contrast and size in the driver app for outdoor use.

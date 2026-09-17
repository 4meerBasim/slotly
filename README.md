# Slotly

A salon and barbershop booking app. One Flutter codebase serves two audiences:
customers book a chair, shop owners run the diary. Which one you get is decided
by the `role` on your profile, set at sign-up.

Built on Supabase — Postgres, auth and row-level security, no server of my own.

## What it does

**Customer** — browse shops, pick a service, pick a barber, pick a slot, book.
Cancel from the bookings tab.

**Owner** — a day-by-day schedule with expected revenue, mark each appointment
done / cancelled / no-show, manage services and prices, add barbers, set who
performs which service, and set each barber's weekly working hours.

## The part that was actually hard

Availability. A slot is bookable only if it sits inside that barber's working
hours for that weekday, finishes before closing, misses every existing booking,
misses every scheduled absence, and is far enough in the future to be worth
offering.

That logic lives in `lib/scheduling/availability.dart` as a pure function with
no database or widget dependency, covered by 13 unit tests in
`test/availability_test.dart` — split shifts, lunch breaks, back-to-back
bookings, DST-safe wall-clock arithmetic, and lead time.

The client-side generator only keeps impossible times off the screen. The
server is the source of truth:

- `create_booking()` derives the end time and price from the service row, so a
  tampered client cannot book a $40 service for $1 or hold a chair all day. It
  re-checks working hours, absences and ownership before inserting.
- A Postgres exclusion constraint makes two overlapping live bookings for the
  same barber *impossible*, not merely unlikely:

  ```sql
  exclude using gist (
    staff_id with =,
    tstzrange(starts_at, ends_at) with &&
  ) where (status in ('pending', 'confirmed'))
  ```

  Two customers tapping Confirm on the same slot in the same instant: one wins,
  the other gets "Someone just took that time" and a refreshed slot list.

## Stack

| | |
|---|---|
| Flutter 3.44 / Dart 3.12 | Material 3, light and dark |
| Riverpod | state and dependency injection |
| go_router | routing, auth redirect |
| Supabase | Postgres, auth, row-level security |

## Setup

1. Create a project at [supabase.com](https://supabase.com).
2. Open the SQL editor and run `supabase/schema.sql`.
3. Turn off "Confirm email" under Authentication → Providers → Email, so demo
   accounts work without a mailbox.
4. Run the app with your project's keys:

   ```sh
   flutter run \
     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
     --dart-define=SUPABASE_KEY=your_publishable_key
   ```

   Keys are passed at build time and never committed.

### Demo data

Sign up in the app as `owner@slotly.app` with the **I own a shop** role, then run
`supabase/seed.sql`. That creates Ironside Barbers with four services, three
barbers with different skills, a full week of hours and a recurring lunch break.

Then sign up again as any customer email and book against it.

## Layout

```
lib/
  scheduling/availability.dart   slot generation, pure and tested
  models/                        plain Dart, hand-written fromJson
  data/                          repositories + Riverpod providers
  features/
    auth/                        sign in, sign up with role choice
    customer/                    browse, shop detail, booking flow, bookings
    owner/                       schedule, services, team, hours editor
supabase/
  schema.sql                     tables, RLS, create_booking()
  seed.sql                       demo shop
```

## Known limits

- Working hours are interpreted in the shop's `timezone` column, which the app
  does not yet expose in the UI — it defaults to `UTC`.
- Payments are not wired up; bookings are confirmed without a deposit.
- Reminders are not sent; there is no push notification setup yet.

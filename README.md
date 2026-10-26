# CS Mobile App (Community Service)

Flutter app para sa monitoring, scheduling at rescheduling ng community service duties.

## Paano patakbuhin

Ang folder na ito ay may `lib/` at `pubspec.yaml` lang. Kailangan pang gawin ang android/ios folders:

```bash
cd cs_mobile_app
flutter create .          # gumagawa ng android/, ios/, web/ nang hindi binubura ang lib/
flutter pub get
flutter run
```

## Demo accounts

- Admin (OSA): `admin@school.edu` / `admin123`
- Student: mag-register sa loob ng app (Register button)

## Features (ayon sa concept paper)

| Feature | Nasaan |
|---|---|
| User registration at login | `lib/screens/auth_screen.dart` |
| User profile (admin at student) | Profile tab, `home_screen.dart` |
| Dashboard | Dashboard tab (stats + susunod na duty) |
| Add records | Admin: Records tab, "Add record" |
| View records / ticket | Records tab at `record_detail.dart` (digital CS ticket) |
| Search at filter | Records tab (search bar + status chips) |
| Edit/update records | Admin: Edit icon, o "Mag-add ng rendered hours" |
| Delete records | Admin: Delete icon sa ticket |
| Schedule / reschedule duty | Ticket screen, "I-reschedule ang duty" |
| Local data storage | `shared_preferences` (`lib/store.dart`) |

## Mga limitasyon

- Walang notifications (nakasaad sa Project Limitations ng concept paper).
- Local storage lang ito: naka-save sa phone, hindi naka-sync sa ibang device. Kung gusto ninyo ng shared database (Firebase o Supabase), palitan lang ang `lib/store.dart`.
- Plain text ang password sa local storage. Pang-demo lang ito, hindi pang-production.

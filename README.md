# CS Mobile App (Community Service)

A Flutter app for monitoring, scheduling, and rescheduling community-service
duties. App data is stored in MySQL; a PHP API connects Flutter to XAMPP.
Do not connect Flutter directly to MySQL.

## XAMPP setup

1. Open the XAMPP Control Panel and start **Apache** and **MySQL**.
2. Copy the contents of `api/` to `C:\xampp\htdocs\cs_bmc_api\`. The API file
   should be at `C:\xampp\htdocs\cs_bmc_api\index.php`.
3. Open `http://localhost/phpmyadmin`, select **Import**, and import
   `api/schema.sql`. This creates the `cs_bmc` database and its tables.
   If the database already exists, import `api/migrations/001_profile_photo.sql`
   to add the profile photo column.
4. Create an admin account in PowerShell:

   ```powershell
   cd C:\xampp\htdocs\cs_bmc_api
   php seed_admin.php admin@school.edu "ReplaceWithAStrongPassword" "OSA Admin"
   ```

   Remember the password you chose; you will use it to log in as admin.

5. From the project folder, install Flutter packages and run the app in a
   browser:

   ```powershell
   cd C:\cs\cs_bmc
   flutter pub get
   flutter run -d chrome
   ```

   Default API address: `http://localhost/cs_bmc_api/index.php`.

### Android emulator or physical device

- Android emulator: run Flutter with
  `flutter run --dart-define=API_BASE_URL=http://10.0.2.2/cs_bmc_api/index.php`.
- Physical Android device: connect the phone and computer to the same network,
  find the computer's LAN IPv4 address (`ipconfig`), and use it in the API URL.
  For example:
  `flutter run --dart-define=API_BASE_URL=http://192.168.1.10/cs_bmc_api/index.php`.
- Allow Apache through Windows Firewall if prompted. HTTP/cleartext is for local
  development only; use HTTPS before deploying to the internet.

If the MySQL database name or credentials differ, set `CS_BMC_DB_HOST`,
`CS_BMC_DB_NAME`, `CS_BMC_DB_USER`, and `CS_BMC_DB_PASSWORD` in the Apache/PHP
environment.

## Database and security

- `api/schema.sql` defines the MySQL schema (`users`, `records`, and `api_tokens`).
- `api/migrations/001_profile_photo.sql` adds the profile photo field to
  databases created before profile photos were added.
- Profile photos accept JPG, PNG, and WebP files up to 5 MB. Uploaded files are
  stored in `api/uploads/profiles/`.
- `api/index.php` is the JSON API for authentication and record operations.
- `api/config.php` contains the database connection settings. Default XAMPP
  values are `127.0.0.1`, database `cs_bmc`, user `root`, and a blank password.
  Change these for your local MySQL configuration.
- Passwords are hashed on the server with PHP `password_hash`; the Flutter app
  does not store passwords. Only the login token is saved on the device.
- Do not expose the default XAMPP configuration to the public internet. Set a
  strong MySQL password and use HTTPS in production.
- Existing demo accounts and records saved in `shared_preferences` are not
  automatically transferred to MySQL. Register again or create an admin with
  `seed_admin.php`.

## Features

| Feature | Location |
|---|---|
| User registration and login | `lib/screens/auth_screen.dart`, `api/index.php` |
| Editable profile information and photo | Profile tab, `lib/screens/home_screen.dart` |
| Profile photos in dashboard and records | Dashboard, record cards, and ticket details |
| Dashboard and duty schedule | Dashboard tab |
| Add, edit, and delete records | Records tab and ticket screen |
| View records and tickets | `lib/screens/record_detail.dart` |
| Search and status filters | Records tab |
| Local MySQL persistence | XAMPP MySQL through the PHP API |

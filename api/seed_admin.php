<?php
declare(strict_types=1);

require_once __DIR__ . '/config.php';

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

if ($argc !== 4) {
    fwrite(STDERR, "Usage: php seed_admin.php <email> <password> <name>\n");
    exit(1);
}

[$script, $email, $password, $name] = $argv;
if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($password) < 8 || trim($name) === '') {
    fwrite(STDERR, "Use a valid email, a password with at least 8 characters, and a name.\n");
    exit(1);
}

$db = database();
$statement = $db->prepare(
    "INSERT INTO users (name, student_no, email, password_hash, role)
     VALUES (?, NULL, ?, ?, 'admin')
     ON DUPLICATE KEY UPDATE name = VALUES(name), password_hash = VALUES(password_hash), role = 'admin'"
);
$statement->execute([
    trim($name),
    strtolower($email),
    password_hash($password, PASSWORD_DEFAULT),
]);
fwrite(STDOUT, "Admin account created/updated: {$email}\n");

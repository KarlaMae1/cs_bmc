<?php
declare(strict_types=1);

require_once __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Auth-Token');

function respond(int $status, array $data): never
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function require_method(string $expected): void
{
    if ($_SERVER['REQUEST_METHOD'] !== $expected) {
        header('Allow: GET, POST, PUT, DELETE, OPTIONS');
        respond(405, ['error' => 'The request method is not supported.']);
    }
}

function input(): array
{
    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) {
        respond(400, ['error' => 'The request data is invalid.']);
    }
    return $data;
}

function required_string(array $data, string $key, int $maxLength): string
{
    $value = $data[$key] ?? null;
    if (!is_string($value) || trim($value) === '' || mb_strlen(trim($value)) > $maxLength) {
        respond(422, ['error' => 'The ' . $key . ' value is invalid.']);
    }
    return trim($value);
}

function valid_date(mixed $value): ?string
{
    if ($value === null || $value === '') {
        return null;
    }
    if (!is_string($value)) {
        respond(422, ['error' => 'The duty date is invalid.']);
    }
    $date = DateTimeImmutable::createFromFormat('!Y-m-d', $value);
    if (!$date || $date->format('Y-m-d') !== $value) {
        respond(422, ['error' => 'The duty date is invalid.']);
    }
    return $value;
}

function public_user(array $user): array
{
    return [
        'id' => (string)$user['id'],
        'name' => $user['name'],
        'email' => $user['email'],
        'role' => $user['role'],
        'studentNo' => $user['student_no'],
        'profilePhoto' => $user['profile_photo'],
    ];
}

function request_token(): ?string
{
    $authorization = $_SERVER['HTTP_AUTHORIZATION']
        ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
        ?? '';
    $token = $_SERVER['HTTP_X_AUTH_TOKEN'] ?? '';

    if (function_exists('getallheaders')) {
        foreach (getallheaders() as $name => $value) {
            if (strcasecmp($name, 'Authorization') === 0) {
                $authorization = $value;
            } elseif (strcasecmp($name, 'X-Auth-Token') === 0) {
                $token = $value;
            }
        }
    }

    if (preg_match('/^Bearer\s+([a-f0-9]{64})$/i', trim($authorization), $matches)) {
        return $matches[1];
    }
    if (preg_match('/^[a-f0-9]{64}$/i', trim($token), $matches)) {
        return $matches[0];
    }
    return null;
}

function user_by_id(PDO $db, int $id): array
{
    $statement = $db->prepare(
        'SELECT id, name, student_no, email, role, profile_photo FROM users WHERE id = ?'
    );
    $statement->execute([$id]);
    $user = $statement->fetch();
    if (!$user) {
        respond(404, ['error' => 'User not found.']);
    }
    return $user;
}

function current_user(PDO $db): array
{
    $token = request_token();
    if ($token === null) {
        respond(401, ['error' => 'Please log in first.']);
    }
    $hash = hash('sha256', $token);
    $statement = $db->prepare(
        'SELECT u.id, u.name, u.student_no, u.email, u.role, u.profile_photo
         FROM api_tokens t JOIN users u ON u.id = t.user_id
         WHERE t.token_hash = ? AND t.expires_at > UTC_TIMESTAMP()'
    );
    $statement->execute([$hash]);
    $user = $statement->fetch();
    if (!$user) {
        respond(401, ['error' => 'Your session expired. Please log in again.']);
    }
    return $user;
}

function issue_session(PDO $db, int $userId): array
{
    $token = bin2hex(random_bytes(32));
    $statement = $db->prepare(
        'INSERT INTO api_tokens (user_id, token_hash, expires_at)
         VALUES (?, ?, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 DAY))'
    );
    $statement->execute([$userId, hash('sha256', $token)]);
    return ['token' => $token, 'user' => public_user(user_by_id($db, $userId))];
}

function record_rows(PDO $db, array $user): array
{
    $query = "SELECT r.id, r.ticket_no, r.student_id, r.violation,
                     r.hours_required, r.hours_rendered, r.status, r.duty_date,
                     r.duty_time, r.note,
                     DATE_FORMAT(r.created_at, '%Y-%m-%dT%H:%i:%sZ') AS created_at
              FROM records r";
    if ($user['role'] !== 'admin') {
        $query .= ' WHERE r.student_id = ?';
    }
    $query .= ' ORDER BY r.created_at DESC, r.id DESC';
    $statement = $db->prepare($query);
    $statement->execute($user['role'] === 'admin' ? [] : [$user['id']]);

    return array_map(static fn(array $row): array => [
        'id' => (string)$row['id'],
        'ticketNo' => $row['ticket_no'],
        'studentId' => (string)$row['student_id'],
        'violation' => $row['violation'],
        'hoursRequired' => (float)$row['hours_required'],
        'hoursRendered' => (float)$row['hours_rendered'],
        'status' => $row['status'],
        'dutyDate' => $row['duty_date'],
        'dutyTime' => $row['duty_time'],
        'note' => $row['note'],
        'createdAt' => $row['created_at'],
    ], $statement->fetchAll());
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

try {
    $db = database();
    $action = $_GET['action'] ?? '';

    if ($action === 'login') {
        require_method('POST');
        $data = input();
        $email = required_string($data, 'email', 254);
        $password = $data['password'] ?? null;
        if (!is_string($password)) {
            respond(422, ['error' => 'Enter a password.']);
        }
        $statement = $db->prepare(
            'SELECT id, password_hash FROM users WHERE email = ?'
        );
        $statement->execute([$email]);
        $user = $statement->fetch();
        if (!$user || !password_verify($password, $user['password_hash'])) {
            respond(401, ['error' => 'Incorrect email or password.']);
        }
        respond(200, issue_session($db, (int)$user['id']));
    }

    if ($action === 'register') {
        require_method('POST');
        $data = input();
        $name = required_string($data, 'name', 150);
        $studentNo = required_string($data, 'studentNo', 60);
        $email = required_string($data, 'email', 254);
        $password = $data['password'] ?? null;
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            respond(422, ['error' => 'Enter a valid email address.']);
        }
        if (!is_string($password) || strlen($password) < 6) {
            respond(422, ['error' => 'The password must be at least 6 characters long.']);
        }
        $statement = $db->prepare(
            "INSERT INTO users (name, student_no, email, password_hash, role)
             VALUES (?, ?, ?, ?, 'student')"
        );
        $statement->execute([
            $name,
            $studentNo,
            strtolower($email),
            password_hash($password, PASSWORD_DEFAULT),
        ]);
        respond(201, issue_session($db, (int)$db->lastInsertId()));
    }

    if ($action === 'bootstrap') {
        require_method('GET');
        $user = current_user($db);
        if ($user['role'] === 'admin') {
            $statement = $db->query(
                "SELECT id, name, student_no, email, role, profile_photo
                 FROM users WHERE role = 'student' ORDER BY name"
            );
            $users = array_map('public_user', $statement->fetchAll());
        } else {
            $users = [];
        }
        array_unshift($users, public_user($user));
        respond(200, [
            'user' => public_user($user),
            'users' => $users,
            'records' => record_rows($db, $user),
        ]);
    }

    if ($action === 'profile') {
        require_method('POST');
        $user = current_user($db);
        $name = required_string($_POST, 'name', 150);
        $email = required_string($_POST, 'email', 254);
        $studentNo = trim((string)($_POST['studentNo'] ?? ''));
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            respond(422, ['error' => 'Enter a valid email address.']);
        }
        if (mb_strlen($studentNo) > 60) {
            respond(422, ['error' => 'Student number must be 60 characters or fewer.']);
        }

        $photoPath = null;
        if (isset($_FILES['photo']) && $_FILES['photo']['error'] !== UPLOAD_ERR_NO_FILE) {
            $upload = $_FILES['photo'];
            if ($upload['error'] !== UPLOAD_ERR_OK) {
                respond(422, ['error' => 'The profile photo could not be uploaded.']);
            }
            if ($upload['size'] > 5 * 1024 * 1024) {
                respond(413, ['error' => 'The profile photo must be 5 MB or smaller.']);
            }
            $imageInfo = getimagesize($upload['tmp_name']);
            $mime = (new finfo(FILEINFO_MIME_TYPE))->file($upload['tmp_name']);
            $extensions = [
                'image/jpeg' => 'jpg',
                'image/png' => 'png',
                'image/webp' => 'webp',
            ];
            if ($imageInfo === false || !isset($extensions[$mime])) {
                respond(422, ['error' => 'Choose a valid JPG, PNG, or WebP image.']);
            }

            $filename = bin2hex(random_bytes(16)) . '.' . $extensions[$mime];
            $uploadDirectory = __DIR__ . '/uploads/profiles';
            if (!is_dir($uploadDirectory) &&
                !mkdir($uploadDirectory, 0755, true) &&
                !is_dir($uploadDirectory)) {
                throw new RuntimeException('Unable to create the profile photo directory.');
            }
            if (!move_uploaded_file($upload['tmp_name'], $uploadDirectory . '/' . $filename)) {
                throw new RuntimeException('Unable to save the uploaded profile photo.');
            }
            $photoPath = 'uploads/profiles/' . $filename;
        }

        $oldPhoto = $user['profile_photo'];
        $statement = $db->prepare(
            'UPDATE users
             SET name = ?, email = ?, student_no = ?, profile_photo = COALESCE(?, profile_photo)
             WHERE id = ?'
        );
        try {
            $statement->execute([
                $name,
                strtolower($email),
                $user['role'] === 'student' && $studentNo !== '' ? $studentNo : null,
                $photoPath,
                $user['id'],
            ]);
        } catch (Throwable $error) {
            if ($photoPath !== null) {
                @unlink(__DIR__ . '/' . $photoPath);
            }
            throw $error;
        }

        $updatedUser = public_user(user_by_id($db, (int)$user['id']));
        if ($photoPath !== null && is_string($oldPhoto) &&
            preg_match('#^uploads/profiles/[a-f0-9]{32}\.(jpg|png|webp)$#', $oldPhoto)) {
            $oldFile = __DIR__ . '/' . $oldPhoto;
            if (is_file($oldFile)) {
                unlink($oldFile);
            }
        }
        respond(200, ['user' => $updatedUser]);
    }

    if ($action === 'logout') {
        require_method('POST');
        current_user($db);
        $token = request_token();
        $statement = $db->prepare('DELETE FROM api_tokens WHERE token_hash = ?');
        $statement->execute([hash('sha256', $token)]);
        respond(200, ['ok' => true]);
    }

    if ($action === 'records' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        $user = current_user($db);
        if ($user['role'] !== 'admin') {
            respond(403, ['error' => 'Only admins can create records.']);
        }
        $data = input();
        $studentId = filter_var($data['studentId'] ?? null, FILTER_VALIDATE_INT);
        $violation = required_string($data, 'violation', 1000);
        $hours = filter_var($data['hoursRequired'] ?? null, FILTER_VALIDATE_FLOAT);
        $dutyDate = valid_date($data['dutyDate'] ?? null);
        $dutyTime = is_string($data['dutyTime'] ?? null) ? trim($data['dutyTime']) : '';
        if (!$studentId || !$hours || $hours <= 0 || $hours > 10000 || strlen($dutyTime) > 100) {
            respond(422, ['error' => 'The student or required hours value is invalid.']);
        }
        $student = user_by_id($db, $studentId);
        if ($student['role'] !== 'student') {
            respond(422, ['error' => 'Select a student account.']);
        }
        $db->beginTransaction();
        $statement = $db->prepare(
            "INSERT INTO records
             (student_id, violation, hours_required, duty_date, duty_time)
             VALUES (?, ?, ?, ?, ?)"
        );
        $statement->execute([$studentId, $violation, $hours, $dutyDate, $dutyTime]);
        $id = (int)$db->lastInsertId();
        $ticketNo = 'CS-' . gmdate('Y') . '-' . str_pad((string)$id, 4, '0', STR_PAD_LEFT);
        $statement = $db->prepare('UPDATE records SET ticket_no = ? WHERE id = ?');
        $statement->execute([$ticketNo, $id]);
        $db->commit();
        respond(201, ['ok' => true, 'id' => (string)$id, 'ticketNo' => $ticketNo]);
    }

    if ($action === 'records' && $_SERVER['REQUEST_METHOD'] === 'PUT') {
        $user = current_user($db);
        if ($user['role'] !== 'admin') {
            respond(403, ['error' => 'Only admins can edit records.']);
        }
        $data = input();
        $id = filter_var($data['id'] ?? null, FILTER_VALIDATE_INT);
        $studentId = filter_var($data['studentId'] ?? null, FILTER_VALIDATE_INT);
        $violation = required_string($data, 'violation', 1000);
        $required = filter_var($data['hoursRequired'] ?? null, FILTER_VALIDATE_FLOAT);
        $rendered = filter_var($data['hoursRendered'] ?? null, FILTER_VALIDATE_FLOAT);
        $date = valid_date($data['dutyDate'] ?? null);
        $time = is_string($data['dutyTime'] ?? null) ? trim($data['dutyTime']) : '';
        if (!$id || !$studentId || !$required || $required <= 0 || $required > 10000 ||
            $rendered === false || $rendered < 0 || strlen($time) > 100) {
            respond(422, ['error' => 'The record details are invalid.']);
        }
        $student = user_by_id($db, $studentId);
        if ($student['role'] !== 'student') {
            respond(422, ['error' => 'Select a student account.']);
        }
        $status = $rendered >= $required ? 'Completed' : ($rendered > 0 ? 'Ongoing' : 'Pending');
        $statement = $db->prepare(
            'UPDATE records SET student_id = ?, violation = ?, hours_required = ?,
             hours_rendered = ?, status = ?, duty_date = ?, duty_time = ? WHERE id = ?'
        );
        $statement->execute([
            $studentId, $violation, $required, $rendered, $status, $date, $time, $id,
        ]);
        if ($statement->rowCount() === 0) {
            $check = $db->prepare('SELECT id FROM records WHERE id = ?');
            $check->execute([$id]);
            if (!$check->fetch()) {
                respond(404, ['error' => 'Record not found.']);
            }
        }
        respond(200, ['ok' => true]);
    }

    if ($action === 'records' && $_SERVER['REQUEST_METHOD'] === 'DELETE') {
        $user = current_user($db);
        if ($user['role'] !== 'admin') {
            respond(403, ['error' => 'Only admins can delete records.']);
        }
        $data = input();
        $id = filter_var($data['id'] ?? null, FILTER_VALIDATE_INT);
        if (!$id) {
            respond(422, ['error' => 'The record ID is invalid.']);
        }
        $statement = $db->prepare('DELETE FROM records WHERE id = ?');
        $statement->execute([$id]);
        if ($statement->rowCount() === 0) {
            respond(404, ['error' => 'Record not found.']);
        }
        respond(200, ['ok' => true]);
    }

    if ($action === 'reschedule') {
        require_method('POST');
        $user = current_user($db);
        $data = input();
        $id = filter_var($data['id'] ?? null, FILTER_VALIDATE_INT);
        $date = valid_date($data['dutyDate'] ?? null);
        $time = required_string($data, 'dutyTime', 100);
        $note = required_string($data, 'note', 1000);
        if (!$id || $date === null) {
            respond(422, ['error' => 'Select a valid duty date.']);
        }
        $statement = $db->prepare('SELECT student_id, status FROM records WHERE id = ?');
        $statement->execute([$id]);
        $record = $statement->fetch();
        if (!$record) {
            respond(404, ['error' => 'Record not found.']);
        }
        if ($user['role'] !== 'admin' && (int)$record['student_id'] !== (int)$user['id']) {
            respond(403, ['error' => 'You cannot modify this record.']);
        }
        if ($record['status'] === 'Completed') {
            respond(409, ['error' => 'Completed records cannot be rescheduled.']);
        }
        $statement = $db->prepare(
            'UPDATE records SET duty_date = ?, duty_time = ?, note = ? WHERE id = ?'
        );
        $statement->execute([$date, $time, $note, $id]);
        respond(200, ['ok' => true]);
    }

    respond(404, ['error' => 'Unknown API action.']);
} catch (PDOException $error) {
    error_log($error->__toString());
    if (($error->errorInfo[1] ?? null) === 1062) {
        respond(409, ['error' => 'An account already uses this email address or student number.']);
    }
    respond(500, ['error' => 'Could not connect to the database. Check the XAMPP MySQL service and database setup.']);
} catch (Throwable $error) {
    error_log($error->__toString());
    respond(500, ['error' => 'An unexpected PHP API error occurred. Check the Apache error log.']);
}

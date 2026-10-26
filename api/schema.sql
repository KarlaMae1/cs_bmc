CREATE DATABASE IF NOT EXISTS cs_bmc
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE cs_bmc;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(150) NOT NULL,
  student_no VARCHAR(60) NULL DEFAULT NULL,
  profile_photo VARCHAR(255) NULL DEFAULT NULL,
  email VARCHAR(254) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('admin', 'student') NOT NULL DEFAULT 'student',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email),
  UNIQUE KEY uq_users_student_no (student_no)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS records (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  ticket_no VARCHAR(40) NULL,
  student_id BIGINT UNSIGNED NOT NULL,
  violation VARCHAR(1000) NOT NULL,
  hours_required DECIMAL(7,2) NOT NULL,
  hours_rendered DECIMAL(7,2) NOT NULL DEFAULT 0,
  status ENUM('Pending', 'Ongoing', 'Completed') NOT NULL DEFAULT 'Pending',
  duty_date DATE NULL,
  duty_time VARCHAR(100) NOT NULL DEFAULT '',
  note VARCHAR(1000) NOT NULL DEFAULT '',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_records_ticket_no (ticket_no),
  KEY ix_records_student_created (student_id, created_at),
  CONSTRAINT fk_records_student
    FOREIGN KEY (student_id) REFERENCES users (id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_records_hours CHECK (hours_required > 0 AND hours_rendered >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS api_tokens (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_api_tokens_hash (token_hash),
  KEY ix_api_tokens_expiry (expires_at),
  CONSTRAINT fk_api_tokens_user
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

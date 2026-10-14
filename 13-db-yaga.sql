CREATE DATABASE db_shibuya_k43;

-- Buat user yang dapat diakses dari seluruh IP di subnet backend
CREATE USER 'k-43'@'10.85.4.%' IDENTIFIED BY 'k-43-123';
GRANT ALL PRIVILEGES ON db_shibuya_k43.* TO 'k-43'@'10.85.4.%';

CREATE USER 'replica'@'10.85.4.%' IDENTIFIED BY 'replica123';
GRANT REPLICATION SLAVE ON *.* TO 'replica'@'10.85.4.%';

FLUSH PRIVILEGES;

USE db_shibuya_k43;

-- Tabel untuk mencatat riwayat akses request dari load balancer
CREATE TABLE request_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    worker_name VARCHAR(50) NOT NULL,
    client_ip VARCHAR(50) NOT NULL,
    proxy_ip VARCHAR(50) NOT NULL,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SHOW MASTER STATUS;

EXIT;

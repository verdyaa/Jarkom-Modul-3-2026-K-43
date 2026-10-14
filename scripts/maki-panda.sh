#!/bin/bash
apt-get update -y && apt upgrade -y
apt-get install -y nginx php-fpm php-mysqli mariadb-client

cat > /etc/nginx/sites-available/default <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.php index.html;

    server_name _;
    allow 10.85.1.4;
    deny all;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX

cat > /var/www/html/index.php <<'PHP'
<?php
header('Content-Type: text/html; charset=UTF-8');

// Konfigurasi Database Terpusat (Sesuaikan IP DB-Server dengan prefix kelompok)
$db_host = "10.85.4.2";
$db_user = "k-43";
$db_pass = "k-43-123";
$db_name = "db_shibuya_k43";

$hostname    = gethostname();
$server_ip   = $_SERVER['SERVER_ADDR'] ?? 'Unknown';
$proxy_ip    = $_SERVER['REMOTE_ADDR'] ?? 'Unknown';
$client_ip   = $_SERVER['HTTP_X_REAL_IP'] ?? $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $proxy_ip;
$user_agent  = $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown';

$db_status   = "Terkoneksi";
$total_hits  = 0;

// Koneksi ke MariaDB Terpusat
$conn = @new mysqli($db_host, $db_user, $db_pass, $db_name);

if ($conn->connect_error) {
    $db_status = "Gagal: " . $conn->connect_error;
} else {
    // Insert log request
    $stmt = $conn->prepare("INSERT INTO request_logs (worker_name, client_ip, proxy_ip, user_agent) VALUES (?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("ssss", $hostname, $client_ip, $proxy_ip, $user_agent);
        $stmt->execute();
        $stmt->close();
    }

    // Hitung total request yang tercatat di seluruh cluster
    $res = $conn->query("SELECT COUNT(*) AS total FROM request_logs");
    if ($res) {
        $row = $res->fetch_assoc();
        $total_hits = $row['total'];
    }
    $conn->close();
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>Cluster Worker: <?php echo htmlspecialchars($hostname); ?></title>
    <style>
        body { font-family: monospace; background: #0f172a; color: #f8fafc; padding: 2rem; }
        .card { background: #1e293b; border: 1px solid #334155; padding: 1.5rem; border-radius: 8px; max-width: 650px; }
        h2 { margin-top: 0; color: #38bdf8; border-bottom: 1px solid #334155; padding-bottom: 8px; }
        pre { font-family: monospace; font-size: 14px; margin: 0; line-height: 1.8; color: #f8fafc; }
    </style>
</head>
<body>
    <div class="card">
        <h2>Backend Cluster Worker</h2>
<pre>
Worker Hostname: <?php echo htmlspecialchars($hostname); ?>

Worker Local IP: <?php echo htmlspecialchars($server_ip); ?>

Reverse Proxy IP: <?php echo htmlspecialchars($proxy_ip); ?>

Client Real IP: <?php echo htmlspecialchars($client_ip); ?>

Status Database: <?php echo htmlspecialchars($db_status); ?>

Total Cluster Requests: <?php echo htmlspecialchars($total_hits); ?>
</pre>
    </div>
</body>
</html>
PHP

rm -f /var/www/html/index.html

service php8.4-fpm start
service php8.4-fpm status
nginx -t
service nginx restart || service nginx start
service nginx status

cat << "EOF" > /etc/php/8.4/fpm/pool.d/www.conf
[www]

user = www-data
group = www-data

listen = /run/php/php8.4-fpm.sock

listen.owner = www-data
listen.group = www-data

pm = dynamic
pm.max_children = 30
pm.start_servers = 6
pm.min_spare_servers = 4
pm.max_spare_servers = 10
pm.max_requests = 500

;pm.max_spawn_rate = 32
EOF

service php8.4-fpm restart
service php8.4-fpm status

ls -la /run/php/

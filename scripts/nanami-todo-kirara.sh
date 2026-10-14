#!/bin/bash

apt-get update -y && apt upgrade -y
apt-get install -y nginx php-fpm php-mysqli mariadb-client

cat > /etc/nginx/sites-available/api_worker <<'NGINX'
server {
    listen 80 default_server;
    server_name _;

    root /var/www/html;
    index index.php;

    # Restriksi Akses: Hanya Geto (Load Balancer API) yang boleh mengakses
    allow 10.85.4.4; 
    deny all;             

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock; 
    }
}
NGINX

ln -s /etc/nginx/sites-available/api_worker /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
rm -f /var/www/html/index.html

cat > /var/www/html/index.php <<'PHP'
<?php
header('Content-Type: application/json; charset=UTF-8');

$db_host = "10.85.4.2";
$db_user = "k-43";
$db_pass = "k-43-123";
$db_name = "db_shibuya_k43";

$hostname    = gethostname();
$server_ip   = $_SERVER['SERVER_ADDR'] ?? 'Unknown';
$proxy_ip    = $_SERVER['REMOTE_ADDR'] ?? 'Unknown';
$client_ip   = $_SERVER['HTTP_X_REAL_IP'] ?? $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $proxy_ip;
$user_agent  = $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown';

$response = [
    "service" => "API Worker",
    "worker_hostname" => $hostname,
    "worker_ip" => $server_ip,
    "proxy_ip" => $proxy_ip,
    "client_ip" => $client_ip,
    "database_status" => "Terkoneksi",
    "total_cluster_requests" => 0
];

$conn = @new mysqli($db_host, $db_user, $db_pass, $db_name);

if ($conn->connect_error) {
    $response["database_status"] = "Gagal: " . $conn->connect_error;
} else {
    $stmt = $conn->prepare("INSERT INTO request_logs (worker_name, client_ip, proxy_ip, user_agent) VALUES (?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("ssss", $hostname, $client_ip, $proxy_ip, $user_agent);
        $stmt->execute();
        $stmt->close();
    }

    $res = $conn->query("SELECT COUNT(*) AS total FROM request_logs");
    if ($res) {
        $row = $res->fetch_assoc();
        $response["total_cluster_requests"] = (int) $row['total'];
    }
    $conn->close();
}

echo json_encode($response, JSON_PRETTY_PRINT);
?>
PHP

service php8.4-fpm restart
nginx -t && service nginx restart

# Testing k-43

### Soal 1: Routing, Gateway & NAT
* **Di mana dijalankan:** Terminal `jichi` dan klien `kusakabe`
* **Perintah:**
  ```bash
  # [Di jichi]
  cat /proc/sys/net/ipv4/ip_forward
  iptables -t nat -L -n -v | grep MASQUERADE
  ip route

  # [Di kusakabe]
  ping -c 2 10.85.3.1
  ping -c 2 8.8.8.8
  ping -c 2 google.com
  ```
* **Ekspektasi Output:** `ip_forward` bernilai `1`, terdapat rule MASQUERADE pada `eth0`, ping gateway dan `google.com` 0% packet loss.

---

### Soal 2: DHCP Server Scope di Tengen
* **Di mana dijalankan:** Terminal `tengen`
* **Perintah:**
  ```bash
  # [Di tengen]
  service isc-dhcp-server status
  cat /etc/default/isc-dhcp-server | grep INTERFACES
  grep -A 2 "subnet 10.85.4.0" /etc/dhcp/dhcpd.conf
  grep -A 10 "subnet 10.85.2.0" /etc/dhcp/dhcpd.conf
  grep -A 10 "subnet 10.85.3.0" /etc/dhcp/dhcpd.conf
  ```
* **Ekspektasi Output:** Service `dhcpd is running`, `INTERFACESv4="eth0"`, subnet `10.85.4.0` dideklarasikan kosong tanpa pool dinamis (mencegah error *No subnet declaration*).

---

### Soal 3: DHCP Relay di Jichi
* **Di mana dijalankan:** Terminal `jichi` dan klien `itadori`
* **Perintah:**
  ```bash
  # [Di jichi]
  service isc-dhcp-relay status || ps aux | grep dhcrelay
  cat /etc/default/isc-dhcp-relay

  # [Di itadori]
  udhcpc -i eth0 -n -q
  ip a show eth0
  ```
* **Ekspektasi Output:** `SERVERS="10.85.4.10"`, `INTERFACES="eth4 eth2 eth3"`. Klien di Network 2 berhasil memperoleh IP lease melalui relay.

---

### Soal 4: DHCP Classes di Network 2 (Divisi A)
* **Di mana dijalankan:** Terminal klien `itadori`, `fushiguro`, `zenin`, `okkotsu`
* **Perintah:**
  ```bash
  ip a show eth0 | grep inet
  ```
* **Ekspektasi Output:**
  - `itadori` & `fushiguro` berada di **10.85.2.10 – 10.85.2.35** (Pool 1).
  - `zenin` & `okkotsu` berada di **10.85.2.70 – 10.85.2.95** (Pool 2).
  - Rentang `10.85.2.36 – 10.85.2.69` kosong tidak teralokasi.

---

### Soal 5: Short Lease & Long Lease di Network 3 (Divisi B)
* **Di mana dijalankan:** Terminal `tengen` dan klien `ino`, `kusakabe`, `miwa`
* **Perintah:**
  ```bash
  # [Di tengen]
  grep -E "lease 10.85.3.|starts|ends" /var/lib/dhcp/dhcpd.leases | tail -n 12

  # [Di ino / kusakabe / miwa]
  ip a show eth0 | grep inet
  cat /etc/resolv.conf
  ```
* **Ekspektasi Output:**
  - `ino` dan `kusakabe`: IP `10.85.3.10–89`, selisih masa berlaku = 1800 detik (30 menit).
  - `miwa`: IP `10.85.3.100–199`, selisih masa berlaku = 43200 detik (12 jam).
  - Resolv.conf berisi DNS `10.85.1.2`, `10.85.1.3`, dan search `k-43.com`.

---

### Soal 6: Fixed Address VIP Kugisaki
* **Di mana dijalankan:** Terminal `tengen` dan `kugisaki`
* **Perintah:**
  ```bash
  # [Di tengen]
  grep -A 4 "host kugisaki" /etc/dhcp/dhcpd.conf

  # [Di kugisaki]
  udhcpc -i eth0 -n -q
  ip a show eth0 | grep inet
  ```
* **Ekspektasi Output:** `kugisaki` selalu mendapatkan IP fixed `10.85.3.99`.

---

### Soal 7: Validasi Konfigurasi Jaringan Klien
* **Di mana dijalankan:** Terminal salah satu klien (`kusakabe` / `itadori`) dan `tengen`
* **Perintah:**
  ```bash
  # [Di klien]
  ip a show eth0
  ip route show default
  cat /etc/resolv.conf

  # [Di tengen]
  cat /var/lib/dhcp/dhcpd.leases
  ```
* **Ekspektasi Output:** Netmask `/24`, broadcast `10.85.x.255`, gateway `10.85.x.1`, seluruh lease cocok dengan file leases di `tengen`.

---

### Soal 8: Packet Capture DORA Sequence
* **Di mana dijalankan:** Terminal `tengen` dan klien `itadori`
* **Perintah:**
  ```bash
  # [Di tengen]
  tcpdump -i eth0 -n -vvv "port 67 or port 68"

  # [Di itadori (terminal terpisah)]
  udhcpc -i eth0 -n -q
  ```
* **Ekspektasi Output:** Terlihat urutan 4 paket: `DHCPDISCOVER` → `DHCPOFFER` → `DHCPREQUEST` → `DHCPACK`, dengan nilai `giaddr = 10.85.2.1` (interface relay `jichi`).

---

### Soal 9: Simulasi Gangguan Relay Jichi
* **Di mana dijalankan:** Terminal `jichi` dan klien `itadori`
* **Perintah:**
  ```bash
  # 1. [Di jichi] Hentikan Relay
  service isc-dhcp-relay stop || killall dhcrelay

  # 2. [Di itadori] Renew IP (akan gagal / timeout)
  udhcpc -i eth0 -n -q -T 3

  # 3. [Di jichi] Nyalakan Relay kembali
  service isc-dhcp-relay start

  # 4. [Di itadori] Renew IP
  udhcpc -i eth0 -n -q
  ip a show eth0 | grep inet
  ```
* **Ekspektasi Output:** Saat relay mati, `udhcpc` gagal. Setelah relay hidup kembali, klien memperoleh kembali IP dari pool yang benar.

---

### Soal 10: Persistensi Autostart Setelah Reboot
* **Di mana dijalankan:** Terminal `tengen` dan `jichi`
* **Perintah:**
  ```bash
  tail -n 5 /root/.bashrc
  ```
* **Ekspektasi Output:** Terdapat baris `bash tengen.sh` di `tengen` dan `bash jichi.sh` di `jichi` yang menjamin service menyala kembali secara otomatis.

---

### Soal 11: DNS Master (Utahime) & Slave (Shoko)
* **Di mana dijalankan:** Terminal klien (misal: `kusakabe`) dan `utahime`
* **Perintah:**
  ```bash
  # [Di klien]
  dig @10.85.1.2 jujutsu.k-43.com +short
  dig @10.85.1.3 jujutsu.k-43.com +short

  # [Di utahime] Uji zone transfer dengan menaikkan serial SOA
  nano /etc/bind/jarkom/k-43.com
  rndc reload
  ```
* **Ekspektasi Output:** Kedua server DNS menjawab dengan IP `10.85.1.4`. `shoko` otomatis mensinkronkan file zona dari Master.

---

### Soal 12: A Record, CNAME, PTR & DNS Forwarder
* **Di mana dijalankan:** Terminal klien `kusakabe`
* **Perintah:**
  ```bash
  # 1. A Record & CNAME
  dig @10.85.1.2 jujutsu.k-43.com +short
  dig @10.85.1.2 www.k-43.com +short

  # 2. Reverse DNS (PTR)
  dig @10.85.1.2 -x 10.85.1.4 +short

  # 3. DNS Forwarder
  dig @10.85.1.2 google.com +short
  ping -c 2 google.com
  ```
* **Ekspektasi Output:** A record & CNAME mengarah ke `10.85.1.4`, PTR mengembalikan `gojo.k-43.com.`, forwarder meneruskan resolusi dan ping internet berhasil.

---

### Soal 13: Replikasi MariaDB Master (Yaga) & Slave (Inumaki)
* **Di mana dijalankan:** Terminal `yaga` dan `inumaki`
* **Perintah:**
  ```bash
  # 1. [Di yaga]
  mariadb -u root -e "SHOW MASTER STATUS\G"

  # 2. [Di inumaki]
  mariadb -u root -e "SHOW SLAVE STATUS\G"

  # 3. [Di yaga] Insert baris data baru
  mariadb -u root -e "USE db_shibuya_k43; INSERT INTO request_logs (worker_name, client_ip, proxy_ip, user_agent) VALUES ('test-audit', '10.85.2.10', '10.85.1.4', 'Testing Replication');"

  # 4. [Di inumaki] Cek replikasi data
  mariadb -u root -e "USE db_shibuya_k43; SELECT * FROM request_logs WHERE worker_name='test-audit';"
  ```
* **Ekspektasi Output:** `Slave_IO_Running: Yes`, `Slave_SQL_Running: Yes`. Data yang diinsert pada `yaga` muncul di `inumaki`.

---

### Soal 14: Restriksi Akses Worker Web & API
* **Di mana dijalankan:** Terminal klien `kusakabe` dan `gojo`
* **Perintah:**
  ```bash
  # 1. [Di klien] Akses langsung (harus 403 Forbidden)
  curl -I http://10.85.4.5/
  curl -I http://10.85.4.7/

  # 2. [Di gojo] Akses legal via Reverse Proxy (harus diizinkan)
  curl -I http://10.85.4.5/
  ```
* **Ekspektasi Output:** Akses langsung dari klien ditolak (`403 Forbidden`), sedangkan akses dari proxy diizinkan.

---

### Soal 15: Weighted Round Robin (3:1) di Geto
* **Di mana dijalankan:** Terminal node internal Data Center (misal: `maki` atau `tengen`)
* **Perintah:**
  ```bash
  # Jalankan loop 12 kali request langsung ke Geto
  for i in {1..12}; do curl -s http://10.85.4.4/ | grep "worker_hostname"; done
  ```
* **Ekspektasi Output:** Hostname `nanami` muncul sebanyak **9 kali** dan `todo` muncul sebanyak **3 kali** (rasio beban 3:1).

---

### Soal 16: Path-Based Routing di Gojo
* **Di mana dijalankan:** Terminal klien `kusakabe`
* **Perintah:**
  ```bash
  # 1. Akses Root (/) -> diteruskan ke Maki atau Panda
  curl -s http://jujutsu.k-43.com/ | grep -i "Worker Hostname"

  # 2. Akses Path (/api/) -> diteruskan ke Geto (Nanami / Todo)
  curl -s http://jujutsu.k-43.com/api/
  ```
* **Ekspektasi Output:** Request root dialihkan ke web worker (`maki` / `panda`), dan request path `/api/` dialihkan ke API worker (`nanami` / `todo`).

---

### Soal 17: Validasi Header X-Real-IP & Log Database
* **Di mana dijalankan:** Terminal klien `kusakabe` (10.85.3.10) dan terminal `yaga`
* **Perintah:**
  ```bash
  # 1. [Di kusakabe] Kirim request ke endpoint API
  curl -s http://jujutsu.k-43.com/api/

  # 2. [Di yaga] Periksa pencatatan IP asli di database
  mariadb -u root -e "USE db_shibuya_k43; SELECT id, worker_name, client_ip, proxy_ip, created_at FROM request_logs ORDER BY id DESC LIMIT 5;"
  ```
* **Ekspektasi Output:** Kolom `client_ip` mencatat alamat asli klien `10.85.3.10` (bukan IP Gojo `10.85.1.4` atau Geto `10.85.4.4`).

---

### Soal 18: Simulasi Failover & Backup Worker Kirara
* **Di mana dijalankan:** Terminal `nanami`, `todo`, dan klien `kusakabe`
* **Perintah:**
  ```bash
  # 1. [Di nanami & todo] Hentikan layanan Nginx
  service nginx stop

  # 2. [Di klien] Kirim request ke endpoint API
  curl -s http://jujutsu.k-43.com/api/ | grep "worker_hostname"
  ```
* **Ekspektasi Output:** Request tidak menghasilkan `502 Bad Gateway`, melainkan langsung dialihkan ke server backup `kirara` (`"worker_hostname": "kirara"`).

---

### Soal 19: Nginx Proxy Caching & Rate Limiting di Gojo
* **Di mana dijalankan:** Terminal klien `kusakabe`
* **Perintah:**
  ```bash
  # 1. Uji Proxy Caching (Akses Root)
  curl -I http://jujutsu.k-43.com/ | grep -i "x-cache-status"
  curl -I http://jujutsu.k-43.com/ | grep -i "x-cache-status"

  # 2. Uji Rate Limiting (Kirim burst request ke /api/)
  for i in {1..15}; do curl -s -o /dev/null -w "%{http_code} " http://jujutsu.k-43.com/api/; done; echo
  ```
* **Ekspektasi Output:**
  - Cache menampilkan `X-Cache-Status: MISS` pada akses awal dan `HIT` pada akses berulang.
  - Rate limiting menghasilkan deretan kode respons yang berubah menjadi **`503`** ketika request melampaui 10 req/detik.

### Soal 20: Audit Kapasitas Layanan & Benchmark (Apache Benchmark)
* **Di mana dijalankan:** Terminal klien `kusakabe` dan node `gojo`
* **Perintah:**
  ```bash
  # 1. [Di kusakabe] Install Apache Benchmark (jika belum terpasang di Alpine)
  apk update && apk add apache2-utils

  # 2. [Di kusakabe] Benchmark Web Frontend (Baseline & Cache)
  ab -n 600 -c 30 http://jujutsu.k-43.com/

  # 3. [Di kusakabe] Benchmark Endpoint /api/ (Efek Rate Limiting)
  ab -n 600 -c 30 http://jujutsu.k-43.com/api/

  # 4. [Di gojo] Analisis Access Log & Error Log untuk identifikasi penolakan Rate Limit
  awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c
  tail -n 30 /var/log/nginx/error.log | grep "limiting requests"
  ```
* **Ekspektasi Output & Analisis:**
  - **Pada Web Frontend (`/`)**: RPS tinggi, latensi rendah, `Failed requests: 0` (karena dilayani langsung oleh cache Nginx Gojo tanpa membebani backend).
  - **Pada API (`/api/`)**: Muncul sejumlah besar `Failed requests: ... (Connect: 0, Receive: 0, Length: 0, Exceptions: 0)` dan `Non-2xx responses: ~590` (berstatus HTTP 503) akibat pemblokiran oleh `limit_req`.
  - **Pada Log `gojo`**: `awk` menunjukkan dominasi status `503`, dan `error.log` mencatat baris peringatan `limiting requests, excess: ... by zone "limit_api"`.

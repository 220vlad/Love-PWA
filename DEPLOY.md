# Инструкция по установке и публикации Love PWA на сервере

## Требования к серверу

- PHP >= 8.1
- Composer
- Node.js >= 18 и npm
- База данных: MySQL/MariaDB или PostgreSQL (рекомендуется для продакшена)
- Веб-сервер: Nginx или Apache
- SSL сертификат (обязательно для PWA)

## Вариант 1: Деплой на Linux VPS (Ubuntu/Debian)

### Шаг 1: Подготовка сервера

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка необходимых пакетов
sudo apt install -y php8.1 php8.1-fpm php8.1-mysql php8.1-mbstring php8.1-xml php8.1-curl php8.1-zip php8.1-gd
sudo apt install -y nginx mysql-server composer nodejs npm git

# Установка Node.js через nvm (рекомендуется)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 18
nvm use 18
```

### Шаг 2: Клонирование проекта

```bash
cd /var/www
sudo git clone https://github.com/220vlad/Love-PWA.git love-pwa
cd love-pwa
sudo chown -R www-data:www-data /var/www/love-pwa
```

### Шаг 3: Установка зависимостей

```bash
# PHP зависимости
composer install --optimize-autoloader --no-dev

# JavaScript зависимости
npm install
```

### Шаг 4: Настройка окружения

```bash
# Создание .env файла
cp .env.example .env

# Генерация ключа приложения
php artisan key:generate

# Редактирование .env (используйте nano или vim)
nano .env
```

Настройте `.env` файл:

```env
APP_NAME="Love PWA"
APP_ENV=production
APP_DEBUG=false
APP_URL=https://yourdomain.com

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=love_pwa
DB_USERNAME=your_db_user
DB_PASSWORD=your_db_password

# Настройки для продакшена
CACHE_DRIVER=file
SESSION_DRIVER=database
QUEUE_CONNECTION=database

# Telegram (опционально)
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_BOT_USERNAME=your_bot_username

SANCTUM_STATEFUL_DOMAINS=yourdomain.com,www.yourdomain.com
SESSION_DOMAIN=.yourdomain.com
```

### Шаг 5: Настройка базы данных

```bash
# Создание базы данных MySQL
sudo mysql -u root -p
```

В MySQL консоли:

```sql
CREATE DATABASE love_pwa CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'love_user'@'localhost' IDENTIFIED BY 'strong_password_here';
GRANT ALL PRIVILEGES ON love_pwa.* TO 'love_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

Запуск миграций:

```bash
php artisan migrate --force
php artisan storage:link
```

### Шаг 6: Сборка фронтенда

```bash
npm run build
```

### Шаг 7: Оптимизация Laravel

```bash
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan optimize
```

### Шаг 8: Настройка Nginx

Создайте конфигурационный файл:

```bash
sudo nano /etc/nginx/sites-available/love-pwa
```

Содержимое:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name yourdomain.com www.yourdomain.com;
    
    # Редирект на HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;
    
    root /var/www/love-pwa/public;
    index index.php index.html;

    # SSL сертификаты (используйте Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # Безопасность
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";

    # PWA поддержка
    add_header Service-Worker-Allowed /;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    # Кэширование статики
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

Активируйте сайт:

```bash
sudo ln -s /etc/nginx/sites-available/love-pwa /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Шаг 9: Установка SSL сертификата (Let's Encrypt)

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

### Шаг 10: Настройка прав доступа

```bash
cd /var/www/love-pwa
sudo chown -R www-data:www-data storage bootstrap/cache
sudo chmod -R 775 storage bootstrap/cache
```

### Шаг 11: Настройка Supervisor (для очередей, опционально)

```bash
sudo apt install supervisor
sudo nano /etc/supervisor/conf.d/love-pwa-worker.conf
```

Содержимое:

```ini
[program:love-pwa-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/love-pwa/artisan queue:work --sleep=3 --tries=3
autostart=true
autorestart=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=/var/www/love-pwa/storage/logs/worker.log
```

Запуск:

```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start love-pwa-worker:*
```

## Вариант 2: Деплой на хостинг с панелью управления (cPanel, Plesk)

### Шаг 1: Загрузка файлов

1. Создайте ZIP архив проекта (исключите `node_modules`, `.git`, `.env`)
2. Загрузите через File Manager или FTP
3. Распакуйте архив в корневую директорию сайта

### Шаг 2: Установка через SSH

```bash
cd ~/public_html  # или ваш путь к сайту
composer install --no-dev --optimize-autoloader
npm install
npm run build
```

### Шаг 3: Настройка .env

Создайте `.env` файл через панель управления или SSH.

### Шаг 4: Запуск миграций

```bash
php artisan migrate --force
php artisan storage:link
php artisan optimize
```

### Шаг 5: Настройка прав доступа

```bash
chmod -R 755 storage bootstrap/cache
chown -R your_user:your_group storage bootstrap/cache
```

## Вариант 3: Docker деплой

Создайте `Dockerfile`:

```dockerfile
FROM php:8.1-fpm

RUN apt-get update && apt-get install -y \
    git curl libpng-dev libonig-dev libxml2-dev zip unzip \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

WORKDIR /var/www

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
COPY . .

RUN composer install --optimize-autoloader --no-dev
RUN npm install && npm run build

RUN chown -R www-data:www-data /var/www
RUN chmod -R 775 /var/www/storage

EXPOSE 9000
CMD ["php-fpm"]
```

`docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    build: .
    volumes:
      - .:/var/www
    networks:
      - love-pwa

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - .:/var/www
      - ./docker/nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - app
    networks:
      - love-pwa

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: love_pwa
      MYSQL_USER: love_user
      MYSQL_PASSWORD: strong_password
      MYSQL_ROOT_PASSWORD: root_password
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - love-pwa

networks:
  love-pwa:
    driver: bridge

volumes:
  mysql_data:
```

Запуск:

```bash
docker-compose up -d
docker-compose exec app php artisan migrate
docker-compose exec app php artisan storage:link
```

## Проверка после установки

1. Проверьте доступность сайта: `https://yourdomain.com`
2. Проверьте регистрацию нового пользователя
3. Проверьте установку PWA: откройте DevTools > Application > Manifest
4. Проверьте Service Worker: DevTools > Application > Service Workers

## Обновление приложения

```bash
cd /var/www/love-pwa
git pull origin main
composer install --no-dev --optimize-autoloader
npm install
npm run build
php artisan migrate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan optimize
```

## Мониторинг и логи

```bash
# Laravel логи
tail -f /var/www/love-pwa/storage/logs/laravel.log

# Nginx логи
tail -f /var/log/nginx/error.log
tail -f /var/log/nginx/access.log

# PHP-FPM логи
tail -f /var/log/php8.1-fpm.log
```

## Резервное копирование

Создайте скрипт для бэкапа:

```bash
#!/bin/bash
BACKUP_DIR="/backups/love-pwa"
DATE=$(date +%Y%m%d_%H%M%S)

# Бэкап базы данных
mysqldump -u love_user -p love_pwa > $BACKUP_DIR/db_$DATE.sql

# Бэкап файлов
tar -czf $BACKUP_DIR/files_$DATE.tar.gz /var/www/love-pwa

# Удаление старых бэкапов (старше 7 дней)
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
```

Добавьте в crontab:

```bash
0 2 * * * /path/to/backup-script.sh
```

## Безопасность

1. Убедитесь, что `.env` файл не доступен публично
2. Используйте сильные пароли для базы данных
3. Включите firewall: `sudo ufw enable`
4. Регулярно обновляйте зависимости: `composer update` и `npm update`
5. Настройте мониторинг ошибок (Sentry, Bugsnag)

## Поддержка

При возникновении проблем проверьте:
- Логи Laravel в `storage/logs/laravel.log`
- Права доступа к `storage` и `bootstrap/cache`
- Конфигурацию базы данных в `.env`
- Настройки Nginx/Apache
- SSL сертификат для HTTPS


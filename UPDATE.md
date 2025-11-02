# Обновление проекта без простоя (Hot Update)

## Вариант 1: Обновление в режиме разработки (Hot Reload)

При локальной разработке Vite автоматически обновляет страницу при изменении кода:

```bash
# Терминал 1: Laravel сервер
php artisan serve

# Терминал 2: Vite dev server (автоматическое обновление)
npm run dev
```

При изменении файлов в `resources/js` или `resources/css` страница обновится автоматически без перезагрузки.

## Вариант 2: Обновление на продакшен сервере (Zero Downtime)

### Автоматический скрипт обновления

Создайте файл `deploy.sh` для автоматического обновления:

```bash
#!/bin/bash
# deploy.sh - Скрипт для обновления без простоя

set -e  # Остановка при ошибках

echo "🚀 Начало обновления..."

# Переменные
PROJECT_PATH="/var/www/love-pwa"
BACKUP_DIR="/backups/love-pwa"
DATE=$(date +%Y%m%d_%H%M%S)

# 1. Создание бэкапа
echo "📦 Создание бэкапа..."
mkdir -p $BACKUP_DIR
mysqldump -u love_user -p$(grep DB_PASSWORD $PROJECT_PATH/.env | cut -d '=' -f2) \
    $(grep DB_DATABASE $PROJECT_PATH/.env | cut -d '=' -f2) > $BACKUP_DIR/db_$DATE.sql
tar -czf $BACKUP_DIR/files_$DATE.tar.gz $PROJECT_PATH --exclude=node_modules --exclude=.git

# 2. Переход в директорию проекта
cd $PROJECT_PATH

# 3. Сохранение режима обслуживания (опционально)
# php artisan down --render="errors::503" --secret="secret-token-here"

# 4. Получение последних изменений
echo "📥 Получение обновлений..."
git fetch origin
git stash  # Сохранение локальных изменений
git pull origin main

# 5. Обновление зависимостей
echo "📦 Обновление зависимостей..."
composer install --no-dev --optimize-autoloader --no-interaction
npm install --production
npm run build

# 6. Запуск миграций (если есть новые)
echo "🗄️  Проверка миграций..."
php artisan migrate --force

# 7. Очистка и оптимизация кэша
echo "🧹 Очистка кэша..."
php artisan config:clear
php artisan route:clear
php artisan view:clear
php artisan cache:clear

# 8. Пересборка кэша
echo "⚡ Оптимизация..."
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan optimize

# 9. Перезапуск очередей (если используются)
echo "🔄 Перезапуск workers..."
sudo supervisorctl restart love-pwa-worker:*

# 10. Отключение режима обслуживания
# php artisan up

echo "✅ Обновление завершено успешно!"
echo "🔍 Проверьте логи: tail -f storage/logs/laravel.log"
```

Сделайте скрипт исполняемым:

```bash
chmod +x deploy.sh
```

Запуск обновления:

```bash
./deploy.sh
```

### Ручное обновление (пошагово)

Если предпочитаете обновлять вручную:

```bash
cd /var/www/love-pwa

# 1. Получить обновления
git pull origin main

# 2. Обновить зависимости
composer install --no-dev --optimize-autoloader
npm install
npm run build

# 3. Применить миграции (если есть)
php artisan migrate --force

# 4. Очистить кэш
php artisan optimize:clear

# 5. Пересобрать кэш
php artisan optimize
```

## Вариант 3: CI/CD автоматическое обновление

### Использование GitHub Actions

Создайте `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Production

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to server
      uses: appleboy/ssh-action@master
      with:
        host: ${{ secrets.HOST }}
        username: ${{ secrets.USERNAME }}
        key: ${{ secrets.SSH_KEY }}
        script: |
          cd /var/www/love-pwa
          git pull origin main
          composer install --no-dev --optimize-autoloader
          npm install
          npm run build
          php artisan migrate --force
          php artisan optimize
          sudo supervisorctl restart love-pwa-worker:*
```

### Использование GitLab CI

Файл `.gitlab-ci.yml` уже создан (см. выше в проекте).

## Вариант 4: Использование Laravel Horizon/Supervisor

Для полного нулевого простоя используйте очереди:

```bash
# Установите Laravel Horizon (опционально)
composer require laravel/horizon

# Настройте Supervisor (уже есть в DEPLOY.md)
sudo supervisorctl restart love-pwa-worker:*
```

## Вариант 5: Blue-Green Deployment

Для максимальной отказоустойчивости:

1. Подготовьте два окружения (blue и green)
2. Обновляйте неактивное окружение
3. Переключайте трафик через Nginx/load balancer
4. Обновляйте активное окружение

Пример скрипта `blue-green-deploy.sh`:

```bash
#!/bin/bash

CURRENT_ENV=$(nginx -T 2>/dev/null | grep -o 'root /var/www/love-pwa-.*/public' | head -1)
if [[ $CURRENT_ENV == *"blue"* ]]; then
    NEW_ENV="green"
    OLD_ENV="blue"
else
    NEW_ENV="blue"
    OLD_ENV="green"
fi

echo "Обновление окружения $NEW_ENV..."

# Обновление нового окружения
cd /var/www/love-pwa-$NEW_ENV
git pull origin main
composer install --no-dev --optimize-autoloader
npm install && npm run build
php artisan migrate --force
php artisan optimize

# Переключение трафика
sudo sed -i "s/love-pwa-$OLD_ENV/love-pwa-$NEW_ENV/g" /etc/nginx/sites-available/love-pwa
sudo nginx -t && sudo systemctl reload nginx

echo "Переключено на окружение $NEW_ENV"
```

## Проверка обновления

После обновления проверьте:

```bash
# 1. Проверка версии (добавьте версию в .env)
php artisan about

# 2. Проверка миграций
php artisan migrate:status

# 3. Проверка роутов
php artisan route:list

# 4. Проверка логов
tail -f storage/logs/laravel.log

# 5. Проверка работы API
curl https://yourdomain.com/api/me
```

## Откат изменений (Rollback)

Если что-то пошло не так:

```bash
cd /var/www/love-pwa

# 1. Откат к предыдущему коммиту
git log --oneline -10  # Посмотрите историю
git reset --hard HEAD~1  # Откат на один коммит назад

# 2. Восстановление базы данных из бэкапа
mysql -u love_user -p love_pwa < /backups/love-pwa/db_YYYYMMDD_HHMMSS.sql

# 3. Восстановление файлов (если нужно)
tar -xzf /backups/love-pwa/files_YYYYMMDD_HHMMSS.tar.gz -C /

# 4. Пересборка и очистка кэша
composer install --no-dev --optimize-autoloader
npm run build
php artisan optimize:clear
php artisan optimize

# 5. Перезапуск workers
sudo supervisorctl restart love-pwa-worker:*
```

## Автоматический откат при ошибках

Добавьте в `deploy.sh` проверки:

```bash
# Проверка после обновления
if ! php artisan migrate:status > /dev/null 2>&1; then
    echo "❌ Ошибка миграций! Откат..."
    git reset --hard HEAD~1
    exit 1
fi

# Проверка работы приложения
if ! curl -f http://localhost > /dev/null 2>&1; then
    echo "❌ Приложение не отвечает! Откат..."
    git reset --hard HEAD~1
    php artisan optimize
    exit 1
fi
```

## Рекомендации

1. **Всегда делайте бэкап перед обновлением**
2. **Тестируйте на staging окружении сначала**
3. **Используйте feature flags для постепенного внедрения**
4. **Мониторьте логи во время обновления**
5. **Имейте план отката**

## Уведомления об обновлениях

Добавьте уведомления в Slack/Telegram:

```bash
# В конце deploy.sh
curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -d '{"text":"✅ Love PWA обновлен успешно!"}'
```

## Мониторинг обновлений

```bash
# Отслеживание в реальном времени
watch -n 1 'php artisan about && echo "---" && git log --oneline -5'
```


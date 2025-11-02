#!/bin/bash
# Автоматический скрипт обновления без простоя

set -e  # Остановка при ошибках

echo "🚀 Начало обновления Love PWA..."

# Переменные (настройте под свой сервер)
PROJECT_PATH="${PROJECT_PATH:-/var/www/love-pwa}"
BACKUP_DIR="${BACKUP_DIR:-/backups/love-pwa}"
BRANCH="${BRANCH:-main}"

# Получаем путь проекта из текущей директории или переменной
if [ -f "composer.json" ]; then
    PROJECT_PATH=$(pwd)
fi

cd "$PROJECT_PATH"
DATE=$(date +%Y%m%d_%H%M%S)

# Функция отката
rollback() {
    echo "❌ Ошибка! Выполняется откат..."
    git reset --hard HEAD@{1} 2>/dev/null || git reset --hard HEAD~1
    php artisan optimize:clear 2>/dev/null || true
    php artisan optimize 2>/dev/null || true
    echo "⚠️  Откат выполнен. Проверьте состояние приложения."
    exit 1
}

# Устанавливаем обработчик ошибок
trap rollback ERR

# 1. Создание бэкапа (если есть MySQL)
if [ -f ".env" ] && grep -q "DB_CONNECTION=mysql" .env 2>/dev/null; then
    echo "📦 Создание бэкапа базы данных..."
    mkdir -p "$BACKUP_DIR"
    
    DB_NAME=$(grep DB_DATABASE .env | cut -d '=' -f2 | tr -d ' ')
    DB_USER=$(grep DB_USERNAME .env | cut -d '=' -f2 | tr -d ' ')
    DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2 | tr -d ' ')
    
    if [ ! -z "$DB_NAME" ] && [ ! -z "$DB_USER" ]; then
        mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$BACKUP_DIR/db_$DATE.sql" 2>/dev/null || {
            echo "⚠️  Не удалось создать бэкап БД (пропускаем)"
        }
    fi
fi

# 2. Сохранение текущего состояния
echo "💾 Сохранение текущего состояния..."
git stash push -m "Auto-stash before deploy $DATE" 2>/dev/null || true

# 3. Получение обновлений
echo "📥 Получение обновлений из Git..."
git fetch origin
CURRENT_COMMIT=$(git rev-parse HEAD)
git pull origin "$BRANCH" || {
    echo "❌ Ошибка при получении обновлений"
    git stash pop 2>/dev/null || true
    exit 1
}

# Проверка на новые изменения
if [ "$CURRENT_COMMIT" = "$(git rev-parse HEAD)" ]; then
    echo "ℹ️  Нет новых изменений"
    git stash pop 2>/dev/null || true
    exit 0
fi

# 4. Обновление зависимостей
echo "📦 Обновление PHP зависимостей..."
composer install --no-dev --optimize-autoloader --no-interaction || {
    echo "❌ Ошибка обновления Composer зависимостей"
    exit 1
}

echo "📦 Обновление NPM зависимостей..."
npm install --production || {
    echo "❌ Ошибка обновления NPM зависимостей"
    exit 1
}

# 5. Сборка фронтенда
echo "🏗️  Сборка фронтенда..."
npm run build || {
    echo "❌ Ошибка сборки фронтенда"
    exit 1
}

# 6. Проверка и применение миграций
echo "🗄️  Проверка миграций..."
if php artisan migrate:status > /dev/null 2>&1; then
    php artisan migrate --force || {
        echo "❌ Ошибка миграций"
        exit 1
    }
else
    echo "⚠️  Пропуск миграций (база данных недоступна?)"
fi

# 7. Очистка кэша
echo "🧹 Очистка кэша..."
php artisan config:clear 2>/dev/null || true
php artisan route:clear 2>/dev/null || true
php artisan view:clear 2>/dev/null || true
php artisan cache:clear 2>/dev/null || true

# 8. Оптимизация
echo "⚡ Оптимизация приложения..."
php artisan config:cache || {
    echo "⚠️  Ошибка кэширования конфига (продолжаем)"
}
php artisan route:cache || {
    echo "⚠️  Ошибка кэширования роутов (продолжаем)"
}
php artisan view:cache || {
    echo "⚠️  Ошибка кэширования шаблонов (продолжаем)"
}
php artisan optimize || {
    echo "⚠️  Ошибка оптимизации (продолжаем)"
}

# 9. Перезапуск очередей (если настроены)
if systemctl is-active --quiet supervisor 2>/dev/null; then
    echo "🔄 Перезапуск workers..."
    sudo supervisorctl restart love-pwa-worker:* 2>/dev/null || {
        echo "⚠️  Workers не перезапущены (может быть не настроены)"
    }
fi

# 10. Проверка работоспособности
echo "🔍 Проверка работоспособности..."
if php artisan about > /dev/null 2>&1; then
    echo "✅ Приложение работает"
else
    echo "⚠️  Не удалось проверить состояние приложения"
fi

# 11. Очистка старых бэкапов (старше 7 дней)
if [ -d "$BACKUP_DIR" ]; then
    echo "🗑️  Очистка старых бэкапов..."
    find "$BACKUP_DIR" -name "*.sql" -mtime +7 -delete 2>/dev/null || true
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete 2>/dev/null || true
fi

echo ""
echo "✅ Обновление завершено успешно!"
echo "📝 Логи: tail -f $PROJECT_PATH/storage/logs/laravel.log"
echo "🌐 Проверьте работу: curl -I https://yourdomain.com"

# Удаляем обработчик ошибок
trap - ERR


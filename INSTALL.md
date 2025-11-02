# Инструкция по установке Love PWA

## Шаг 1: Установка зависимостей

```bash
# Установка PHP зависимостей
composer install

# Установка JavaScript зависимостей
npm install
```

## Шаг 2: Настройка окружения

```bash
# Скопируйте файл .env.example в .env
cp .env.example .env

# Сгенерируйте ключ приложения
php artisan key:generate
```

## Шаг 3: Настройка базы данных

```bash
# Создайте файл базы данных SQLite
touch database/database.sqlite

# Запустите миграции
php artisan migrate
```

## Шаг 4: Настройка хранилища

```bash
# Создайте символическую ссылку для публичного хранилища
php artisan storage:link
```

## Шаг 5: Создание иконок PWA

Иконки должны быть размещены в `public/icons/`:
- icon-72x72.png
- icon-96x96.png
- icon-128x128.png
- icon-144x144.png
- icon-152x152.png
- icon-192x192.png
- icon-384x384.png
- icon-512x512.png

Вы можете:
1. Использовать инструмент `scripts/generate-icons.html` для создания иконок из одного изображения
2. Или создать иконки вручную в любом редакторе изображений

Рекомендуется создать иконку 512x512 с красным сердцем или символом любви на белом/розовом фоне.

## Шаг 6: Запуск приложения

### Вариант 1: Разработка

```bash
# В первом терминале - Laravel сервер
php artisan serve

# Во втором терминале - Vite dev server
npm run dev
```

Приложение будет доступно на `http://localhost:8000`

### Вариант 2: Продакшн

```bash
# Соберите фронтенд
npm run build

# Запустите Laravel
php artisan serve
```

## Шаг 7: Настройка Telegram (опционально)

1. Создайте бота через [@BotFather](https://t.me/BotFather)
2. Получите токен бота
3. Добавьте в `.env`:
   ```
   TELEGRAM_BOT_TOKEN=your_bot_token_here
   TELEGRAM_BOT_USERNAME=your_bot_username
   ```

## Проверка работы

1. Откройте `http://localhost:8000`
2. Зарегистрируйтесь или войдите
3. Заполните профиль
4. Начните искать других пользователей

## Возможные проблемы

### Ошибка "Class not found"
Запустите: `composer dump-autoload`

### Ошибка доступа к storage
Убедитесь, что выполнена команда `php artisan storage:link`

### PWA не устанавливается
Проверьте, что иконки созданы и доступны по путям из `manifest.json`


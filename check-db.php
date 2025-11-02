<?php

echo "Проверка подключения к базе данных...\n\n";

$host = '127.0.0.1';
$port = '3306';
$database = 'love-pwa';
$username = 'root';
$password = '9pg-rJW-g9L-5MP';

echo "Параметры подключения:\n";
echo "Host: $host\n";
echo "Port: $port\n";
echo "Database: $database\n";
echo "Username: $username\n\n";

// Попытка подключения
try {
    $dsn = "mysql:host=$host;port=$port;dbname=$database;charset=utf8mb4";
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    echo "✓ Подключение успешно!\n";
    
    // Проверка существования базы данных
    $stmt = $pdo->query("SELECT DATABASE() as db");
    $result = $stmt->fetch();
    echo "Текущая база данных: " . $result['db'] . "\n\n";
    
    echo "База данных готова к использованию!\n";
    exit(0);
    
} catch (PDOException $e) {
    echo "✗ Ошибка подключения: " . $e->getMessage() . "\n\n";
    
    if (strpos($e->getMessage(), '2002') !== false) {
        echo "Сервер MariaDB не запущен или недоступен.\n";
        echo "Действия:\n";
        echo "1. Запустите OSPanel (зеленая иконка)\n";
        echo "2. Убедитесь, что MariaDB запущен в меню OSPanel\n";
        echo "3. Проверьте, что порт 3306 не занят другим процессом\n";
    } elseif (strpos($e->getMessage(), '1045') !== false) {
        echo "Ошибка авторизации. Проверьте:\n";
        echo "1. Правильность пароля в .env файле\n";
        echo "2. Пользователь root имеет доступ к базе данных\n";
    } elseif (strpos($e->getMessage(), '1049') !== false) {
        echo "База данных не существует.\n";
        echo "Создайте базу данных через phpMyAdmin:\n";
        echo "CREATE DATABASE `love-pwa` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\n";
    }
    
    exit(1);
}


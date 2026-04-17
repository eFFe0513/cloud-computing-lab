<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LAMP Stack - Applicazione 1</title>
</head>
<body>
    <h1>Benvenuto - Applicazione PHP 1</h1>
    <p>Stack LAMP attivo e funzionante!</p>
    <?php
    echo "<p>PHP Version: " . phpversion() . "</p>";
    echo "<p>Server Time: " . date('Y-m-d H:i:s') . "</p>";
    
    // Test connessione database
    $db_host = getenv('DB_HOST');
    $db_user = getenv('DB_USERNAME');
    $db_pass = getenv('DB_PASSWORD');
    
    try {
        $pdo = new PDO("mysql:host=$db_host", $db_user, $db_pass);
        echo "<p style='color: green;'>✓ Database connesso correttamente</p>";
    } catch (PDOException $e) {
        echo "<p style='color: red;'>✗ Errore database: " . $e->getMessage() . "</p>";
    }
    ?>
</body>
</html>

<?php
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;
// Enable error reporting for debugging
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

$success = '';
$error = '';
// Include PHPMailer (make sure you have installed it via Composer or manually)

require __DIR__ . '/php/phpmailer/PHPMailer.php';
require __DIR__ . '/php/phpmailer/SMTP.php';
require __DIR__ . '/php/phpmailer/Exception.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $name = trim($_POST['name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $message = trim(
        "New enquiry via the website.\nThe email address for this contact is: " . $_POST['email'] .
        "\nThe message is as follows:\n" . ($_POST['message'] ?? '')
    );

    $phone = trim($_POST['phone'] ?? '');
    $isEmailValid = filter_var($email, FILTER_VALIDATE_EMAIL);
    $hasContact = ($isEmailValid || $phone);

    if ($name && $hasContact && $message) {
        $mail = new PHPMailer(true);
        try {
            // SMTP configuration
            $mail->isSMTP();
            $mail->Host = 'smtp.ionos.co.uk';
            $mail->SMTPAuth = true;
            $mail->Username = 'info@wallartbykatka.co.uk'; // Replace with your SMTP username
            // Load from a separate config file (not web-accessible)
            $mail->Password = require __DIR__ . '/php/config/smtp_password.php';
            $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
            $mail->Port = 587;

            // Email settings
            $mail->setFrom('info@wallartbykatka.co.uk', 'Website Contact Form - ' . $name);
            // $mail->setFrom($email, $name);
            $mail->addAddress('info@wallartbykatka.co.uk');
            $mail->Subject = 'Contact Form Submission';
            $mail->Body = $message . "\nPhone: " . $phone;

            $mail->send();
            // Redirect before any output
            header('Location: contactthanks.html');
            exit;
        } catch (Exception $e) {
            $error = 'Sorry, there was a problem sending your message. Please try again later.';
        }
    } else {
        $error = 'Please provide your name, a valid email or phone number, and a message.';
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Contact Form - wallartbykatka</title>
    <style>
        body { margin: 40px; }
        form { max-width: 400px; margin: auto; }
        label { display: block; margin-top: 15px; }
        input, textarea { width: 100%; padding: 8px; margin-top: 5px; }
        button { margin-top: 15px; padding: 10px 20px; }
        .success { color: green; }
        .error { color: red; }
    </style>
    <link rel="stylesheet" href="css/main.css">
</head>
<body>
    <nav class="menu-bar">
        <a href="/index.html">About</a>
        <a href="/wallart.html">Wall Art</a>
        <a href="/boardart.html">Board Art</a>
        <a href="/contact.php" class="active">Contact</a>
    </nav>
    <div class="banner">
        <span style="position: relative; z-index: 1; font-weight: bold; color: white; font-size: 0.7em;">Contact</span>
    </div>

    <?php if ($error): ?>
        <div class="error"><?php echo htmlspecialchars($error); ?></div>
    <?php endif; ?>

    <form method="post" action="">
        <label for="name">Name:</label>
        <input type="text" id="name" name="name" required>

        <label for="email">Email:</label>
        <input type="email" id="email" name="email">

        <label for="phone">Phone:</label>
        <input type="tel" id="phone" name="phone">

        <label for="message">Message:</label>
        <textarea id="message" name="message" rows="5" required></textarea>

        <button type="submit">Send</button>
    </form>
</body>
</html>

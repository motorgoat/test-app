<?php
/*
 * Formular-Backend für /kontakt/ – läuft am SiteGround-Server (EU).
 * Spamschutz: Honeypot-Feld + Zeitfalle. Danach Redirect auf /danke/.
 * Datenminimierung: Es wird nur gemailt, nichts gespeichert (DSGVO).
 */

declare(strict_types=1);

const EMPFAENGER = 'office@ident-it.at';
const ABSENDER = 'no-reply@ident-it.at';
const MIN_AUSFUELLZEIT_SEK = 3;

function fehler_redirect(): never
{
    header('Location: /kontakt/?fehler=1', true, 303);
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    header('Location: /kontakt/', true, 303);
    exit;
}

// Honeypot: echte Besucher lassen das Feld leer
if (!empty($_POST['firmen_website'] ?? '')) {
    header('Location: /danke/', true, 303); // Bots nicht schlauer machen
    exit;
}

// Zeitfalle: Formular wurde verdächtig schnell abgeschickt
$formTs = (int) ($_POST['form_ts'] ?? 0);
if ($formTs > 0 && (time() - $formTs) < MIN_AUSFUELLZEIT_SEK) {
    header('Location: /danke/', true, 303);
    exit;
}

$name = trim((string) ($_POST['name'] ?? ''));
$email = trim((string) ($_POST['email'] ?? ''));
$telefon = trim((string) ($_POST['telefon'] ?? ''));
$leistung = trim((string) ($_POST['leistung'] ?? ''));
$nachricht = trim((string) ($_POST['nachricht'] ?? ''));
$dsgvo = ($_POST['dsgvo'] ?? '') !== '';

if ($name === '' || $nachricht === '' || !$dsgvo || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    fehler_redirect();
}

// Header-Injection verhindern: Zeilenumbrüche aus Kopfzeilen-Werten entfernen
$clean = static fn(string $value): string => str_replace(["\r", "\n", '%0a', '%0d'], '', $value);
$name = mb_substr($clean($name), 0, 200);
$email = $clean($email);
$telefon = mb_substr($clean($telefon), 0, 50);
$leistung = mb_substr($clean($leistung), 0, 50);
$nachricht = mb_substr($nachricht, 0, 5000);

$betreff = 'Neue Anfrage über ident-it.at' . ($leistung !== '' ? " – {$leistung}" : '');

$body = "Neue Anfrage über das Kontaktformular auf ident-it.at\n\n"
    . "Name: {$name}\n"
    . "E-Mail: {$email}\n"
    . ($telefon !== '' ? "Telefon: {$telefon}\n" : '')
    . ($leistung !== '' ? "Leistung: {$leistung}\n" : '')
    . "\nNachricht:\n{$nachricht}\n";

$headers = [
    'From: ident-IT Website <' . ABSENDER . '>',
    'Reply-To: ' . $name . ' <' . $email . '>',
    'Content-Type: text/plain; charset=UTF-8',
    'X-Mailer: PHP/' . PHP_VERSION,
];

$erfolg = mail(
    EMPFAENGER,
    '=?UTF-8?B?' . base64_encode($betreff) . '?=',
    $body,
    implode("\r\n", $headers)
);

if (!$erfolg) {
    fehler_redirect();
}

header('Location: /danke/', true, 303);
exit;

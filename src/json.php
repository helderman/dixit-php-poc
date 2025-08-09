<?php
// ---------------------------------------------------------------------------
// Connect to database
// ---------------------------------------------------------------------------
require('../../dbconn.php');
$mysqli = new mysqli($sSqlSrv, $sSqlUid, $sSqlPwd, $sSqlDb);
$mysqli->set_charset('utf8mb4');
$mysqli->query("SET ROLE 'dixit';");
// ---------------------------------------------------------------------------
// Get credentials from PHP session
// ---------------------------------------------------------------------------
$username = $_SERVER['PHP_AUTH_USER'] ?? 'gast';
$pwd_hash = hash('sha256', $_SERVER['PHP_AUTH_PW'] ?? 'gast');
// ---------------------------------------------------------------------------
// Get data as JSON
// ---------------------------------------------------------------------------
$gameId = filter_input(INPUT_GET, 'game', FILTER_VALIDATE_INT);
if ($gameId === false || $gameId === null) {
	http_response_code(400);
	exit();
}
$stmt = $mysqli->prepare("CALL DixitHandsJson(?, ?, ?);");
$stmt->bind_param("ssi", $username, $pwd_hash, $gameId);
$stmt->execute();
$result = $stmt->get_result();
$game = $result->fetch_object();
if (!$game) {
	http_response_code(403);
	exit();
}
// ---------------------------------------------------------------------------
// Output JSON
// ---------------------------------------------------------------------------
header('Content-Type: application/json; charset=utf-8');
echo $game->Json;
exit();
?>

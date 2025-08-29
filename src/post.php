<?php
// ---------------------------------------------------------------------------
// Get QueryString parameters
// ---------------------------------------------------------------------------
$gameId = filter_input(INPUT_GET, 'game', FILTER_VALIDATE_INT);
$story = filter_input(INPUT_GET, 'story');
if ($gameId === false || $gameId === null || !$story) {
	http_response_code(400);
	exit();
}
// ---------------------------------------------------------------------------
// Connect to database
// ---------------------------------------------------------------------------
require('../../dbconn.php');
$mysqli = new mysqli($sSqlSrv, $sSqlUid, $sSqlPwd, $sSqlDb);
$mysqli->set_charset('utf8mb4');
if (isset($setRole)) $mysqli->query("SET ROLE 'dixit';");
// ---------------------------------------------------------------------------
// Get credentials from PHP session
// ---------------------------------------------------------------------------
$username = $_SERVER['PHP_AUTH_USER'] ?? 'gast';
$pwd_hash = hash('sha256', $_SERVER['PHP_AUTH_PW'] ?? 'gast');
// ---------------------------------------------------------------------------
// Pick
// ---------------------------------------------------------------------------
$mysqli->execute_query('CALL DixitPostStory(?, ?, ?, ?);', [$username, $pwd_hash, $gameId, $story]);
if ($mysqli->affected_rows != 1) {
	http_response_code(403);
	exit();
}
$json = json_encode($cardId, JSON_PRETTY_PRINT);
// ---------------------------------------------------------------------------
// Output JSON
// ---------------------------------------------------------------------------
header('Content-Type: application/json; charset=utf-8');
echo $json;
exit();
?>

<?php
// ---------------------------------------------------------------------------
// Get QueryString parameters
// ---------------------------------------------------------------------------
$gameId = filter_input(INPUT_GET, 'game', FILTER_VALIDATE_INT);
if ($gameId === false || $gameId === null) {
	http_response_code(400);
	exit();
}
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
// Call stored procedures
// ---------------------------------------------------------------------------
$mysqli->execute_query('CALL DixitShuffleVotingCards(?, ?, ?);', [$username, $pwd_hash, $gameId]);
if ($mysqli->affected_rows != 4) {
	http_response_code(403);
	exit();
}
$mysqli->execute_query('CALL DixitStartVoting(?, ?, ?);', [$username, $pwd_hash, $gameId]);
if ($mysqli->affected_rows != 1) {
	http_response_code(403);
	exit();
}
$json = json_encode($gameId, JSON_PRETTY_PRINT);
// ---------------------------------------------------------------------------
// Output JSON
// ---------------------------------------------------------------------------
header('Content-Type: application/json; charset=utf-8');
echo $json;
exit();
?>

<?php
// ---------------------------------------------------------------------------
// Get QueryString parameters
// ---------------------------------------------------------------------------
$gameId = filter_input(INPUT_GET, 'game', FILTER_VALIDATE_INT);
$draw = filter_input(INPUT_GET, 'draw', FILTER_VALIDATE_INT);
if ($gameId === false || $gameId === null || $draw === false || $draw === null) {
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
// Authenticate
// ---------------------------------------------------------------------------
$result = $mysqli->execute_query('CALL DixitUserId(?, ?);', [$username, $pwd_hash]);
if ($result === false) {
	http_response_code(403);
	exit();
}
$userId = $result->fetch_column();
// ---------------------------------------------------------------------------
// Draw cards
// ---------------------------------------------------------------------------
if ($draw > 0) {
	$mysqli->execute_query('CALL DixitDraw(?, ?);', [$gameId, $userId]);
}
// ---------------------------------------------------------------------------
// Get data as JSON
// ---------------------------------------------------------------------------
$result = $mysqli->execute_query('CALL DixitJson(?, ?);', [$gameId, $userId]);
if ($result === false) {
	http_response_code(403);
	exit();
}
$json = $result->fetch_column();
if (!$json) {
	http_response_code(403);
	exit();
}
// ---------------------------------------------------------------------------
// Sort arrays (necessary because MySQL's JSON_ARRAYAGG lacks ORDER BY)
// ---------------------------------------------------------------------------
$game = json_decode($json);
if ($game->Players !== null) {
	usort($game->Players, fn($a, $b) => $a->SortKey <=> $b->SortKey);
	foreach ($game->Players as $player) {
		if ($player->Cards !== null) {
			usort($player->Cards, fn($a, $b) => $a->SortKey <=> $b->SortKey);
		}
	}
}
if ($game->VotingCards !== null) {
	usort($game->VotingCards, fn($a, $b) => $a->SortKey <=> $b->SortKey);
}
$json = json_encode($game, JSON_PRETTY_PRINT);
// ---------------------------------------------------------------------------
// Output JSON
// ---------------------------------------------------------------------------
header('Content-Type: application/json; charset=utf-8');
echo $json;
exit();
?>

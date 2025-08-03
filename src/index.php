<?php
// ---------------------------------------------------------------------------
// Connect to database
// ---------------------------------------------------------------------------
require('../../dbconn.php');
$mysqli = new mysqli($sSqlSrv, $sSqlUid, $sSqlPwd, $sSqlDb);
$mysqli->set_charset('utf8mb4');
$mysqli->query("SET ROLE 'dixit';");
// ---------------------------------------------------------------------------
// Log in
// ---------------------------------------------------------------------------
$user = $_SERVER['PHP_AUTH_USER'] ?? null;
if ($user) {
	$hash = hash('sha256', $_SERVER['PHP_AUTH_PW']);
	$stmt = $mysqli->prepare("SELECT Id, FullName FROM DixitUser WHERE UserName = ? AND HashedPassword = ?");
	$stmt->bind_param("ss", $user, $hash);
	$stmt->execute();
	$result = $stmt->get_result();
	$user = $result->fetch_object();
}
if (!$user) {
	header('WWW-Authenticate: Basic realm="Dixit"');
	http_response_code(401);
?>
<!DOCTYPE html>
<meta charset="utf-8" />
<title>Dixit</title>
<link rel="stylesheet" href="dixit.css" />
<h1>Dixit</h1>
<p>
Graag <a href=".">inloggen</a>.
Toeschouwers kunnen inloggen met gebruikersnaam gast, wachtwoord gast.
</p>
<?php
	exit();
}
// ---------------------------------------------------------------------------
// Action
// ---------------------------------------------------------------------------
$action = filter_input(INPUT_GET, 'action');
if ($action) {
	if ($user->Id <= 1) {
		http_response_code(403);
		exit();
	}
	switch ($action) {
	case 'newgame':
		$gameName = filter_input(INPUT_POST, 'name');
		if ($gameName) {
			$stmt = $mysqli->prepare("INSERT INTO DixitGame (Name) VALUES (?)");
			$stmt->bind_param("s", $gameName);
			$stmt->execute();
			$players = array(2, 3, 4, 5);
			foreach ($players as $userId) {
				$stmt = $mysqli->prepare("INSERT INTO DixitPlayer (GameId, UserId) VALUES (?, ?)");
				$stmt->bind_param("ii", $gameId, $userId);
				$stmt->execute();
			}
		}
		break;
	default:
		http_response_code(400);
		exit();
	}
	header('Location: .');
	exit();
}
// ---------------------------------------------------------------------------
// Lobby
// ---------------------------------------------------------------------------
$gameId = filter_input(INPUT_GET, 'game', FILTER_VALIDATE_INT);
if ($gameId === false || $gameId === null) {
?>
<!DOCTYPE html>
<meta charset="utf-8" />
<title>Dixit</title>
<link rel="stylesheet" href="dixit.css" />
<h1>Dixit - Lobby</h1>
<ul>
<?php
$stmt = $mysqli->prepare("SELECT Id, Name FROM DixitGame ORDER BY Id DESC");
$stmt->execute();
$stmt->bind_result($gameId, $gameName);
while ($stmt->fetch()) {
	echo '<li><a href="?game=', urlencode($gameId), '">', htmlspecialchars($gameName), "</a></li>\n";
}
?>
</ul>
<h2>Een nieuw spel aanmaken</h2>
<form action="?action=newgame" method="post">
Geef het spel een naam:
<input type="text" name="name" required />
<input type="submit" value="Aanmaken" />
</form>
<?php
	exit();
}
// ---------------------------------------------------------------------------
// Game name
// ---------------------------------------------------------------------------
$stmt = $mysqli->prepare("SELECT Name FROM DixitGame WHERE Id = ?");
$stmt->bind_param("i", $gameId);
$stmt->execute();
$result = $stmt->get_result();
$game = $result->fetch_object();
if (!$game) {
	http_response_code(403);
	exit();
}
?>
<!DOCTYPE html>
<meta charset="utf-8" />
<title>Dixit</title>
<link rel="stylesheet" href="dixit.css" />
<h1>Dixit - <?= htmlspecialchars($game->Name) ?> - <?= htmlspecialchars($user->FullName) ?></h1>
<p id="story"></p>
<div class="players">
<?php
// ---------------------------------------------------------------------------
// Game members
// ---------------------------------------------------------------------------
$stmt = $mysqli->prepare("SELECT u.Id, u.FullName FROM DixitPlayer p INNER JOIN DixitUser u ON u.Id = p.UserId WHERE p.GameId = ? ORDER BY p.SortKey");
$stmt->bind_param("i", $gameId);
$stmt->execute();
$stmt->bind_result($playerId, $playerFullName);
while ($stmt->fetch()) {
?>
<div class="player">
<h2><?= htmlspecialchars($playerFullName) ?></h2>
<div id="player<?= $playerId ?>">
</div>
</div>
<?php
}
?>
</div>
<script src="index.js"></script>
<script>poll(<?= $gameId ?>);</script>

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
$user = null;
$username = $_SERVER['PHP_AUTH_USER'] ?? null;
if ($username) {
	$pwd_hash = hash('sha256', $_SERVER['PHP_AUTH_PW']);
	$stmt = $mysqli->prepare("SELECT Id, FullName FROM DixitUser WHERE UserName = ? AND HashedPassword = ?");
	$stmt->bind_param("ss", $username, $pwd_hash);
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
<div class="user"><a href=".">inloggen</a></div>
<h1>Dixit</h1>
<p>
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
			$stmt = $mysqli->prepare("CALL DixitCreateGame(?, ?, ?)");
			$stmt->bind_param("sss", $username, $pwd_hash, $gameName);
			$stmt->execute();
			$gameId = $mysqli->insert_id;
			$stmt = $mysqli->prepare("CALL DixitCreateDeck(?)");
			$stmt->bind_param("i", $gameId);
			$stmt->execute();
			if (isset($_POST['join'])) {
				$stmt = $mysqli->prepare("CALL DixitJoinGame(?, ?, ?)");
				$stmt->bind_param("ssi", $username, $pwd_hash, $gameId);
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
<div class="user"><?= htmlspecialchars($user->FullName) ?></div>
<h1>Dixit &ndash; Lobby</h1>
<h2>Spelers en toeschouwers, kies hier een speeltafel</h2>
<ul>
<?php
$stmt = $mysqli->prepare("SELECT Id, Name FROM DixitGame ORDER BY Id");
$stmt->execute();
$stmt->bind_result($gameId, $gameName);
while ($stmt->fetch()) {
	echo '<li><a href="?game=', urlencode($gameId), '">', htmlspecialchars($gameName), "</a></li>\n";
}
?>
</ul>
<h2>Beheerders, maak hier een nieuwe speeltafel aan</h2>
<form action="?action=newgame" method="post">
<p>
Geef de speeltafel een naam:
<input type="text" name="name" size="100" required><br>
</p>
<p>
Direct jezelf toevoegen als speler aan deze speeltafel:
<input type="checkbox" name="join" checked><br>
</p>
<p>
Bevestig je keuzes:
<input type="submit" value="OK">
</p>
</form>
<?php
	exit();
}
// ---------------------------------------------------------------------------
// Game name and manager
// ---------------------------------------------------------------------------
$stmt = $mysqli->prepare("SELECT Name, MgrUserId FROM DixitGame WHERE Id = ?");
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
<div class="user"><?= htmlspecialchars($user->FullName) ?></div>
<h1><a href=".">Dixit</a> &ndash; <?= htmlspecialchars($game->Name) ?></h1>
<p id="story"></p>
<p>
<?php
if ($user->Id == $game->MgrUserId) {
?>
<button id="start" onclick="start(<?= $gameId ?>)">Start het spel</button>
<button id="stop" onclick="stop(<?= $gameId ?>)">Stop het spel</button>
<button id="reshuffle" onclick="reshuffle(<?= $gameId ?>)">Stapel schudden</button>
<?php
}
?>
<button id="voting" onclick="voting(<?= $gameId ?>)">Start het stemmen</button>
<button id="show" onclick="show(<?= $gameId ?>)">Naar de uitslag</button>
<button id="next" onclick="next(<?= $gameId ?>)">Start de volgende beurt</button>
</p>
<p style="display:none">
Je bent de verteller, kies een kaart en doe je uitspraak:
<input id="edit" maxlength="255"><button onclick="post(<?= $gameId ?>)">Bevestig</button>
</p>
<div id="players"></div>
<script src="index.js"></script>
<script>poll(<?= $gameId ?>);</script>

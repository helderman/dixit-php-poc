-- Run this script as follows:
-- sed 's/^#//' sql/dixit.sql | sudo mysql dixit
-- (assuming the database is named dixit)

#-- DROP USER IF EXISTS 'dixit'@'localhost';
#-- CREATE USER 'dixit'@'localhost' IDENTIFIED BY '12345';
#DROP ROLE IF EXISTS 'dixit';
#CREATE ROLE 'dixit';
#GRANT 'dixit' TO 'dixit'@'localhost';	-- development PC
#-- GRANT 'dixit' TO CURRENT_USER;		-- Hobbynet server

DROP TABLE IF EXISTS DixitCard;
CREATE TABLE DixitCard (
	Id int NOT NULL AUTO_INCREMENT PRIMARY KEY
);
INSERT INTO DixitCard () VALUES   -- numbers 1-84
	(), (), (), (), (), (), (), (), (), (), (), (),
	(), (), (), (), (), (), (), (), (), (), (), (),
	(), (), (), (), (), (), (), (), (), (), (), (),
	(), (), (), (), (), (), (), (), (), (), (), (),
	(), (), (), (), (), (), (), (), (), (), (), (),
	(), (), (), (), (), (), (), (), (), (), (), (),
	(), (), (), (), (), (), (), (), (), (), (), ();

DROP TABLE IF EXISTS DixitUser;
CREATE TABLE DixitUser (
	Id int NOT NULL AUTO_INCREMENT PRIMARY KEY,
	UserName varchar(100) NOT NULL,
	HashedPassword varchar(64) NOT NULL,
	FullName varchar(100) NOT NULL,

	UNIQUE ixUserName (UserName)
);

#GRANT SELECT ON DixitUser TO 'dixit';

INSERT INTO DixitUser (UserName, HashedPassword, FullName) VALUES
	('gast', 'aaac7fafa76910e7a042ae9f783c08cc516ea835ee3cffb7055421a25be67a21', 'Gast'),
	('kees', 'a51c75213f877072d747efd372e729a8c348af908b12140aec373bee0c3032a7', 'Kees'),
	('marco', '39ca1d9c2ea67847fe6adb6f7ff73560323a56ac182607f13adf4583a5ef00f9', 'Marco'),
	('marja', 'b7f750c2c0a45ce9965691c8c8609184c8db4454b5deab9d8de5161ebdd786d0', 'Marja'),
	('paul', '363eb4ba561085d02bd4e6c07aa9847c762e97409fbd8876ddd192c38b66d9a0', 'Paul'),
	('rene', '6fcf8bf65219de08e0fce65a7cdda568c1fdc04286551ca264fd13bcd8331955', 'Rene'),
	('ruud', '10420dde4669ae7c675eaccc72bd4814cab0ad6b823cc384d8ce9b574bcf574e', 'Ruud'),
	('winfried', 'e3cf9835a6308421367bd4945127c8acd4594b2dda941b520c0fdc104179140d', 'Winfried'),
	('wim', 'f4c62aeb63302d6b1dbd9864dbd36acd1182bed76585cb3b8eff506f85bc7e14', 'Wim');

DROP TABLE IF EXISTS DixitGame;
CREATE TABLE DixitGame (
	Id int NOT NULL AUTO_INCREMENT PRIMARY KEY,
	Name varchar(100) NOT NULL,
	MgrUserId int NOT NULL,
	StUserId int NULL,
	Story varchar(255) NULL,
	Status tinyint NOT NULL DEFAULT 0,	-- 0 = join, 1 = story, 2 = pick, 3 = vote, 4 = showdown
	StatusSince TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

#GRANT SELECT ON DixitGame TO 'dixit';

DROP TABLE IF EXISTS DixitPlayer;
CREATE TABLE DixitPlayer (
	GameId int NOT NULL,
	UserId int NOT NULL,
	SortKey float NOT NULL,
	Score int NOT NULL DEFAULT 0,
	VoteCardId int NOT NULL DEFAULT 0,

	UNIQUE ixGameUser (GameId, UserId),
	UNIQUE ixSortKey (GameId, SortKey)
);

#GRANT SELECT ON DixitPlayer TO 'dixit';

DROP TABLE IF EXISTS DixitGameCard;
CREATE TABLE DixitGameCard (
	GameId int NOT NULL,
	CardId int NOT NULL,
	SortKey float NOT NULL,
	UserId int NOT NULL DEFAULT 0,        -- 0 = on draw pile, -1 = on discard pile
	IsPicked bool NOT NULL DEFAULT false,

	UNIQUE ixGameCard (GameId, CardId),
	UNIQUE ixSortKey (GameId, SortKey)
);

#GRANT SELECT ON DixitGameCard TO 'dixit';

-- Get user ID
DROP PROCEDURE IF EXISTS DixitUserId;
CREATE PROCEDURE DixitUserId(p_userName varchar(100), p_hashedPassword varchar(64))
	SELECT Id
	FROM DixitUser
	WHERE UserName = p_userName
	AND HashedPassword = p_hashedPassword;

#GRANT EXECUTE ON PROCEDURE DixitUserId TO 'dixit';

-- Get players
DROP PROCEDURE IF EXISTS DixitPlayerList;
CREATE PROCEDURE DixitPlayerList(p_gameId int)
	SELECT Id, FullName
	FROM DixitUser
	WHERE Id IN (SELECT UserId FROM DixitPlayer WHERE GameId = p_gameId)
	ORDER BY Id;

#GRANT EXECUTE ON PROCEDURE DixitPlayerList TO 'dixit';

-- Get all cards currently in play; expose only open cards and your own cards
-- Note: MySQL's JSON_ARRAYAGG does not support ORDER BY :'-(
DROP PROCEDURE IF EXISTS DixitJson;
CREATE PROCEDURE DixitJson(p_gameId int, p_userId int)
	SELECT JSON_OBJECT(
		'StUserId', g.StUserId,
		'IAmMgr', g.MgrUserId = p_userId,
		'IAmSt', g.StUserId = p_userId,
		'Story', g.Story,
		'Status', g.Status,
		'StatusSince', g.StatusSince,
		'Players', (
			SELECT JSON_ARRAYAGG(JSON_OBJECT(
				'Id', p.UserId,
				'IsMe', p.UserId = p_userId,
				'IsSt', p.UserId = g.StUserId,
				'FullName', u.FullName,
				'Score', p.Score,
				'SortKey', p.SortKey,
				'Cards', (
					SELECT JSON_ARRAYAGG(JSON_OBJECT(
						'Id', CASE WHEN c.UserId = p_userId THEN c.CardId END,
						'IsPicked', c.IsPicked = true,
						'SortKey', c.SortKey
					))
					FROM DixitGameCard c
					WHERE c.GameId = p.GameId
					AND c.UserId = p.UserId
				),
				'Vote', CASE WHEN p.UserId = p_userId OR p.VoteCardId = 0 THEN p.VoteCardId END
			))
			FROM DixitPlayer p
			INNER JOIN DixitUser u ON u.Id = p.UserId
			WHERE p.GameId = g.Id
		),
		'VotingCards', (
			SELECT JSON_ARRAYAGG(JSON_OBJECT(
				'Id', c.CardId,
				'StPick', g.Status > 3 AND c.UserId = g.StUserId,
				'SortKey', c.SortKey
			))
			FROM DixitGameCard c
			WHERE g.Status > 1
			AND c.GameId = g.Id
			AND c.IsPicked
		)
	)
	FROM DixitGame g
	WHERE g.Id = p_gameId;

#GRANT EXECUTE ON PROCEDURE DixitJson TO 'dixit';

-- Create game
-- Note: in PHP, after calling this SP, $mysqli->insert_id holds game's Id
DROP PROCEDURE IF EXISTS DixitCreateGame;
CREATE PROCEDURE DixitCreateGame(p_userName varchar(100), p_hashedPassword varchar(64), p_name varchar(100))
	INSERT INTO DixitGame (Name, MgrUserId)
	SELECT p_name, Id
	FROM DixitUser
	WHERE UserName = p_userName
	AND HashedPassword = p_hashedPassword;

#GRANT EXECUTE ON PROCEDURE DixitCreateGame TO 'dixit';

-- Create the deck for a game
DROP PROCEDURE IF EXISTS DixitCreateDeck;
CREATE PROCEDURE DixitCreateDeck(p_gameId int)
	INSERT INTO DixitGameCard (SortKey, GameId, CardId)
	SELECT RAND(), p_gameId, Id
	FROM DixitCard;

#GRANT EXECUTE ON PROCEDURE DixitCreateDeck TO 'dixit';

-- Let manager add player to game
-- Note: in PHP, after calling this SP, $mysqli->affected_rows is 1 (success) or 0
DROP PROCEDURE IF EXISTS DixitAddPlayer;
CREATE PROCEDURE DixitAddPlayer(p_userName varchar(100), p_hashedPassword varchar(64), p_gameId int, p_userId int)
	INSERT INTO DixitPlayer (GameId, UserId, SortKey)
	SELECT Id, p_userId, RAND()
	FROM DixitGame
	WHERE Id = p_gameId
	AND MgrUserId IN (SELECT Id FROM DixitUser WHERE UserName = p_userName AND HashedPassword = p_hashedPassword);

#GRANT EXECUTE ON PROCEDURE DixitAddPlayer TO 'dixit';

-- Let manager remove player from game
-- Note: in PHP, after calling this SP, $mysqli->affected_rows is 1 (success) or 0
DROP PROCEDURE IF EXISTS DixitRemovePlayer;
CREATE PROCEDURE DixitRemovePlayer(p_userName varchar(100), p_hashedPassword varchar(64), p_gameId int, p_userId int)
	DELETE FROM DixitPlayer
	WHERE GameId = p_gameId
	AND UserId = p_userId
	AND GameId IN (
		SELECT Id FROM DixitGame WHERE MgrUserId IN (
			SELECT Id FROM DixitUser WHERE UserName = p_userName AND HashedPassword = p_hashedPassword
		)
	);

#GRANT EXECUTE ON PROCEDURE DixitRemovePlayer TO 'dixit';

-- Let player add themselves to game
-- Note: in PHP, after calling this SP, $mysqli->affected_rows is 1 (success) or 0
DROP PROCEDURE IF EXISTS DixitJoinGame;
CREATE PROCEDURE DixitJoinGame(p_userName varchar(100), p_hashedPassword varchar(64), p_gameId int)
	INSERT INTO DixitPlayer (GameId, UserId, SortKey)
	SELECT p_gameId, Id, RAND()
	FROM DixitUser
	WHERE UserName = p_userName
	AND HashedPassword = p_hashedPassword
	AND EXISTS (SELECT * FROM DixitGame WHERE Id = p_gameId AND Status = 0);

#GRANT EXECUTE ON PROCEDURE DixitJoinGame TO 'dixit';

-- Let player remove themselves from game
-- Note: in PHP, after calling this SP, $mysqli->affected_rows is 1 (success) or 0
DROP PROCEDURE IF EXISTS DixitLeaveGame;
CREATE PROCEDURE DixitLeaveGame(p_userName varchar(100), p_hashedPassword varchar(64), p_gameId int)
	DELETE FROM DixitPlayer
	WHERE GameId = p_gameId
	AND UserId IN (SELECT Id FROM DixitUser WHERE UserName = p_userName AND HashedPassword = p_hashedPassword);

#GRANT EXECUTE ON PROCEDURE DixitLeaveGame TO 'dixit';

-- Draw card(s) if less than 6 in hand
-- Note: in PHP, after calling this SP, $mysqli->affected_rows < 6 means draw pile depleted
DROP PROCEDURE IF EXISTS DixitDraw;
CREATE PROCEDURE DixitDraw(p_gameId int, p_userId int)
	UPDATE DixitGameCard
	SET UserId = p_userId
	WHERE GameId IN (SELECT Id FROM DixitGame WHERE Id = p_gameId AND Status = 1)
	AND UserId IN (0, p_userId)
	AND EXISTS (SELECT * FROM DixitPlayer WHERE GameId = p_gameId AND UserId = p_userId)
	ORDER BY UserId DESC, SortKey
	LIMIT 6;

#GRANT EXECUTE ON PROCEDURE DixitDraw TO 'dixit';

-- Discard picked cards
DROP PROCEDURE IF EXISTS DixitDiscard;
CREATE PROCEDURE DixitDiscard(p_gameId int)
	UPDATE DixitGameCard
	SET UserId = -1, IsPicked = false
	WHERE GameId = p_gameId
	AND IsPicked;

-- Move 'discard pile' (if any) onto 'draw pile', and shuffle the pile.
DROP PROCEDURE IF EXISTS DixitShuffleDrawPile;
CREATE PROCEDURE DixitShuffleDrawPile(p_gameId int)
	UPDATE DixitGameCard
	SET SortKey = RAND(), UserId = 0
	WHERE GameId = p_gameId
	AND UserId <= 0;

#GRANT EXECUTE ON PROCEDURE DixitShuffleDrawPile TO 'dixit';

-- Rotate the players so that the next one will become first in line; reset votes.
DROP PROCEDURE IF EXISTS DixitRotatePlayers;
CREATE PROCEDURE DixitRotatePlayers(p_userName varchar(100), p_hashedPassword varchar(64), p_gameId int)
	UPDATE DixitPlayer
	SET SortKey = SortKey + 1.0, VoteCardId = 0
	WHERE GameId = p_gameId
	AND UserId IN (SELECT StUserId FROM DixitGame WHERE Id = p_gameId)
	AND UserId IN (SELECT Id FROM DixitUser WHERE UserName = p_userName AND HashedPassword = p_hashedPassword);

#GRANT EXECUTE ON PROCEDURE DixitRotatePlayers TO 'dixit';

-- Make the player who is first in line the storyteller.
-- Call this SP either after adding players or after calling DixitRotatePlayers.
DROP PROCEDURE IF EXISTS DixitStartTurn;
CREATE PROCEDURE DixitStartTurn(p_userName varchar(100), p_hashedPassword varchar(64), p_gameId int)
	UPDATE DixitGame
	SET StUserId = (SELECT UserId FROM DixitPlayer WHERE GameId = p_gameId ORDER BY SortKey LIMIT 1),
		Story = NULL,
		Status = 1
	WHERE Id = p_gameId
	AND Status IN (0, 4)
	AND 4 = (SELECT COUNT(*) FROM DixitPlayer WHERE GameId = p_gameId)
	AND COALESCE(StUserId, MgrUserId) IN (SELECT Id FROM DixitUser WHERE UserName = p_userName AND HashedPassword = p_hashedPassword);

#GRANT EXECUTE ON PROCEDURE DixitStartTurn TO 'dixit';

-- Pick card (works both for storyteller and for voter)
-- Note: in PHP, after calling this SP, $mysqli->affected_rows is 1 or 2 (success) or 0
DROP PROCEDURE IF EXISTS DixitPickCard;
CREATE PROCEDURE DixitPickCard(p_userName varchar(100), p_hashedPassword varchar(64), p_gameId int, p_cardId int)
	UPDATE DixitGameCard
	SET IsPicked = (CardId = p_cardId)
	WHERE GameId IN (SELECT Id FROM DixitGame WHERE Id = p_gameId AND Status = CASE StUserId WHEN UserId THEN 1 ELSE 2 END)
	AND UserId IN (SELECT Id FROM DixitUser WHERE UserName = p_userName AND HashedPassword = p_hashedPassword);

#GRANT EXECUTE ON PROCEDURE DixitPickCard TO 'dixit';

-- Post story (storyteller only).
DROP PROCEDURE IF EXISTS DixitPostStory;
CREATE PROCEDURE DixitPostStory(p_userName varchar(100), p_hashedPassword varchar(64), p_gameId int, p_story varchar(255))
	UPDATE DixitGame
	SET Status = 2, Story = p_story
	WHERE Id = p_gameId
	AND Id IN (SELECT GameId FROM DixitGameCard WHERE UserId = stUserId)
	AND Status = 1
	AND StUserId IN (SELECT Id FROM DixitUser WHERE UserName = p_userName AND HashedPassword = p_hashedPassword);

#GRANT EXECUTE ON PROCEDURE DixitPostStory TO 'dixit';

-- Shuffle voting cards
-- TODO: allow only if every player picked a card
DROP PROCEDURE IF EXISTS DixitShuffleVotingCards;
CREATE PROCEDURE DixitShuffleVotingCards(p_userName varchar(100), p_hashedPassword varchar(64), p_gameId int)
	UPDATE DixitGameCard
	SET SortKey = RAND()
	WHERE IsPicked
	AND GameId IN (
		SELECT Id FROM DixitGame WHERE Id = p_gameId AND MgrUserId IN (
			SELECT Id FROM DixitUser WHERE UserName = p_userName AND HashedPassword = p_hashedPassword
		)
	);

#GRANT EXECUTE ON PROCEDURE DixitShuffleVotingCards TO 'dixit';

-- Start the voting phase
-- TODO: allow ST to run this
DROP PROCEDURE IF EXISTS DixitStartVoting;
CREATE PROCEDURE DixitStartVoting(p_userName varchar(100), p_hashedPassword varchar(64), p_gameId int)
	UPDATE DixitGame
	SET Status = 3
	WHERE Status = 2
	AND MgrUserId IN (SELECT Id FROM DixitUser WHERE UserName = p_userName AND HashedPassword = p_hashedPassword);

#GRANT EXECUTE ON PROCEDURE DixitStartVoting TO 'dixit';

-- Let manager stop the game (table DixitGame)
-- Note: in PHP, after calling this SP, $mysqli->affected_rows is 1 (success) or 0
DROP PROCEDURE IF EXISTS DixitStopGame;
CREATE PROCEDURE DixitStopGame(p_userName varchar(100), p_hashedPassword varchar(64), p_gameId int)
	UPDATE DixitGame
	SET Status = 0, StUserId = NULL
	WHERE MgrUserId IN (SELECT Id FROM DixitUser WHERE UserName = p_userName AND HashedPassword = p_hashedPassword);

#GRANT EXECUTE ON PROCEDURE DixitStopGame TO 'dixit';

-- Let manager stop the game (table DixitGameCard)
-- Note: in PHP, after calling this SP, $mysqli->affected_rows is 84 (success) or 0
DROP PROCEDURE IF EXISTS DixitResetDeck;
CREATE PROCEDURE DixitResetDeck(p_userName varchar(100), p_hashedPassword varchar(64), p_gameId int)
	UPDATE DixitGameCard
	SET SortKey = RAND(), UserId = 0, IsPicked = false
	WHERE GameId IN (
		SELECT Id FROM DixitGame WHERE Id = p_gameId AND MgrUserId IN (
			SELECT Id FROM DixitUser WHERE UserName = p_userName AND HashedPassword = p_hashedPassword
		)
	);

#GRANT EXECUTE ON PROCEDURE DixitResetDeck TO 'dixit';

-- Let manager stop the game (table DixitPlayer)
-- Note: in PHP, after calling this SP, $mysqli->affected_rows is 4 (success) or 0
DROP PROCEDURE IF EXISTS DixitResetVotes;
CREATE PROCEDURE DixitResetVotes(p_userName varchar(100), p_hashedPassword varchar(64), p_gameId int)
	UPDATE DixitPlayer
	SET SortKey = RAND(), VoteCardId = 0
	WHERE GameId IN (
		SELECT Id FROM DixitGame WHERE Id = p_gameId AND MgrUserId IN (
			SELECT Id FROM DixitUser WHERE UserName = p_userName AND HashedPassword = p_hashedPassword
		)
	);

#GRANT EXECUTE ON PROCEDURE DixitResetVotes TO 'dixit';

CALL DixitCreateGame('ruud', '10420dde4669ae7c675eaccc72bd4814cab0ad6b823cc384d8ce9b574bcf574e', 'HCC demo 29 augustus');
CALL DixitCreateDeck(1);
CALL DixitAddPlayer('ruud', '10420dde4669ae7c675eaccc72bd4814cab0ad6b823cc384d8ce9b574bcf574e', 1, 3);
CALL DixitAddPlayer('ruud', '10420dde4669ae7c675eaccc72bd4814cab0ad6b823cc384d8ce9b574bcf574e', 1, 4);
CALL DixitAddPlayer('ruud', '10420dde4669ae7c675eaccc72bd4814cab0ad6b823cc384d8ce9b574bcf574e', 1, 6);
CALL DixitAddPlayer('ruud', '10420dde4669ae7c675eaccc72bd4814cab0ad6b823cc384d8ce9b574bcf574e', 1, 7);

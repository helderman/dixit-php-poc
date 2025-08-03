-- Run this script as follows: sudo mysql dixit < dixit.sql

-- DROP USER IF EXISTS 'dixit'@'localhost';
-- CREATE USER 'dixit'@'localhost' IDENTIFIED BY '12345';
DROP ROLE IF EXISTS 'dixit';
CREATE ROLE 'dixit';
GRANT 'dixit' TO 'dixit'@'localhost';	-- development PC
-- GRANT 'dixit' TO CURRENT_USER;		-- Hobbynet server

DROP TABLE IF EXISTS DixitUser;
CREATE TABLE DixitUser (
	Id int NOT NULL auto_increment,
	UserName varchar(100) NOT NULL,
	HashedPassword varchar(64) NOT NULL,
	FullName varchar(100) NOT NULL,

	PRIMARY KEY (Id),
	UNIQUE ixUserName (UserName)
);

GRANT SELECT ON dixit.DixitUser TO 'dixit';

INSERT INTO DixitUser (Id, UserName, HashedPassword, FullName) VALUES
	(1, 'gast', 'aaac7fafa76910e7a042ae9f783c08cc516ea835ee3cffb7055421a25be67a21', 'Gast'),
	(2, 'marja', 'b7f750c2c0a45ce9965691c8c8609184c8db4454b5deab9d8de5161ebdd786d0', 'Marja'),
	(3, 'marco', '39ca1d9c2ea67847fe6adb6f7ff73560323a56ac182607f13adf4583a5ef00f9', 'Marco'),
	(4, 'rene', '6fcf8bf65219de08e0fce65a7cdda568c1fdc04286551ca264fd13bcd8331955', 'Rene'),
	(5, 'ruud', '10420dde4669ae7c675eaccc72bd4814cab0ad6b823cc384d8ce9b574bcf574e', 'Ruud');

DROP TABLE IF EXISTS DixitGame;
CREATE TABLE DixitGame (
	Id int NOT NULL auto_increment,
	Name varchar(100) NOT NULL,
	StUserId int NULL,
	Story varchar(255) NULL,
	Status tinyint NOT NULL DEFAULT 0,
	StatusSince TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

	PRIMARY KEY (Id)
);

GRANT SELECT ON dixit.DixitGame TO 'dixit';

INSERT INTO DixitGame (Id, Name, StUserId, Story, Status) VALUES (1, 'HCC test crew', 2, 'Spring is in the air.', 2);

DROP TABLE IF EXISTS DixitPlayer;
CREATE TABLE DixitPlayer (
	GameId int NOT NULL,
	UserId int NOT NULL,
	SortKey float NOT NULL DEFAULT 0,
	Score int NOT NULL DEFAULT 0,

	UNIQUE ixGameUser (GameId, UserId)
);

GRANT SELECT ON dixit.DixitPlayer TO 'dixit';

INSERT INTO DixitPlayer (SortKey, GameId, UserId) VALUES (RAND(), 1, 2), (RAND(), 1, 3), (RAND(), 1, 4), (RAND(), 1, 5);

DROP TABLE IF EXISTS DixitGameCard;
CREATE TABLE DixitGameCard (
	SortKey float NOT NULL,
	GameId int NOT NULL,
	CardId int NOT NULL,
	UserId int NULL,        -- to move card to a 'discard pile', assign card to a dummy user (e.g. -1)
	IsPicked bool NOT NULL DEFAULT false,

	UNIQUE ixSortKey (SortKey),
	UNIQUE ixGameUserCard (GameId, UserId, CardId)
);

GRANT SELECT ON dixit.DixitGameCard TO 'dixit';

INSERT INTO DixitGameCard (SortKey, GameId, CardId, UserId, IsPicked) VALUES
	(RAND(), 1, 21, 2, false), (RAND(), 1, 22, 2, true), (RAND(), 1, 31, 3, false), (RAND(), 1, 32, 3, true);

DROP TABLE IF EXISTS DixitVote;
CREATE TABLE DixitVote (
	GameId int NOT NULL,
	CardId int NOT NULL,
	UserId int NULL,

	UNIQUE ixGameUserCard (GameId, UserId, CardId)
);

GRANT SELECT ON dixit.DixitVote TO 'dixit';

INSERT INTO DixitVote (GameId, CardId, UserId) VALUES
	(1, 21, 4), (1, 22, 5), (1, 31, 3);

-- Get all hands of cards currently in play; expose only open cards and your own cards
DROP PROCEDURE IF EXISTS dixit.DixitHandsJson;
CREATE PROCEDURE dixit.DixitHandsJson(p_gameId int, p_userName varchar(100), p_hashedPassword varchar(64))
	SELECT JSON_OBJECT(
		'StUserId', g.StUserId,
		'Story', g.Story,
		'Status', g.Status,
		'StatusSince', g.StatusSince,
		'Players', (
			SELECT JSON_ARRAYAGG(JSON_OBJECT(
				'Id', p.UserId,
				'Score', p.Score,
				'Cards', (
					SELECT JSON_ARRAYAGG(JSON_OBJECT('SortKey', c.SortKey, 'Id', CASE WHEN c.UserId = u.Id THEN c.CardId END, 'IsPicked', c.IsPicked = true))
					FROM DixitGameCard c
					WHERE c.GameId = p.GameId
					AND c.UserId = p.UserId
				),
				'Votes', (
					SELECT JSON_ARRAYAGG(JSON_OBJECT('CardId', CASE WHEN v.UserId = u.Id OR g.Status > 1 THEN v.CardId END))
					FROM DixitVote v
					WHERE v.GameId = p.GameId
					AND v.UserId = p.UserId
				)
			))
			FROM DixitPlayer p
			WHERE p.GameId = g.Id
		),
		'VotingCards', (
			SELECT JSON_ARRAYAGG(JSON_OBJECT('Id', c.CardId, 'StPick', g.Status > 1 AND c.UserId = g.StUserId))
			FROM DixitGameCard c
			WHERE g.Status > 0
			AND c.GameId = g.Id
			AND c.IsPicked
			ORDER BY c.CardId
		)
	) AS Json
	FROM DixitGame g
	INNER JOIN DixitUser u ON u.UserName = p_userName AND u.HashedPassword = p_hashedPassword
	WHERE g.Id = p_gameId;

GRANT EXECUTE ON PROCEDURE dixit.DixitHandsJson TO 'dixit';

-- Shuffle the cards on the 'draw pile'.
DROP PROCEDURE IF EXISTS dixit.DixitShuffleDrawPile;
CREATE PROCEDURE dixit.DixitShuffleDrawPile(p_gameId int)
	UPDATE DixitGameCard
	SET SortKey = RAND()
	WHERE GameId = p_gameId AND UserId IS NULL;

GRANT EXECUTE ON PROCEDURE dixit.DixitShuffleDrawPile TO 'dixit';

-- Shuffle the players (give them random seats at the table).
DROP PROCEDURE IF EXISTS dixit.DixitFirstTurn;
CREATE PROCEDURE dixit.DixitFirstTurn(p_gameId int)
	UPDATE DixitPlayer
	SET SortKey = RAND()
	WHERE GameId = p_gameId;

GRANT EXECUTE ON PROCEDURE dixit.DixitFirstTurn TO 'dixit';

-- Rotate the players so that the next one will become first in line.
DROP PROCEDURE IF EXISTS dixit.DixitNextTurn;
CREATE PROCEDURE dixit.DixitNextTurn(p_gameId int)
	UPDATE DixitPlayer
	SET SortKey = SortKey + 1.0
	WHERE GameId = p_gameId AND UserId = (SELECT StUserId FROM DixitGame WHERE Id = p_gameId);

GRANT EXECUTE ON PROCEDURE dixit.DixitNextTurn TO 'dixit';

-- Make the player who is first in line the storyteller.
-- Call this SP after calling DixitFirstTurn or DixitNextTurn.
DROP PROCEDURE IF EXISTS dixit.DixitStartTurn;
CREATE PROCEDURE dixit.DixitStartTurn(p_gameId int)
	UPDATE DixitGame
	SET StUserId = (SELECT UserId FROM DixitPlayer WHERE GameId = p_gameId ORDER BY SortKey LIMIT 1),
		Story = NULL,
		Status = 0
	WHERE Id = p_gameId;

GRANT EXECUTE ON PROCEDURE dixit.DixitStartTurn TO 'dixit';

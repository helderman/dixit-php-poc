async function poll(gameId) {
	const players = document.getElementById('players');
	let draw = 0;
	for (;;) {
		const response = await fetch('json.php?game=' + encodeURIComponent(gameId) + '&draw=' + encodeURIComponent(draw));
		draw = 0;
		if (response.ok) {
			const game = await response.json();
			document.getElementById('story').innerHTML = GetStory(game);
			let html = '';
			switch (game.Status) {
				case 3:
				case 4:
					html += '<div class="voting">';
					for (const card of game.VotingCards) {
						html += '<img ' +
							' src="img/card' +
							String(card.Id ?? '0').padStart(2, '0') +
							'.jpg">\n';
					}
					html += '</div>\n';
					break;
				default:
					for (const player of game.Players) {
						const cards = player.Cards ?? [];
						if (game.Status > 0 && player.IsMe) {
							draw = 6 - cards.length;
						}
						html += '<div class="player"><h2';
						if (player.IsMe) html += ' class="me"';
						html += '>' + HtmlEncode(player.FullName) +
							'</h2>\n<p>Score: ' + player.Score + '</p>\n<div>\n';
						for (const card of cards) {
							html += '<img ' +
								(card.IsPicked ? 'class="picked"' : 'onclick="pick(this, ' + gameId + ', ' + card.Id + ')"') +
								' src="img/card' +
								String(card.Id ?? '0').padStart(2, '0') +
								'.jpg">\n';
						}
						html += '</div>\n</div>\n';
					}
			}
			if (players.innerHTML != html) {
				//console.log('Old: ' + players.innerHTML + '\nNew: ' + html);
				players.innerHTML = html;
			}
			Display('start', game.Status == 0 && game.Players.length == 4);
			Display('stop', game.Status > 0);
			Display('vote', game.Status == 2 && (game.IAmMgr || game.IAmSt));
			Display('show', game.Status == 3 && (game.IAmMgr || game.IAmSt));
			Display('next', game.Status == 4 && (game.IAmMgr || game.IAmSt));
			document.getElementById('edit').parentNode.style.display =
				game.Status == 1 && game.IAmSt ? 'block' : 'none';
		}
		else {
			console.log(response);
		}
		await new Promise(r => setTimeout(r, 1000));   // sleep 1000 ms
	}
}

async function start(gameId) {
	await fetch('start.php?game=' + encodeURIComponent(gameId));
}

async function stop(gameId) {
	if (confirm('Weet je zeker dat je het spel wilt afbreken?')) {
		await fetch('stop.php?game=' + encodeURIComponent(gameId));
	}
}

async function vote(gameId) {
	await fetch('vote.php?game=' + encodeURIComponent(gameId));
}

async function next(gameId) {
	await fetch('next.php?game=' + encodeURIComponent(gameId));
}

async function post(gameId) {
	const story = document.getElementById('edit').value;
	await fetch('post.php?game=' + encodeURIComponent(gameId) + '&story=' + encodeURIComponent(story));
}

async function pick(img, gameId, cardId) {
	if (!img.classList.contains('picked')) {
		img.classList.add('picked');
		await fetch('pick.php?game=' + encodeURIComponent(gameId) + '&card=' + encodeURIComponent(cardId));
	}
}

function GetStory(game) {
	switch (game.Status) {
		case 0:
			return 'Zodra er 4 spelers zijn, kan de beheerder het spel starten.';
		case 1:
			return 'Het wachten is op de verteller om een kaart te kiezen en daarbij een uitspraak te doen...';
		default:
			return 'De verteller heeft een kaart gekozen en geeft als uitspraak: <b>' + HtmlEncode(game.Story) + '</b>';
	}
}

function HtmlEncode(s) {
	return s.replace(/&/g, '&amp;').replace(/</, '&lt;').replace(/>/, '&gt;').replace(/\n|\r\n?/, '<br>');
}

function Display(id, condition) {
	const elem = document.getElementById(id);
	if (elem) elem.style.display = condition ? 'block' : 'none';
}

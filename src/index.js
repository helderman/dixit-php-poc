async function poll(gameId) {
	const players = document.getElementById('players');
	let draw = 0;
	for (;;) {
		const response = await fetch('json.php?game=' + encodeURIComponent(gameId) + '&draw=' + encodeURIComponent(draw));
		draw = 0;
		if (response.ok) {
			const game = await response.json();
			document.getElementById('story').innerHTML = DescribeStatus(game);
			let html = '';
			switch (game.Status) {
				case 3:
				case 4:
					const me = game.Players.filter(p => p.IsMe);
					const myVote = me.length > 0 ? me[0].Vote : 0;
					const ppp = game.Players.filter(p => !p.IsSt);
					const all = ppp.filter(p => p.Vote !== ppp[0].Vote).length == 0;
					const stPicks = game.VotingCards.filter(c => c.StPick);
					html += '<h2>Stemmen: ' + game.Players.filter(p => p.Vote !== 0).length + '</h2>';
					for (const card of game.VotingCards) {
						const pickers = game.Players.filter(p => p.Id == card.UserId);
						const pickerName = pickers.length > 0 ? pickers[0].FullName : "?";
						html += '<div class="player"><img ' +
							(card.Id == myVote ? 'class="voted"' : game.Status > 3 || game.IAmSt ? 'class=""' : 'onclick="vote(this, ' + gameId + ', ' + card.Id + ')"') +
							' src="img/card' +
							String(card.Id ?? '0').padStart(2, '0') +
							'.jpg"><h2>' + HtmlEncode(pickerName) + '</h2>';
						if (game.Status > 3) {
							const voters = game.Players.filter(p => p.Vote == card.Id);
							html += '<p>Kreeg stemmen van: ' +
								(voters.length > 0 ? HtmlEncode(voters.map(p => p.FullName).join(', ')) : '<i>niemand</i>') +
								'</p><p>';
							if (card.StPick) {
								html += 'Verteller krijgt ' + (voters.length > 0 && voters.length < 3 ? 3 : 0) + ' punten';
							}
							else {
								html += 'Aantal punten: ' +
									(pickers[0].Vote !== stPicks[0].Id ? 0 : all ? 2 : 3) +
									' + ' + voters.length;
							}
							html += '</p>';
						}
						html += '</div>\n';
					}
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
							'</h2>\n<div>\n';
							//'</h2>\n<p>Score: ' + player.Score + '</p>\n<div>\n';
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
			Display('voting', game.Status == 2 && (game.IAmMgr || game.IAmSt));
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
	if (confirm('Weet je zeker dat je deze speeltafel wilt afruimen?')) {
		await fetch('stop.php?game=' + encodeURIComponent(gameId));
	}
}

async function reshuffle(gameId) {
	await fetch('reshuffle.php?game=' + encodeURIComponent(gameId));
}

async function voting(gameId) {
	await fetch('voting.php?game=' + encodeURIComponent(gameId));
}

async function show(gameId) {
	await fetch('show.php?game=' + encodeURIComponent(gameId));
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

async function vote(img, gameId, cardId) {
	if (!img.classList.contains('voted')) {
		img.classList.add('voted');
		await fetch('vote.php?game=' + encodeURIComponent(gameId) + '&card=' + encodeURIComponent(cardId));
	}
}

function DescribeStatus(game) {
	const story = 'De verteller heeft een kaart gekozen en doet daarbij de uitspraak: <i>' + HtmlEncode(game.Story ?? '') + '</i><br>';
	switch (game.Status) {
		case 0:	// join
			return 'Zodra er 4 spelers zijn, dan kan de beheerder het spel starten.';
		case 1: // story
			return 'Het wachten is op de verteller om een kaart te kiezen en daarbij een uitspraak te doen.';
		case 2:	// pick
			return story + 'De andere spelers kiezen uit hun hand een kaart die past bij deze uitspraak.';
		case 3:	// vote
			return story + 'De andere spelers stemmen welke kaart volgens hen van de verteller is.';
		case 4:	// showdown
			return story + 'De beurt is voorbij. Alle spelers zien hieronder hoeveel punten ze gescoord hebben.';
		default:
			return 'Status = ' + game.Status;
	}
}

function HtmlEncode(s) {
	return s.replace(/&/g, '&amp;').replace(/</, '&lt;').replace(/>/, '&gt;').replace(/\n|\r\n?/, '<br>');
}

function Display(id, condition) {
	const elem = document.getElementById(id);
	if (elem) elem.style.display = condition ? 'initial' : 'none';
}

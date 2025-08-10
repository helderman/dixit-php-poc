async function poll(gameId) {
	const players = document.getElementById('players');
	let draw = 0;
	for (;;) {
		const response = await fetch('json.php?game=' + encodeURIComponent(gameId) + '&draw=' + encodeURIComponent(draw));
		draw = 0;
		if (response.ok) {
			const game = await response.json();
			document.getElementById('story').innerText = game.Story;
			let html = '';
			for (const player of game.Players) {
				const cards = player.Cards ?? [];
				if (game.Status > 0 && player.IsMe) {
					draw = 6 - cards.length;
				}
				html += '<div class="player"><h2';
				if (player.IsMe) html += ' class="me"';
				html += '>' + player.FullName +
					'</h2>\n<p>Score: ' + player.Score;
				if (player.IsSt) html += ' &mdash; <i>Verteller</i>';
				html += '</p>\n<div>\n';
				for (const card of cards) {
					html += '<img';
					if (card.IsPicked) html += ' class="picked"';
					html += ' src="img/card' +
						String(card.Id ?? '0').padStart(2, '0') +
						'.jpg">\n';
				}
				html += '</div>\n</div>';
			}
			if (players.innerHTML != html) players.innerHTML = html;
		}
		else {
			console.log(response);
		}
		await new Promise(r => setTimeout(r, 1000));   // sleep 1000 ms
	}
}

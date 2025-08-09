async function poll(gameId) {
	let draw = 0;
	for (;;) {
		const response = await fetch('json.php?game=' + encodeURIComponent(gameId)) + '&draw=' + encodeURIComponent(draw));
		draw = 0;
		if (response.ok) {
			const game = await response.json();
			document.getElementById('story').innerText = game.Story;
			for (const player of game.Players) {
				const cards = player.Cards ?? [];
				if (game.Status > 0 && player.IsMe) {
					draw = 6 - cards.length;
				}
				const div = document.getElementById('player' + player.Id);
				if (div) {
					div.innerHTML = '<p>Score: ' + player.Score + '</p>';
					for (const card of cards) {
						div.innerHTML +=
							'\n<img src="img/card' +
							String(card.Id ?? '0').padStart(2, '0') +
							'.jpg" width="40%" height="50%"' +
							(card.IsPicked ? ' class="picked">' : '>');
					}
				}
			}
		}
		else {
			console.log(response);
		}
		await new Promise(r => setTimeout(r, 1000));   // sleep 1000 ms
	}
}

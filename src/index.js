async function poll(gameId) {
	for (;;) {
		const response = await fetch('json.php?game=' + encodeURIComponent(gameId));
		if (response.ok) {
			const game = await response.json();
			document.getElementById('story').innerText = game.Story;
			for (const player of game.Players) {
				const div = document.getElementById('player' + player.Id);
				if (div) {
					div.innerHTML = '<p>Score: ' + player.Score + '</p>';
					if (player.Cards) {
						for (const card of player.Cards) {
							div.innerHTML += '\n<img src="img/card' + String(card.Id ?? '0').padStart(2, '0') + '.jpg" width="40%" height="50%">';
						}
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

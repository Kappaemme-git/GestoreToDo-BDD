CALL crea_utente('simone', 'pass_simone');
CALL crea_utente('francesco', 'pass_francesco');
CALL crea_utente('pluto', 'pass_pluto');
CALL crea_utente('paperino', 'pass_paperino');

CALL crea_todo(1, 'Compito BD', 'Preparare presentazione', CURRENT_DATE + 3, NULL, NULL, 'FFAABB');
CALL crea_todo(1, 'Ripasso SQL', 'JOIN e GROUP BY', CURRENT_DATE + 5, NULL, NULL, NULL);
CALL crea_todo(2, 'CV', 'Aggiornare CV', CURRENT_DATE + 10, NULL, NULL, NULL);
CALL crea_todo(3, 'Palestra', 'Allenamento serale', CURRENT_DATE + 1, NULL, NULL, NULL);

CALL crea_todo(4, 'Esercizi', 'Normalizzazione', CURRENT_DATE + 4, NULL, NULL, NULL);
CALL crea_todo(5, 'Task GUI', 'Fix bug interfaccia', CURRENT_DATE + 7, NULL, NULL, NULL);
CALL crea_todo(6, 'Spesa', 'Comprare roba per cena', CURRENT_DATE + 1, NULL, NULL, NULL);

CALL crea_todo(7, 'Reti', 'Ripasso TCP/UDP', CURRENT_DATE + 6, NULL, NULL, NULL);
CALL crea_todo(8, 'Turno', 'Preparare attività', CURRENT_DATE + 2, NULL, NULL, NULL);
CALL crea_todo(9, 'Highlights Inter-PSG', 'Riguardare highlights inter psg 0-5', CURRENT_DATE + 8, NULL, NULL, NULL);

CALL crea_todo(10, 'Appunti', 'Sistemare appunti lezioni', CURRENT_DATE + 5, NULL, NULL, NULL);
CALL crea_todo(11, 'Email', 'Rispondere ai messaggi', CURRENT_DATE + 2, NULL, NULL, NULL);
CALL crea_todo(12, 'Calcetto', 'Partita con amici', CURRENT_DATE + 4, NULL, NULL, NULL);

CALL condividi_todo(1, 'francesco', CURRENT_DATE);
CALL condividi_todo(1, 'pluto', CURRENT_DATE);

CALL condividi_todo(7, 'simone', CURRENT_DATE);

CALL condividi_todo(6, 'paperino', CURRENT_DATE);

CALL condividi_todo(12, 'simone', CURRENT_DATE);
CALL condividi_todo(12, 'francesco', CURRENT_DATE);
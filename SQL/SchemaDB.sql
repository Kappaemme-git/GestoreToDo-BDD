
DROP TRIGGER IF EXISTS trg_no_self_share ON condivisione;
DROP TRIGGER IF EXISTS trg_check_scadenza_insert ON todo;
DROP TRIGGER IF EXISTS trg_crea_bacheche ON utente;

DROP FUNCTION IF EXISTS check_no_self_share();
DROP FUNCTION IF EXISTS check_scadenza_insert();
DROP FUNCTION IF EXISTS crea_bacheche();

DROP FUNCTION IF EXISTS cerca_todo_per_titolo(VARCHAR, TEXT);
DROP FUNCTION IF EXISTS get_todo_completati(VARCHAR);
DROP FUNCTION IF EXISTS get_todo_scaduti(VARCHAR);
DROP FUNCTION IF EXISTS trova_todo_per_scadenza(VARCHAR, DATE);

DROP PROCEDURE IF EXISTS crea_utente;
DROP PROCEDURE IF EXISTS elimina_utente;
DROP PROCEDURE IF EXISTS crea_todo;
DROP PROCEDURE IF EXISTS aggiorna_todo;
DROP PROCEDURE IF EXISTS elimina_todo;
DROP PROCEDURE IF EXISTS sposta_todo_bacheca;
DROP PROCEDURE IF EXISTS cambia_posizione_todo;
DROP PROCEDURE IF EXISTS condividi_todo;
DROP PROCEDURE IF EXISTS rimuovi_condivisione;
DROP PROCEDURE IF EXISTS crea_bacheca;
DROP PROCEDURE IF EXISTS aggiorna_bacheca;
DROP PROCEDURE IF EXISTS elimina_bacheca;

DROP TABLE IF EXISTS condivisione;
DROP TABLE IF EXISTS todo;
DROP TABLE IF EXISTS bacheca;
DROP TABLE IF EXISTS utente;

DROP TYPE IF EXISTS status_todo;
DROP TYPE IF EXISTS tipo_bacheca;

-- ENUM

CREATE TYPE tipo_bacheca AS ENUM ('UNIVERSITA', 'LAVORO', 'TEMPO_LIBERO');
CREATE TYPE status_todo  AS ENUM ('COMPLETATO', 'NON_COMPLETATO');

-- TABELLE

CREATE TABLE utente (
  username VARCHAR(20) PRIMARY KEY,
  password VARCHAR(255) NOT NULL
);

CREATE TABLE bacheca (
  id SERIAL PRIMARY KEY,
  proprietario VARCHAR(20) NOT NULL REFERENCES utente(username) ON DELETE CASCADE,
  tipo tipo_bacheca NOT NULL,
  descrizione VARCHAR(50) NOT NULL DEFAULT '',
  UNIQUE (proprietario, tipo)
);

CREATE TABLE todo (
  id SERIAL PRIMARY KEY,
  bacheca_id INTEGER NOT NULL REFERENCES bacheca(id) ON DELETE CASCADE,
  data_scadenza DATE NULL,
  ordine INTEGER NOT NULL,
  stato status_todo NOT NULL DEFAULT 'NON_COMPLETATO',
  titolo VARCHAR(100) NULL,
  descrizione VARCHAR(255) NULL,
  url VARCHAR(255) NULL,
  immagine VARCHAR(255) NULL,
  colore VARCHAR(6) NULL,
  UNIQUE (bacheca_id, ordine)
);

CREATE TABLE condivisione (
  todo_id INTEGER NOT NULL REFERENCES todo(id) ON DELETE CASCADE,
  username VARCHAR(20) NOT NULL REFERENCES utente(username) ON DELETE CASCADE,
  dataCondivisione DATE NULL,
  PRIMARY KEY (todo_id, username)
);

-- TRIGGER: crea bacheche standard
CREATE OR REPLACE FUNCTION crea_bacheche()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO bacheca (proprietario, tipo, descrizione)
  VALUES
    (NEW.username, 'UNIVERSITA', 'Universita'),
    (NEW.username, 'LAVORO', 'Lavoro'),
    (NEW.username, 'TEMPO_LIBERO', 'Tempo Libero');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_crea_bacheche
AFTER INSERT ON utente
FOR EACH ROW
EXECUTE FUNCTION crea_bacheche();

-- TRIGGER: blocca insert con scadenza nel passato (solo INSERT)
CREATE OR REPLACE FUNCTION check_scadenza_insert()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.data_scadenza IS NOT NULL AND NEW.data_scadenza < CURRENT_DATE THEN
    RAISE EXCEPTION 'data_scadenza non puo essere nel passato';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_scadenza_insert
BEFORE INSERT ON todo
FOR EACH ROW
EXECUTE FUNCTION check_scadenza_insert();

-- TRIGGER: vieta self-share
CREATE OR REPLACE FUNCTION check_no_self_share()
RETURNS TRIGGER AS $$
DECLARE
  owner VARCHAR(20);
BEGIN
  SELECT b.proprietario
  INTO owner
  FROM todo t
  JOIN bacheca b ON t.bacheca_id = b.id
  WHERE t.id = NEW.todo_id;

  IF owner IS NULL THEN
    RAISE EXCEPTION 'Todo % non trovato', NEW.todo_id;
  END IF;

  IF NEW.username = owner THEN
    RAISE EXCEPTION 'Non puoi condividere un ToDo con te stesso (%).', owner;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_no_self_share
BEFORE INSERT ON condivisione
FOR EACH ROW
EXECUTE FUNCTION check_no_self_share();

-- VINCOLI CHECK
ALTER TABLE todo
  ADD CONSTRAINT check_lunghezza_titolo_todo
  CHECK (titolo IS NULL OR length(titolo) <= 100);

ALTER TABLE todo
  ADD CONSTRAINT check_lunghezza_descrizione_todo
  CHECK (descrizione IS NULL OR length(descrizione) <= 255);

-- FUNZIONI
CREATE OR REPLACE FUNCTION get_todo_scaduti(p_username VARCHAR(20))
RETURNS TABLE (
  todo_id INTEGER,
  titolo VARCHAR(100),
  data_scadenza DATE,
  tipo_bacheca tipo_bacheca,
  ordine INTEGER,
  stato status_todo
) AS $$
BEGIN
  RETURN QUERY
  SELECT t.id, t.titolo, t.data_scadenza, b.tipo, t.ordine, t.stato
  FROM todo t
  JOIN bacheca b ON b.id = t.bacheca_id
  LEFT JOIN condivisione c ON c.todo_id = t.id
  WHERE t.data_scadenza IS NOT NULL
    AND t.data_scadenza < CURRENT_DATE
    AND (b.proprietario = p_username OR c.username = p_username)
  ORDER BY t.data_scadenza, b.tipo, t.ordine;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_todo_completati(p_username VARCHAR(20))
RETURNS TABLE (
  todo_id INTEGER,
  titolo VARCHAR(100),
  data_scadenza DATE,
  tipo_bacheca tipo_bacheca,
  ordine INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT t.id, t.titolo, t.data_scadenza, b.tipo, t.ordine
  FROM todo t
  JOIN bacheca b ON b.id = t.bacheca_id
  LEFT JOIN condivisione c ON c.todo_id = t.id
  WHERE t.stato = 'COMPLETATO'
    AND (b.proprietario = p_username OR c.username = p_username)
  ORDER BY b.tipo, t.ordine;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trova_todo_per_scadenza(
  p_username VARCHAR(20),
  p_data_limite DATE
)
RETURNS TABLE (
  todo_id INTEGER,
  titolo VARCHAR(100),
  data_scadenza DATE,
  tipo_bacheca tipo_bacheca,
  ordine INTEGER,
  stato status_todo
) AS $$
BEGIN
  RETURN QUERY
  SELECT t.id, t.titolo, t.data_scadenza, b.tipo, t.ordine, t.stato
  FROM todo t
  JOIN bacheca b ON b.id = t.bacheca_id
  LEFT JOIN condivisione c ON c.todo_id = t.id
  WHERE t.data_scadenza IS NOT NULL
    AND t.data_scadenza <= p_data_limite
    AND (b.proprietario = p_username OR c.username = p_username)
  ORDER BY t.data_scadenza, b.tipo, t.ordine;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cerca_todo_per_titolo(
  p_username VARCHAR(20),
  p_query TEXT
)
RETURNS TABLE (
  todo_id INTEGER,
  titolo VARCHAR(100),
  data_scadenza DATE,
  tipo_bacheca tipo_bacheca,
  ordine INTEGER,
  stato status_todo
) AS $$
BEGIN
  RETURN QUERY
  SELECT t.id, t.titolo, t.data_scadenza, b.tipo, t.ordine, t.stato
  FROM todo t
  JOIN bacheca b ON b.id = t.bacheca_id
  LEFT JOIN condivisione c ON c.todo_id = t.id
  WHERE (b.proprietario = p_username OR c.username = p_username)
    AND t.titolo IS NOT NULL
    AND t.titolo ILIKE '%' || p_query || '%'
  ORDER BY b.tipo, t.ordine;
END;
$$ LANGUAGE plpgsql;


-- PROCEDURE
CREATE OR REPLACE PROCEDURE crea_utente(p_username VARCHAR(20), p_password VARCHAR(255))
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO utente(username, password)
  VALUES (p_username, p_password);
END;
$$;

CREATE OR REPLACE PROCEDURE elimina_utente(p_username VARCHAR(20))
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM utente WHERE username = p_username;
END;
$$;

CREATE OR REPLACE PROCEDURE crea_todo(
  p_bacheca_id INTEGER,
  p_titolo VARCHAR(100),
  p_descrizione VARCHAR(255),
  p_data_scadenza DATE,
  p_url VARCHAR(255),
  p_immagine VARCHAR(255),
  p_colore VARCHAR(6)
)
LANGUAGE plpgsql AS $$
DECLARE
  new_ordine INTEGER;
BEGIN
  SELECT COALESCE(MAX(ordine), 0) + 1
  INTO new_ordine
  FROM todo
  WHERE bacheca_id = p_bacheca_id;

  INSERT INTO todo (bacheca_id, ordine, titolo, descrizione, data_scadenza, url, immagine, colore)
  VALUES (p_bacheca_id, new_ordine, p_titolo, p_descrizione, p_data_scadenza, p_url, p_immagine, p_colore);
END;
$$;

CREATE OR REPLACE PROCEDURE aggiorna_todo(
  p_todo_id INTEGER,
  p_titolo VARCHAR(100),
  p_descrizione VARCHAR(255),
  p_data_scadenza DATE,
  p_url VARCHAR(255),
  p_immagine VARCHAR(255),
  p_colore VARCHAR(6),
  p_stato status_todo
)
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE todo
  SET titolo = p_titolo,
      descrizione = p_descrizione,
      data_scadenza = p_data_scadenza,
      url = p_url,
      immagine = p_immagine,
      colore = p_colore,
      stato = p_stato
  WHERE id = p_todo_id;
END;
$$;

CREATE OR REPLACE PROCEDURE elimina_todo(p_todo_id INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM todo WHERE id = p_todo_id;
END;
$$;

CREATE OR REPLACE PROCEDURE sposta_todo_bacheca(
  p_todo_id INTEGER,
  p_nuova_bacheca_id INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
  new_ordine INTEGER;
BEGIN
  SELECT COALESCE(MAX(ordine), 0) + 1
  INTO new_ordine
  FROM todo
  WHERE bacheca_id = p_nuova_bacheca_id;

  UPDATE todo
  SET bacheca_id = p_nuova_bacheca_id,
      ordine = new_ordine
  WHERE id = p_todo_id;
END;
$$;

CREATE OR REPLACE PROCEDURE cambia_posizione_todo(
  p_todo_id INTEGER,
  p_nuovo_ordine INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
  v_bacheca_id INTEGER;
  v_old_ordine INTEGER;
BEGIN
  SELECT bacheca_id, ordine
  INTO v_bacheca_id, v_old_ordine
  FROM todo
  WHERE id = p_todo_id;

  IF v_bacheca_id IS NULL THEN
    RAISE EXCEPTION 'Todo % non trovato', p_todo_id;
  END IF;

  IF p_nuovo_ordine < 1 THEN
    RAISE EXCEPTION 'Nuovo ordine deve essere >= 1';
  END IF;

  IF p_nuovo_ordine = v_old_ordine THEN
    RETURN;
  END IF;

  UPDATE todo SET ordine = -1 WHERE id = p_todo_id;

  IF p_nuovo_ordine < v_old_ordine THEN
    UPDATE todo
    SET ordine = ordine + 1
    WHERE bacheca_id = v_bacheca_id
      AND ordine >= p_nuovo_ordine
      AND ordine < v_old_ordine;
  ELSE
    UPDATE todo
    SET ordine = ordine - 1
    WHERE bacheca_id = v_bacheca_id
      AND ordine > v_old_ordine
      AND ordine <= p_nuovo_ordine;
  END IF;

  UPDATE todo SET ordine = p_nuovo_ordine WHERE id = p_todo_id;
END;
$$;

CREATE OR REPLACE PROCEDURE condividi_todo(
  p_todo_id INTEGER,
  p_username VARCHAR(20),
  p_dataCondivisione DATE
)
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO condivisione(todo_id, username, dataCondivisione)
  VALUES (p_todo_id, p_username, p_dataCondivisione);
END;
$$;

CREATE OR REPLACE PROCEDURE rimuovi_condivisione(
  p_todo_id INTEGER,
  p_username VARCHAR(20)
)
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM condivisione
  WHERE todo_id = p_todo_id
    AND username = p_username;
END;
$$;

CREATE OR REPLACE PROCEDURE crea_bacheca(
  p_proprietario VARCHAR(20),
  p_tipo tipo_bacheca,
  p_descrizione VARCHAR(50)
)
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO bacheca(proprietario, tipo, descrizione)
  VALUES (p_proprietario, p_tipo, COALESCE(p_descrizione, ''));
END;
$$;

CREATE OR REPLACE PROCEDURE aggiorna_bacheca(
  p_bacheca_id INTEGER,
  p_descrizione VARCHAR(50)
)
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE bacheca
  SET descrizione = COALESCE(p_descrizione, '')
  WHERE id = p_bacheca_id;
END;
$$;

CREATE OR REPLACE PROCEDURE elimina_bacheca(p_bacheca_id INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM bacheca WHERE id = p_bacheca_id;
END;
$$;
--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.6
-- Dumped by pg_dump version 9.5.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

SET search_path = public, pg_catalog;

ALTER TABLE ONLY public.person DROP CONSTRAINT person_pkey;
DROP TABLE public.person;
DROP EXTENSION plpgsql;
DROP SCHEMA public;
--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: person; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE person (
	idperson integer NOT NULL,
	firstname text NOT NULL,
	lastname text NOT NULL,
	birthdate date
);


ALTER TABLE person OWNER TO postgres;

--
-- Data for Name: person; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY person (idperson, firstname, lastname, birthdate) FROM stdin;
\.


--
-- Name: person_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY person
ADD CONSTRAINT person_pkey PRIMARY KEY (idperson);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--  http://solaimurugan.blogspot.com/2010/08/cross-database-triggers-in-postgresql.html
--

DROP DATABASE IF EXISTS db1;
DROP DATABASE IF EXISTS db2;

CREATE DATABASE db1;
CREATE DATABASE db2;

\c db1 

CREATE TABLE Person (
	IdPerson INT PRIMARY KEY     ,
	FirstName           TEXT    NOT NULL,
	LastName            TEXT     NOT NULL,
	BirthDate DATE
);


\c db2

CREATE TABLE People (
	IdPerson INT PRIMARY KEY     ,
	Name TEXT NOT NULL,
	BirthDate DATE
);

\c db1

-- Master-slave replication

CREATE EXTENSION dblink;

CREATE OR REPLACE FUNCTION fn_remote_1() RETURNS TRIGGER AS $body$
DECLARE
_sql text;
BEGIN
--	SET LOCAL session_replication_role = 'replica';
	PERFORM dblink_connect('dbname=db2');
	PERFORM DBLINK_EXEC('ALTER TABLE People DISABLE TRIGGER USER');
	IF TG_OP = 'INSERT' THEN
		PERFORM
		DBLINK_EXEC('dbname=db2','INSERT INTO People VALUES ('||new.IdPerson||','''||CONCAT(new.FirstName,' ',new.LastName)||''', '''||new.BirthDate||''')');
	ELSIF TG_OP = 'UPDATE' THEN
		_sql := 
		'UPDATE People SET Name='''||CONCAT(new.FirstName,' ',new.LastName)||''',BirthDate='''||new.BirthDate||''' WHERE IdPerson='||OLD.IdPerson||'';
		PERFORM DBLINK_EXEC(_sql);
	ELSIF TG_OP = 'DELETE' THEN
		_sql := format('
			DELETE FROM People 
			WHERE  IdPerson = %s;'
			, (OLD.IdPerson)::text);
		PERFORM DBLINK_EXEC(_sql);
	ELSE
		RAISE 'Trigger error on operation %', TG_OP;
END IF;
	PERFORM DBLINK_EXEC('ALTER TABLE People ENABLE TRIGGER USER');
PERFORM dblink_disconnect();
RETURN NEW;
END;
$body$ LANGUAGE 'plpgsql';


CREATE TRIGGER TASK_EVERYONE AFTER INSERT OR UPDATE OR DELETE 
ON Person FOR EACH ROW
--WHEN (current_setting('session_replication_role') <> 'replica')
EXECUTE PROCEDURE fn_remote_1();

\c db1

-- Tests for master-slave repliaction

INSERT INTO Person (IdPerson, FirstName, LastName, BirthDate) VALUES (1, 'Michael', 'Jordan', to_date('1963-09-01', 'YYYY-MM-DD'));
INSERT INTO Person (IdPerson, FirstName, LastName, BirthDate) VALUES (2, 'Jessica', 'Albo', to_date('1983-12-01', 'YYYY-MM-DD'));
INSERT INTO Person (IdPerson, FirstName, LastName, BirthDate) VALUES (3, 'Roman', 'Polanski', to_date('1992-12-01', 'YYYY-MM-DD'));

UPDATE Person SET LastName = 'Smith' WHERE IdPerson=1;
DELETE FROM Person WHERE IdPerson='2';
DELETE FROM Person WHERE IdPerson=1;

INSERT INTO Person (IdPerson, FirstName, LastName, BirthDate) VALUES (1, 'Grace', 'Kelly', to_date('1963-09-01', 'YYYY-MM-DD'));
INSERT INTO Person (IdPerson, FirstName, LastName, BirthDate) VALUES (2, 'John', 'Kennedy', to_date('1983-12-01', 'YYYY-MM-DD'));

-- Master-master replication

\connect db1
SELECT * FROM Person;
\connect db2
SELECT * FROM People;

\connect db2

CREATE EXTENSION dblink;

CREATE OR REPLACE FUNCTION fn_remote_2() RETURNS TRIGGER AS $body2$
DECLARE
_sql text;
BEGIN
--	SET LOCAL session_replication_role = 'replica';
	PERFORM dblink_connect('dbname=db1');
	PERFORM dblink_exec('ALTER TABLE Person DISABLE TRIGGER USER');
	IF TG_OP = 'INSERT' THEN
		PERFORM DBLINK_EXEC('INSERT INTO Person VALUES ('||new.IdPerson||','''||split_part(new.Name, ' ',1)||''','''||split_part(new.Name, ' ',2)||''', '''||new.BirthDate||''')');
	ELSIF TG_OP = 'UPDATE' THEN
		_sql := 
		'UPDATE Person SET FirstName='''||split_part(new.Name,' ',1)||''',LastName='''||split_part(new.Name,' ',2)||''',BirthDate='''||new.BirthDate||''' WHERE IdPerson='||OLD.IdPerson||'';
		PERFORM dblink_exec(_sql);
	ELSIF TG_OP = 'DELETE' THEN
		_sql := format('
			DELETE FROM Person 
			WHERE  IdPerson = %s;'
			, (OLD.IdPerson)::text);
		PERFORM dblink_exec(_sql);
	ELSE
		RAISE 'Trigger error on operation %', TG_OP;
END IF;
	PERFORM dblink_exec('ALTER TABLE Person ENABLE TRIGGER USER');
PERFORM dblink_disconnect();
RETURN NEW;
END;
$body2$ LANGUAGE 'plpgsql';

CREATE TRIGGER TASK_ADDITIONAL AFTER INSERT OR UPDATE OR DELETE 
ON People FOR ROW
--WHEN (current_setting('session_replication_role') <> 'replica')
EXECUTE PROCEDURE fn_remote_2();

-- Tests for master-master repliaction

INSERT INTO People (IdPerson, Name, BirthDate) VALUES (4, 'Raymond Tusk', to_date('1944-09-01', 'YYYY-MM-DD'));
INSERT INTO People (IdPerson, Name, BirthDate) VALUES (5, 'Charlie Chaplin', to_date('1944-09-01', 'YYYY-MM-DD'));

UPDATE People SET Name = 'John Smith' WHERE IdPerson=1;
DELETE FROM People WHERE IdPerson='2';

\connect db1
SELECT * FROM Person;
\connect db2
SELECT * FROM People;


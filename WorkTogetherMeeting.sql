--
-- PostgreSQL database dump
--

-- Dumped from database version 13.2
-- Dumped by pg_dump version 13.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: addmeeting(character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.addmeeting(course character varying, description character varying, createdby character varying, startdate timestamp without time zone, enddate timestamp without time zone, maxlimit integer, minlimit integer, location character varying)
    LANGUAGE plpgsql
    AS $$

/*coalesce (minlimit,(SELECT cast(column_default as integer)
FROM information_schema.columns
WHERE (table_name,column_name) = ('meeting','minlimit')))*/

declare meetingowner varchar(50) = null;
declare status varchar(10) = 'hidden';
Begin
IF createdby <> 'FSR:IF' then
	set meetingowner = createdby;
	set status = 'shown';
END IF;
perform minlimit = coalesce(minlimit,(SELECT cast(column_default as integer)
FROM information_schema.columns
WHERE (table_name,column_name) = ('meeting','minlimit'))), maxlimit = coalesce(maxlimit,10000);
IF maxlimit >= minlimit and startdate > Current_Timestamp and enddate > startdate then
insert into meeting (course,description,createdby,startdate,enddate,maxlimit,minlimit,location,meetingowner)
		values (course,description,createdby,startdate,enddate,maxlimit,minlimit,location,meetingowner);
END IF;
END;
$$;


ALTER PROCEDURE public.addmeeting(course character varying, description character varying, createdby character varying, startdate timestamp without time zone, enddate timestamp without time zone, maxlimit integer, minlimit integer, location character varying) OWNER TO postgres;

--
-- Name: addmeetingenrolled(integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.addmeetingenrolled(meetingid integer, studentid character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
	if studentid <> 'FSR:IF' then
		insert into meetingenrolled(meetingid,studentid) values (meetingid,studentid);
	end if;
END;
$$;


ALTER PROCEDURE public.addmeetingenrolled(meetingid integer, studentid character varying) OWNER TO postgres;

--
-- Name: addstudentinmeetingenrolled(integer, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.addstudentinmeetingenrolled(meeting_id integer, user_id character varying, perform_check character varying)
    LANGUAGE plpgsql
    AS $$
declare checkmeeting boolean = false;

begin
 checkmeeting := (select case when studentid = user_id then true end from meetingenrolled where studentid = user_id limit 1);
if perform_check = 'delete' then 
	delete from meetingenrolled where studentid = user_id and meetingid = meeting_id;
else
if checkmeeting = true then
	update meetingenrolled set meetingid = meeting_id,joineddate = current_timestamp where studentid = user_id;
else
	insert into meetingenrolled (meetingid,studentid) values (meeting_id,user_id);
end if;
end if;
end;
$$;


ALTER PROCEDURE public.addstudentinmeetingenrolled(meeting_id integer, user_id character varying, perform_check character varying) OWNER TO postgres;

--
-- Name: adduser(character varying, character varying, character varying, character varying, character varying, character varying, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.adduser(username character varying, firstname character varying, middlename character varying, lastname character varying, email character varying, password character varying, usertype boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
	insert into users (username,firstname,middlename,lastname,email,password,usertype) 
		values (username,firstname,middlename,lastname,email,password,usertype);
END;
$$;


ALTER PROCEDURE public.adduser(username character varying, firstname character varying, middlename character varying, lastname character varying, email character varying, password character varying, usertype boolean) OWNER TO postgres;

--
-- Name: checkmeetingowner(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.checkmeetingowner() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare new_meeting_owner varchar(30) = (select meetingowner from meeting where id = new.meetingid);
declare old_meeting_owner varchar(30) = (select mr.studentid from meetingenrolled mr inner join  meeting m on m.id = mr.meetingid
										 where m.id = old.meetingid and studentid <> coalesce(new.studentid,'') 
										 and m.meetingowner = old.studentid order by joineddate limit 1);
declare count_student integer = (select count(*) from meetingenrolled where meetingid = old.meetingid);
			
begin
if new_meeting_owner is null and new.meetingid is not null then
	update  meeting set meetingowner = coalesce(new.studentid,old.studentid) where id = new.meetingid;
elseif count_student = 0 then 
	delete from meeting where id = old.meetingid;
end if;
if new.meetingid <> old.meetingid or new.meetingid is null then
	update  meeting set meetingowner = old_meeting_owner where id = old.meetingid;
end if;
return new;
end;
$$;


ALTER FUNCTION public.checkmeetingowner() OWNER TO postgres;

--
-- Name: getemail(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.getemail(e_mail character varying) RETURNS TABLE(id integer, username character varying, firstname character varying, lastname character varying, email character varying, password character varying, usertype boolean)
    LANGUAGE plpgsql
    AS $$
begin
return query
	select * from tblusers u where u.username = e_mail;
end;
$$;


ALTER FUNCTION public.getemail(e_mail character varying) OWNER TO postgres;

--
-- Name: getmeeting(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.getmeeting(user_name character varying) RETURNS TABLE(id integer, course character varying, description character varying, startdate timestamp without time zone, enddate timestamp without time zone, maxlimit integer, minlimit integer, location character varying, status character varying, meetingowner character varying, studentnumber bigint, utype boolean)
    LANGUAGE plpgsql
    AS $$
declare stat boolean = (select usertype from tblusers where username = user_name);
begin
if stat = true then 
return query
	select 
		m.id,m.course,m.description,m.startdate,m.enddate,m.maxlimit,m.minlimit,m.location,m.status,
		m.meetingowner,count(me.id), case when u.usertype = true then true else false end utype
	from tblmeeting m left join tblmeetingenrolled me on m.id = me.meetingid left join tblusers u on u.username = m.meetingowner
group by m.id,m.course,m.description,m.startdate,m.enddate,m.maxlimit,m.minlimit,m.location,m.status,m.meetingowner, u.usertype;
else
return query

	select 
		m.id,m.course,m.description,m.startdate,m.enddate,m.maxlimit,m.minlimit,m.location,m.status,
		m.meetingowner,count(me.id), case when u.usertype = true then true else false end utype
	from tblmeeting m left join tblmeetingenrolled me on m.id = me.meetingid left join tblusers u on u.username = m.meetingowner
	where m.status = 'shown'
group by m.id,m.course,m.description,m.startdate,m.enddate,m.maxlimit,m.minlimit,m.location,m.status,m.meetingowner, u.usertype;
end if;
end;
$$;


ALTER FUNCTION public.getmeeting(user_name character varying) OWNER TO postgres;

--
-- Name: getstudent(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.getstudent(meeting_id integer) RETURNS TABLE(meetingid integer, studentid character varying, joineddate timestamp without time zone, firstname character varying, lastname character varying, email character varying)
    LANGUAGE plpgsql
    AS $$
begin
return query
	select
		me.meetingid, me.studentid,me.joineddate, u.firstname, u.lastname, u.email from
		tblmeetingenrolled me inner join tblusers u on u.username = me.studentid
		where me.meetingid = meeting_id;
end;
$$;


ALTER FUNCTION public.getstudent(meeting_id integer) OWNER TO postgres;

--
-- Name: getuser(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.getuser(user_name character varying) RETURNS TABLE(id integer, username character varying, firstname character varying, lastname character varying, email character varying, password character varying, usertype boolean)
    LANGUAGE plpgsql
    AS $$
begin
return query
	select * from tblusers u where u.username = user_name;
end;
$$;


ALTER FUNCTION public.getuser(user_name character varying) OWNER TO postgres;

--
-- Name: meetingaddition(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.meetingaddition() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
if new.createdby <> 'FSR:IF' then
	insert into meetingenrolled (meetingid,studentid) 
		values (new.id,new.createdby);
end if;
return new;
end;
$$;


ALTER FUNCTION public.meetingaddition() OWNER TO postgres;

--
-- Name: proc_action_meeting_enrolled(integer, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.proc_action_meeting_enrolled(meeting_id integer, user_id character varying, perform_check character varying)
    LANGUAGE plpgsql
    AS $$
declare checkmeeting boolean = false;
declare studentno integer = (select count(*) from tblmeetingenrolled where meetingid = meeting_id);
declare maxlimit integer = (select maxlimit from tblmeeting where id = meeting_id);
declare end_date timestamp = (select enddate from tblmeeting where id = meeting_id);
begin
 checkmeeting := (select case when studentid = user_id then true end from tblmeetingenrolled where studentid = user_id limit 1);
if perform_check = 'delete' then 
	delete from tblmeetingenrolled where studentid = user_id and meetingid = meeting_id;
else
if end_date < current_timestamp then
	update tblmeeting set status = 'hidden' where id = meeting_id;
elseif checkmeeting = true and maxlimit > studentno then
	update tblmeetingenrolled set meetingid = meeting_id,joineddate = current_timestamp where studentid = user_id;
elseif maxlimit > studentno then
	insert into tblmeetingenrolled (meetingid,studentid) values (meeting_id,user_id);
end if;
end if;
end;
$$;


ALTER PROCEDURE public.proc_action_meeting_enrolled(meeting_id integer, user_id character varying, perform_check character varying) OWNER TO postgres;

--
-- Name: proc_add_user(character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.proc_add_user(user_name character varying, pass_word character varying)
    LANGUAGE plpgsql
    AS $$
begin
	update tblusers set password = pass_word where username = user_name;
end;
$$;


ALTER PROCEDURE public.proc_add_user(user_name character varying, pass_word character varying) OWNER TO postgres;

--
-- Name: proc_add_user(character varying, character varying, character varying, character varying, character varying, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.proc_add_user(user_name character varying, first_name character varying, last_name character varying, e_mail character varying, pass_word character varying, user_type boolean)
    LANGUAGE plpgsql
    AS $$
begin
	insert into tblusers (username,firstname,lastname,email,password,usertype)
		values (user_name,first_name,last_name,e_mail,pass_word,user_type);
end;
$$;


ALTER PROCEDURE public.proc_add_user(user_name character varying, first_name character varying, last_name character varying, e_mail character varying, pass_word character varying, user_type boolean) OWNER TO postgres;

--
-- Name: proc_add_user(character varying, character varying, character varying, character varying, character varying, character varying, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.proc_add_user(user_name character varying, first_name character varying, middle_name character varying, last_name character varying, e_mail character varying, pass_word character varying, user_type boolean)
    LANGUAGE plpgsql
    AS $$
begin
	insert into tblusers (username,firstname,middlename,lastname,email,password,usertype)
		values (user_name,first_name,middle_name,last_name,e_mail,pass_word,user_type);
end;
$$;


ALTER PROCEDURE public.proc_add_user(user_name character varying, first_name character varying, middle_name character varying, last_name character varying, e_mail character varying, pass_word character varying, user_type boolean) OWNER TO postgres;

--
-- Name: proc_addmeeting(character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.proc_addmeeting(cour character varying, descript character varying, created_by character varying, start_date timestamp without time zone, end_date timestamp without time zone, max_limit integer, min_limit integer, locat character varying)
    LANGUAGE plpgsql
    AS $$

declare meeting_owner varchar(30) := (select case usertype when true then null else created_by end from tblusers where username = created_by);
declare status varchar(10) := (select case usertype when true then 'hidden' else 'shown' end from tblusers where username = created_by);
Begin
perform min_limit = coalesce(min_limit,2), max_limit = coalesce(max_limit,10000);
IF max_limit >= min_limit and start_date > Current_Timestamp and end_date > start_date then
insert into tblmeeting (course,description,createdby,startdate,enddate,maxlimit,minlimit,location,meetingowner,status)
		values (cour,descript,created_by,start_date,end_date,max_limit,min_limit,locat,meeting_owner,status);
END IF;
END;
$$;


ALTER PROCEDURE public.proc_addmeeting(cour character varying, descript character varying, created_by character varying, start_date timestamp without time zone, end_date timestamp without time zone, max_limit integer, min_limit integer, locat character varying) OWNER TO postgres;

--
-- Name: proc_change_password(character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.proc_change_password(user_name character varying, pass_word character varying)
    LANGUAGE plpgsql
    AS $$
begin
	update tblusers set password = pass_word where username = user_name;
end;
$$;


ALTER PROCEDURE public.proc_change_password(user_name character varying, pass_word character varying) OWNER TO postgres;

--
-- Name: proc_delete_meeting(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.proc_delete_meeting(meeting_id integer)
    LANGUAGE plpgsql
    AS $$
begin
	delete from tblmeeting where id = meeting_id;
end;
$$;


ALTER PROCEDURE public.proc_delete_meeting(meeting_id integer) OWNER TO postgres;

--
-- Name: proc_toggle_meeting(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.proc_toggle_meeting(meeting_id integer)
    LANGUAGE plpgsql
    AS $$
declare stat varchar(10) = (select case when status = 'shown' then 'hidden' else 'shown' end from tblmeeting where id = meeting_id);
begin
	update tblmeeting set status = stat where id = meeting_id ;
end;
$$;


ALTER PROCEDURE public.proc_toggle_meeting(meeting_id integer) OWNER TO postgres;

--
-- Name: proc_update_meeting(integer, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.proc_update_meeting(meeting_id integer, cour character varying, descript character varying, start_date timestamp without time zone, end_date timestamp without time zone, max_limit integer, min_limit integer, locat character varying)
    LANGUAGE plpgsql
    AS $$
begin
	update tblmeeting set course = cour, description = descript,
	startdate = start_date, enddate = end_date, maxlimit = max_limit, minlimit = min_limit,
	location = locat where id = meeting_id;
end;
$$;


ALTER PROCEDURE public.proc_update_meeting(meeting_id integer, cour character varying, descript character varying, start_date timestamp without time zone, end_date timestamp without time zone, max_limit integer, min_limit integer, locat character varying) OWNER TO postgres;

--
-- Name: proc_update_meeting(integer, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.proc_update_meeting(meeting_id integer, cour character varying, descript character varying, user_name character varying, start_date timestamp without time zone, end_date timestamp without time zone, max_limit integer, min_limit integer, locat character varying)
    LANGUAGE plpgsql
    AS $$
begin
	update tblmeeting set course = cour, description = descript, createdby = user_name,
	startdate = start_date, enddate = end_date, maxlimit = max_limit, minlimit = min_limit,
	location = locat where id = meeting_id;
end;
$$;


ALTER PROCEDURE public.proc_update_meeting(meeting_id integer, cour character varying, descript character varying, user_name character varying, start_date timestamp without time zone, end_date timestamp without time zone, max_limit integer, min_limit integer, locat character varying) OWNER TO postgres;

--
-- Name: trig_fun_action_meeting_enrolled(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trig_fun_action_meeting_enrolled() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare new_meeting_owner varchar(30) = (select meetingowner from tblmeeting where id = new.meetingid);
declare old_meeting_owner varchar(30) = (select mr.studentid from tblmeetingenrolled mr inner join  tblmeeting m on m.id = mr.meetingid
										 where m.id = old.meetingid and studentid <> coalesce(new.studentid,'') 
										 and m.meetingowner = old.studentid order by joineddate limit 1);
declare count_student integer = (select count(*) from tblmeetingenrolled where meetingid = old.meetingid);
			
begin
if new_meeting_owner is null and new.meetingid is not null then
	update tblmeeting set meetingowner = coalesce(new.studentid,old.studentid) where id = new.meetingid;
elseif count_student = 0 then 
	delete from tblmeeting where id = old.meetingid;
end if;
if new.meetingid <> old.meetingid or new.meetingid is null then
	update tblmeeting set meetingowner = old_meeting_owner where id = old.meetingid;
end if;
return new;
end;
$$;


ALTER FUNCTION public.trig_fun_action_meeting_enrolled() OWNER TO postgres;

--
-- Name: trig_fun_add_meeting(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trig_fun_add_meeting() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare check_value boolean = (select usertype from tblusers where username = new.createdby);
declare new_value varchar(30) = (select studentid from tblmeetingenrolled where studentid = new.createdby limit 1);
BEGIN
if check_value = false and new_value is null then
	insert into tblmeetingenrolled (meetingid,studentid) 
		values (new.id,new.createdby);
elseif check_value = false then
	update tblmeetingenrolled set meetingid = new.id where studentid = new.createdby;
end if;
return new;
end;
$$;


ALTER FUNCTION public.trig_fun_add_meeting() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: tblmeeting; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblmeeting (
    id integer NOT NULL,
    course character varying(50) NOT NULL,
    description character varying(1000) NOT NULL,
    createdby character varying(30) NOT NULL,
    startdate timestamp without time zone NOT NULL,
    enddate timestamp without time zone NOT NULL,
    maxlimit integer DEFAULT 10000,
    minlimit integer DEFAULT 2,
    location character varying(70) NOT NULL,
    status character varying(10) DEFAULT 'hidden'::character varying,
    meetingowner character varying(30),
    CONSTRAINT tblmeeting_check CHECK ((startdate < enddate)),
    CONSTRAINT tblmeeting_check1 CHECK ((maxlimit >= minlimit))
);


ALTER TABLE public.tblmeeting OWNER TO postgres;

--
-- Name: tblmeeting_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tblmeeting_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblmeeting_id_seq OWNER TO postgres;

--
-- Name: tblmeeting_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tblmeeting_id_seq OWNED BY public.tblmeeting.id;


--
-- Name: tblmeetingenrolled; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblmeetingenrolled (
    id integer NOT NULL,
    meetingid integer NOT NULL,
    studentid character varying(30) NOT NULL,
    joineddate timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.tblmeetingenrolled OWNER TO postgres;

--
-- Name: tblmeetingenrolled_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tblmeetingenrolled_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblmeetingenrolled_id_seq OWNER TO postgres;

--
-- Name: tblmeetingenrolled_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tblmeetingenrolled_id_seq OWNED BY public.tblmeetingenrolled.id;


--
-- Name: tblusers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblusers (
    id integer NOT NULL,
    username character varying(30),
    firstname character varying(30) NOT NULL,
    lastname character varying(30) NOT NULL,
    email character varying(50),
    password character varying(60) NOT NULL,
    usertype boolean DEFAULT false
);


ALTER TABLE public.tblusers OWNER TO postgres;

--
-- Name: tblusers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tblusers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblusers_id_seq OWNER TO postgres;

--
-- Name: tblusers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tblusers_id_seq OWNED BY public.tblusers.id;


--
-- Name: tblmeeting id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmeeting ALTER COLUMN id SET DEFAULT nextval('public.tblmeeting_id_seq'::regclass);


--
-- Name: tblmeetingenrolled id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmeetingenrolled ALTER COLUMN id SET DEFAULT nextval('public.tblmeetingenrolled_id_seq'::regclass);


--
-- Name: tblusers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblusers ALTER COLUMN id SET DEFAULT nextval('public.tblusers_id_seq'::regclass);


--
-- Data for Name: tblmeeting; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblmeeting (id, course, description, createdby, startdate, enddate, maxlimit, minlimit, location, status, meetingowner) FROM stdin;
22	scienc	data	FSR	2021-05-31 06:02:00	2021-05-31 17:01:00	5	2	Chemnitz	hidden	somanpradhan
28	Science	dah	pradhansoman	2021-05-31 17:54:00	2021-06-01 18:59:00	5	2	Chemnitz	shown	pradhansoman
\.


--
-- Data for Name: tblmeetingenrolled; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblmeetingenrolled (id, meetingid, studentid, joineddate) FROM stdin;
7	22	somanpradhan	2021-05-30 19:38:37.349789
13	28	pradhansoman	2021-05-30 23:51:54.502533
\.


--
-- Data for Name: tblusers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblusers (id, username, firstname, lastname, email, password, usertype) FROM stdin;
1	pradhansoman	soman	pradhan	somanpradhan13@gmail.com	$2b$12$YyFVchELT6y2yXyYehGGl.Pwq7w6/XcfgBJmzEz/K.CAAvxisUWRO	f
2	somanpradhan	soman	pradhan	somanpradhan92@gmail.com	$2b$12$IGer7tXHbdX8SK4n/AIaU.jxMhf7ih/sm2vQY5S2R8xrgwlmOUnoy	f
3	FSR	Fachschaftsrat	Informatik	fachschaftsratinformatik@something.de	$2b$12$iKnIwToKe3vUSOP9ULKvQ.BdkxQvwzukD0Hlf1l968FqXQgas0rnK	t
\.


--
-- Name: tblmeeting_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tblmeeting_id_seq', 28, true);


--
-- Name: tblmeetingenrolled_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tblmeetingenrolled_id_seq', 13, true);


--
-- Name: tblusers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tblusers_id_seq', 3, true);


--
-- Name: tblmeeting tblmeeting_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmeeting
    ADD CONSTRAINT tblmeeting_pkey PRIMARY KEY (id);


--
-- Name: tblmeetingenrolled tblmeetingenrolled_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmeetingenrolled
    ADD CONSTRAINT tblmeetingenrolled_pkey PRIMARY KEY (id);


--
-- Name: tblusers tblusers_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblusers
    ADD CONSTRAINT tblusers_email_key UNIQUE (email);


--
-- Name: tblusers tblusers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblusers
    ADD CONSTRAINT tblusers_pkey PRIMARY KEY (id);


--
-- Name: tblusers tblusers_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblusers
    ADD CONSTRAINT tblusers_username_key UNIQUE (username);


--
-- Name: tblmeetingenrolled trig_action_meeting_enrolled; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trig_action_meeting_enrolled AFTER INSERT OR DELETE OR UPDATE ON public.tblmeetingenrolled FOR EACH ROW EXECUTE FUNCTION public.trig_fun_action_meeting_enrolled();


--
-- Name: tblmeeting trig_add_meeting; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trig_add_meeting AFTER INSERT ON public.tblmeeting FOR EACH ROW EXECUTE FUNCTION public.trig_fun_add_meeting();


--
-- Name: tblmeeting fk_createdby; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmeeting
    ADD CONSTRAINT fk_createdby FOREIGN KEY (createdby) REFERENCES public.tblusers(username) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tblmeetingenrolled fk_meetingid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmeetingenrolled
    ADD CONSTRAINT fk_meetingid FOREIGN KEY (meetingid) REFERENCES public.tblmeeting(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tblmeetingenrolled fk_studentid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmeetingenrolled
    ADD CONSTRAINT fk_studentid FOREIGN KEY (studentid) REFERENCES public.tblusers(username) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--


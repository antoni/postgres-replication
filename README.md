# Master-master replication in PostgreSQL
An attempt to create a master-master replication in PostgreSQL using
[dblink extension](https://www.postgresql.org/docs/9.4/static/contrib-dblink-function.html) and triggers.
It was just an exercise and should not be (nor it was intended to be) used in production. There are existing, mature solutions to be used for such needs, like [Postgres-BDR](https://www.2ndquadrant.com/en/resources/bdr/) and [Bucardo](https://bucardo.org/wiki/Bucardo/Documentation/Overview).
## Usage
Execute: `psql < mm_replication.sql`


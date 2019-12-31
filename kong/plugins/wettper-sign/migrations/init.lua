return {
    postgres = {
        up = [[
        CREATE TABLE IF NOT EXISTS "wettpersign_credentials" (
        "id" uuid NOT NULL,
        "created_at" timestamptz(6) DEFAULT timezone('UTC'::text, ('now'::text)::timestamp(0) with time zone),
        "consumer_id" uuid,
        "apikey" text COLLATE "pg_catalog"."default",
        "secret" text COLLATE "pg_catalog"."default",
        CONSTRAINT "wettpersign_credentials_pkey" PRIMARY KEY ("id"),
        CONSTRAINT "wettpersign_credentials_consumer_id_fkey" FOREIGN KEY ("consumer_id") REFERENCES "consumers" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT "wettpersign_credentials_apikey" UNIQUE ("apikey")
        );
        CREATE INDEX IF NOT EXISTS "wettpersign_credentials_consumer_id_idx" ON "wettpersign_credentials" USING btree (
        "consumer_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
        );
        ]],
    },
    cassandra = {
        up = [[
        ]],
    },
}

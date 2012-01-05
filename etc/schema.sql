CREATE TABLE "aria2" ("url_id" int not null PRIMARY KEY ,"gid" text NOT NULL ,"session_id" text NOT NULL );
CREATE TABLE "hltv" ("url_id" int not null PRIMARY KEY ,"hltv_id" int NOT NULL );
CREATE TABLE "urls" ("id" INTEGER PRIMARY KEY  NOT NULL ,"url" text unique NOT NULL ,"host" text NOT NULL ,"otr" int NOT NULL ,"state" int NOT NULL );

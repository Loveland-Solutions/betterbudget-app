# Two or more computers on one ledger: the expert reports (2026-10-12)

Why: the owner, told that five kinds of conflict still asked "which whole ledger
do you want to keep", said "I don't want them to have to make this decision. We
need to make a way where entries are ingested without replacing the entire
database", proposed a master database with a local child copy and a lock file,
and asked for experts to weigh in and come up with a reliable solution.

Four were briefed with the same text (`brief.md`) and read the same code
(`app/lib/domain/combine.dart`, `app/lib/data/cloud_folder.dart`,
`app/lib/domain/sync.dart`, ADR 0005 "More than one computer on one ledger"):

- [distributed-systems.md](distributed-systems.md): replication over a sync
  folder with no server and no trusted clock.
- [sqlite.md](sqlite.md): what the database itself can record; whether the
  session extension is in the build this app links (it is).
- [folder-sync-practitioner.md](folder-sync-practitioner.md): what products that
  sync through Drive and Dropbox folders settled on, and what their sync clients
  really do.
- [money.md](money.md): for each kind of conflict, which answer is safe for a
  household's books, which can be settled by a rule, which must be asked.

Where they agree, where they differ, and what was chosen is in ADR 0005
("Two computers: the way chosen 2026-10-12" once the owner has picked).

-- actually stores the 512-byte hashes
CREATE TABLE hash (
  id INTEGER PRIMARY KEY,
  -- this would be the full hash, represented as base32 instead of bytes,
  -- to optimize for looking them up by prefix.
  base32 TEXT UNIQUE NOT NULL
);
CREATE INDEX hash_base32 ON hash(base32);

-- just came up with this, a layer of indirection to allow multiple hash_ids to
-- reference the same object.
-- so: SELECT object.id, bytes FROM object
--      INNER JOIN hash_object ON object_id = object.id
--      INNER JOIN hash ON hash_id = hash.id
--     WHERE base32 LIKE 'a1b2c3%'
CREATE TABLE hash_object (
  -- hashes are UNIQUE; many hashes correspond to one object
  -- (causal nodes are not considered objects atm)
  hash_id INTEGER PRIMARY KEY NOT NULL REFERENCES hash(id),
  object_id INTEGER NOT NULL REFERENCES object(id),
  hash_version INTEGER NOT NULL
);
CREATE INDEX hash_object_hash_id ON hash_object(hash_id);
CREATE INDEX hash_object_object_id ON hash_object(object_id);

-- this table is just documentation, it won't be used for joins.
CREATE TABLE object_type_description (
  id INTEGER UNIQUE NOT NULL,
  description TEXT UNIQUE NOT NULL
);
INSERT INTO object_type_description (id, description) VALUES
    (0, "Term Component"), -- foo x = x + 1
    (1, "Types of Term Component"), -- [Nat -> Nat]
    (2, "Decl Component"), -- unique type Animal = Cat | Dog | Mouse
    (3, "Namespace"), -- a one-level slice
    (4, "Patch"), -- replace term #abc with term #def
    (5, "Local Text/Object Lookup")
    ;

-- How should objects be linked to hashes?  (and old hashes)
-- And which id should be linked into blobs?
--   a) object.id -- no: I ran into an issue in serializing a type annotation
--                   within a term; there wasn't enough info here to properly
--                   ser/des a type annotation that includes a self-ref, and I
--                   couldn't convince myself that the situation wouldn't come up
--   b) hash.id -- ~~no: multiple hashes may refer to one object~~
--              -- though, I guess that's true even when they are represented as
--              -- inline bytestrings.  so I'm going with this option.
--
CREATE TABLE object (
  id INTEGER PRIMARY KEY,
  primary_hash_id UNIQUE INTEGER NOT NULL REFERENCES hash(id),
  type_id INTEGER NOT NULL REFERENCES object_type_description(id),
  bytes BLOB NOT NULL
);
CREATE INDEX object_hash_id ON object(primary_hash_id);
CREATE INDEX object_type_id ON object(type_id);

-- `causal` references value hash ids instead of value ids, in case you want
-- to be able to drop values and keep just the causal spine.
-- to be able to drop values and keep just the causal spine.
-- This implementation keeps the hash of the dropped values, although I could
-- see an argument to drop them too and just use NULL, but I thought it better
-- to not lose their identities.
CREATE TABLE causal (
  self_hash_id INTEGER PRIMARY KEY NOT NULL REFERENCES hash(id),
  -- intentionally not object_id, see above
  value_hash_id INTEGER NOT NULL REFERENCES hash(id)
);

-- valueHash : Hash = hash(value)
-- db.saveValue(valueHash, value)
-- causalHash : Hash = hash(new Causal(valueHash, parentCausalHashes))
-- db.saveCausal(selfHash = causalHash, valueHash, parentCausalHashes)

CREATE TABLE causal_parent (
  id INTEGER PRIMARY KEY NOT NULL,
  causal_id INTEGER NOT NULL REFERENCES causal(self_hash_id),
  parent_id INTEGER NOT NULL REFERENCES causal(self_hash_id),
  UNIQUE(causal_id, parent_id)
);
CREATE INDEX causal_parent_causal_id ON causal_parent(causal_id);
CREATE INDEX causal_parent_parent_id ON causal_parent(parent_id);

-- associate old (e.g. v1) causal hashes with new causal hashes
CREATE TABLE causal_old (
  old_hash_id INTEGER PRIMARY KEY NOT NULL REFERENCES hash(id),
  new_hash_id INTEGER NOT NULL REFERENCES hash(id)
);

-- |Links a referent to its type's object
CREATE TABLE type_of_referent (
  object_id INTEGER NOT NULL REFERENCES object(id),
  component_index INTEGER NOT NULL,
  constructor_index INTEGER NULL,
  bytes BLOB NOT NULL,
  PRIMARY KEY (object_id, component_index, constructor_index)
);

--CREATE TABLE type_of_referent (
--  referent_derived_id INTEGER NOT NULL PRIMARY KEY REFERENCES referent_derived(id),
--  type_object_id INTEGER NOT NULL REFERENCES object(id)
--);
--CREATE INDEX type_of_referent_object_id ON type_of_referent(type_object_id);
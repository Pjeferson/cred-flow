CREATE TABLE IF NOT EXISTS spb_transactions (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  spb_transaction_id  TEXT NOT NULL UNIQUE,
  account_id          TEXT NOT NULL,
  payment_order_id    TEXT NOT NULL,
  amount_cents        INTEGER NOT NULL,
  settled_at          TEXT NOT NULL,
  status              TEXT NOT NULL DEFAULT 'settled'
);

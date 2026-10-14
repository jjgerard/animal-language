# Animal Language

A language-noticing activity: what do animals say around the world? Static page
(GitHub Pages) plus a free Supabase database for shared contributions.

    index.html   the whole app
    config.js    Supabase URL + public anon key (the only thing you edit)
    schema.sql   database tables, security rules, submit functions

## One-time setup

1. **Create a Supabase project** at supabase.com (free tier is plenty).
2. **Run `schema.sql`**: dashboard -> SQL Editor -> New query -> paste -> Run.
3. **Create the admin user**: Authentication -> Users -> Add user (email + password).
   Then Authentication -> Sign In / Providers -> turn **off** "Allow new users to sign up",
   because any signed-in user can moderate.
4. **Fill in `config.js`** with Project Settings -> API -> Project URL and the
   `anon public` key. That key is meant to be public. Never use `service_role`.
5. **Publish**: repo Settings -> Pages -> deploy from branch `main`, folder `/ (root)`.
   The app will be at `https://jjgerard.github.io/animal-language/`.

If `config.js` is left blank the page still works, but contributions only stay in the visitor's browser.

## How it works

- Visitors can read approved rows only, and can only add rows through
  `submit_language` / `submit_contribution`, which always create `pending` rows
  and stop accepting new ones if more than 100 languages or 500 items are waiting.
- Limits (name 100 chars, text 200, recording ~300 KB, valid animals) are enforced by the database.
- Admin: click the gear (or open `?admin=1`), sign in with the admin email and
  password, then use "Review pending" to approve or reject.
- The session token lives in `sessionStorage` and expires after about an hour.

## Not done yet

- Recordings are stored as base64 in the table and every approved one is
  downloaded on page load. Moving them to Supabase Storage would be better.
- Export/Import still works on the browser's local copy only.

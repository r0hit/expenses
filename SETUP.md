# Setting up Household expenses

This takes about 15 minutes, and everything here is free. You'll set up three things:

- **Supabase** stores your expenses and handles sign-in.
- **GitHub Pages** hosts the app at a web address you both open.
- **A GitHub Action** keeps your free Supabase project from pausing.

Do this on a computer. Once it's done, you and your wife only need your phones. Supabase and GitHub occasionally rename menu items, so if a label below doesn't match exactly, look for the closest equivalent.

---

## 1. Create a Supabase project

1. Go to **supabase.com** and sign up. Signing in with GitHub is easiest.
2. Click **New project**.
   - **Name:** `household-expenses`
   - **Database password:** click **Generate a password** and save it in your password manager. The app doesn't use it, but you'd need it to manage the database directly.
   - **Region:** choose the one closest to you, such as East US.
3. Click **Create new project** and wait a minute or two while it sets up.

## 2. Create the database

1. In the left sidebar, open **SQL Editor**.
2. Open `supabase/schema.sql` from this folder, copy the entire file, and paste it into the editor.
3. Click **Run**. You should see "Success. No rows returned."

This creates the tables and the security rules that make sure only members of your household can see your expenses.

## 3. Put the app on GitHub Pages

1. Sign in at **github.com** and click **New repository** (the **+** in the top right).
   - **Name:** `expenses`
   - **Visibility:** Public. Free GitHub Pages requires a public repository. Only the app's code goes here. Your expenses are stored in Supabase, never in this repository.
   - Click **Create repository**.
2. On the new repository's page, click **uploading an existing file**.
3. Drag in these files and the `supabase` folder:
   `index.html`, `app.js`, `config.js`, `manifest.webmanifest`, `icon-192.png`, `icon-512.png`, `apple-touch-icon.png`, `SETUP.md`
   Then click **Commit changes**. You'll add the `.github` folder separately in step 6, because computers often hide folders whose names start with a dot.
4. Go to **Settings > Pages**. Under **Build and deployment**, set **Source** to **Deploy from a branch**, choose the **main** branch and **/ (root)** folder, then click **Save**.
5. After about a minute, refresh the page. GitHub shows your app's address, which looks like `https://YOUR-USERNAME.github.io/expenses/`. Copy it.

## 4. Connect the app to Supabase

1. In Supabase, click **Connect** at the top of your project, or go to **Project Settings > API Keys**. You need two values:
   - **Project URL**, which looks like `https://abcdefghijkl.supabase.co`
   - **Publishable key**, which starts with `sb_publishable_`. Older projects call it the **anon public** key.
2. In GitHub, open `config.js`, click the pencil icon to edit it, and replace the two placeholder values:
   ```js
   window.EXPENSES_CONFIG = {
     supabaseUrl: "https://abcdefghijkl.supabase.co",
     supabaseKey: "sb_publishable_...",
   };
   ```
3. Click **Commit changes**. GitHub Pages updates within a minute.

It's fine for these two values to be public. They're designed to sit inside apps. Your data is protected by sign-in and the database rules from step 2, so never paste the **secret** key or the database password into this file.

## 5. Tell Supabase where the app lives

This makes the confirmation and password-reset emails link back to your app.

1. In Supabase, go to **Authentication > URL Configuration**.
2. Set **Site URL** to your app address from step 3, for example `https://YOUR-USERNAME.github.io/expenses/`.
3. Under **Redirect URLs**, click **Add URL** and add the same address. Click **Save**.

## 6. Keep the project awake (recommended)

Free Supabase projects pause after a week without activity. This step sends a tiny request every 3 days so that doesn't happen.

1. In GitHub, go to **Settings > Secrets and variables > Actions** and click **New repository secret**. Add two secrets:
   - `SUPABASE_URL`, set to your Project URL
   - `SUPABASE_KEY`, set to your publishable key
2. Go back to the **Code** tab and click **Add file > Create new file**.
3. For the file name, type `.github/workflows/keepalive.yml`. GitHub creates the folders as you type each `/`.
4. Paste in the contents of `.github/workflows/keepalive.yml` from this folder, then click **Commit changes**.
5. Open the **Actions** tab, click **Keep Supabase awake**, then click **Run workflow** to test it. A green check means it worked.

Two caveats. First, GitHub turns off scheduled workflows in public repositories after 60 days with no changes to the repository. GitHub emails you before that happens, and you can turn it back on with one click in the **Actions** tab. Second, if the project ever does pause, nothing is lost. Open your Supabase dashboard and click **Restore project**.

## 7. Start using it

**You:**
1. Open your app address and tap **Create an account**.
2. Confirm your email using the link Supabase sends you, then sign in.
3. Choose **Create household**, enter a household name and your name, and set your monthly take-home pay.

**Your wife:**
1. Open **Settings** in the app and copy the invite code. Send it to her along with the app address.
2. She creates her own account, confirms her email, and signs in.
3. She chooses **Join with code** and enters the invite code.

From then on, an expense either of you adds shows up on the other's phone within a few seconds.

## 8. Add it to your home screens

- **iPhone:** open the app address in Safari, tap the **Share** button, then tap **Add to Home Screen**.
- **Android:** open it in Chrome, tap the **⋮** menu, then tap **Add to Home screen** or **Install app**.

On iPhone, the home-screen app keeps its own sign-in separate from Safari, so you'll sign in once more after adding it.

---

## Good to know

- **Privacy.** Only signed-in members of your household can read or change your expenses. The database rules enforce this, so it can't be bypassed from the app. As the owner of the Supabase project, you can also see the data in the Supabase dashboard, so keep that account secure.
- **Emails.** Supabase's built-in email sender only allows a few emails per hour. That's plenty for two people. If a confirmation email doesn't arrive, check spam, wait a few minutes, and try again.
- **Invite codes.** Once your wife has joined, tap **Make a new code** in Settings so the old code stops working. A household can have up to 6 members.
- **Updating the app.** If I make changes for you later, you'll only need to upload a new `app.js`. Leave `config.js` as it is.
- **Editing the code yourself.** The `source` folder has the readable code. Run `npm install` and then `npm run build`, which writes a new `app.js`.

## If something isn't working

- **The app says "Almost ready."** `config.js` still has the placeholder values. Redo step 4.
- **"Couldn't connect."** Check that the Project URL in `config.js` is spelled exactly right and starts with `https://`.
- **The confirmation link opens a broken page.** Check the Site URL and Redirect URL from step 5. They must match your app address exactly, including the trailing `/`.
- **"Couldn't load your household" after signing in.** The SQL from step 2 probably didn't run fully. Open the SQL Editor, check for a red error message, and run the file again on a fresh project if needed.

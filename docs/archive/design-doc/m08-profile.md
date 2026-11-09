## M8 profile (Gilfoyle, 2026-10-04)
Architecture lock only. Not a milestone stamp. No new screen id. `817a8ff42f584875beff5a0db22229ad` is not the screen. `32d2ebd59a64467896852b9adab37064` is the menu reference only.
### Avatar
- `profiles.avatar_path text` nullable. Check: null, or exactly `id::text || '/avatar.jpg'`.
- Private bucket `avatars`. Not `story-photos`. One object, `{uid}/avatar.jpg`, JPEG.
- Storage select, insert, update, and delete: `auth.uid()` and that object only. A co-member does not get the file. **Superseded for SELECT by M9 avatar visibility (2026-10-05): co-members can read the file. Writes stay own-only.**
- Co-member SELECT of `profiles` returns `avatar_path`. No other screen paints it in this milestone.
- No picture: the client paints initials from the saved `display_name`. First letter of each whitespace-separated word, uppercased. Not a column. Not one letter. Not the email. Sarah Morgan is SM.
- A saved picture replaces the initials. The circle shows that file. Initials only when `avatar_path` is null.
- Bill, 2026-10-04: the name is required. Save does not write a blank or null `display_name`. Do not take initials from the email. A stored name that is already blank paints no letters until a name is saved. A saved picture still fills the circle. An empty circle is only when `avatar_path` is null and the stored name is blank. No `NOT NULL` in this milestone.
- Reuse the existing story-photo JPEG compressor. No new package. No new Edge function.
### Email
- The client does not update `profiles.email`.
- A changed address calls `auth.updateUser({ email })` and nothing else.
- Secure email change stays on. Confirmation goes to the current address and the new address. `auth.users.email` does not move until both are confirmed. Magic-link delivery stays on the old address until then.
- An update trigger on `auth.users` copies the new email onto `profiles.email` only after that move. Insert bootstrap stays `handle_new_user()`.
- No second screen and no second route for the confirmations. They are the two emails. Save stays one button.
- No admin API. No service role in the client.
### Screen
- Route `/settings`.
- The header control is the last control on the existing shared header. The menu is Settings, then Logout, including on Settings. Logout is the existing session sign-out.
- One Save. Name writes `profiles.display_name`. The picture writes the object and `avatar_path`. Email is the request above, not a column write.
> 🚫 FORBIDDEN: Writing `profiles.email` from the client. Putting the avatar in `story-photos`. A public avatar URL. Painting another member's picture (superseded by M9 avatar visibility, 2026-10-05: co-members may paint it). Deriving initials from the email. Painting initials over a saved picture. A confirmation screen. Matching screen `817a8ff42f584875beff5a0db22229ad`.

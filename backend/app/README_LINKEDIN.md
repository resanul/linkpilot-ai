# LinkedIn integration notes
- OAuth 2.0 member authorization is separate from Google app login.
- Use `w_member_social` for member post/comment/like actions where enabled for the app.
- Reading all member posts requires restricted `r_member_social` access; do not assume it is granted.
- Keep `state` server-side, single-use, user-bound and short-lived. The starter returns state but does not persist it; implement persistence before production.
- Encrypt access/refresh tokens with a managed KMS. Never store tokens in plaintext or in the mobile app.
- Use the current supported `Linkedin-Version` value and update it before version sunset.

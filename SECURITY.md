# Security

Report a vulnerability privately through
[GitHub private vulnerability reporting](https://github.com/SVamseekar/devernance-release-gate/security/advisories/new).
Please do not open a public issue.

## Releases

Every `vX.Y.Z` release is immutable: its tag cannot be moved or deleted. The major tag (`v1`) moves to the newest
`v1.x.y`. If your organisation requires it, pin the action to a full commit SHA (see the README).

The action sends your API key only to the `api-url` you configure, masks it in logs, and needs no token
permissions beyond `contents: read`.

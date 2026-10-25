# Security policy

## Secrets

This repository is public. Never commit secrets or credentials, including:

- API keys and access tokens
- GitHub, npm, OpenAI, Anthropic, Tailscale, Microsoft, Apple, or Google credentials
- SSH or TLS private keys
- passwords, recovery codes, cookies, session exports, or credential-manager data
- school credentials or private institutional configuration
- environment files containing credentials

Bootstrap scripts may detect that authentication is required, but authentication should remain an explicit user action unless a secure external secret provider is deliberately introduced.

## Configuration safety

Bootstrap scripts should preserve existing user configuration unless the change is explicitly requested. Destructive operations, broad upgrades, and credential changes must not be hidden inside normal installation.

If a secret is committed, revoke or rotate it immediately. Removing it from the latest commit is not sufficient because Git history may retain it.

# BUILD — iac-networking

## One-line install (fresh Ubuntu/Debian VM)

```bash
curl -fsSL https://raw.githubusercontent.com/UncleD0886475978/iac-networking/main/setup.sh | bash
```

The script installs its own prerequisites — git/curl via apt, and Terraform from the official HashiCorp apt repository (only when `.tf` files are actually present) — then clones the repo and validates. Alternative (clone-and-run): `git clone https://github.com/UncleD0886475978/iac-networking.git && cd iac-networking && ./setup.sh`.

- Repo: UncleD0886475978/iac-networking — Public (not marked private/fork in brief)
- Stack actually found: Docs/configs/reference — no code at root. Proving files: `README.md` (644 B) plus directories `configs/`, `runbooks/`, `subnetting/`. No `.tf`, compose, or playbook files at root. Docs/configs-only: **Yes, as far as root inspection shows** (subdir contents not enumerated — see note).
- What setup.sh does: Bootstraps base tools (git/curl) via apt, locates/clones the repo, inventories all files, bootstraps terraform (HashiCorp apt repo) only if `.tf` files are discovered at runtime (then init/validate per directory; on non-apt platforms it prints install guidance and exits), otherwise confirms docs/configs-only and parse-checks any JSON configs. Applies nothing. Prints a bootstrap summary (installed tools, working copy, one-line reinstall command).
- Issue it prevents: Hunting for a deploy command / applying infrastructure that this reference repo does not contain.
- Inspection note: root listing for every repo succeeded via GitHub connector. Deeper file reads were halted by a GitHub MCP HTTP 429 (rate limit) after willow-creek's subdirs/README were read; no further connector calls were made after the 429. Scripts therefore discover files at runtime where subdir contents were not individually enumerated.

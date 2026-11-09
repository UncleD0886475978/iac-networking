#!/usr/bin/env bash
# setup.sh — iac-networking (docs/configs/runbooks reference repo)
# VM BOOTSTRAP: on a fresh Ubuntu/Debian VM this script INSTALLS its own
# prerequisites (git/curl, plus Terraform if .tf files are present) first.
# Safe by design: Terraform is init + validate ONLY. Nothing is applied.
set -e
REPO="iac-networking"
echo "=== Setup: $REPO ==="

OWNER="UncleD0886475978"
RUN_ONELINE="curl -fsSL https://raw.githubusercontent.com/${OWNER}/${REPO}/main/setup.sh | bash"

echo "==> Step 1/6: Platform check + base bootstrap (git, curl)"
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "ERROR: this script needs root or sudo to install packages."
    exit 1
  fi
fi
APT=0
if [ "$(uname -s)" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then APT=1; fi
INSTALLED=""
APT_UPDATED=""
note_installed() { INSTALLED="${INSTALLED} $1"; }
apt_update_once() {
  if [ -z "${APT_UPDATED}" ]; then $SUDO apt-get update -y; APT_UPDATED=1; fi
}
apt_install() {
  apt_update_once
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "$@"
}
if [ "${APT}" -eq 1 ]; then
  BASE_PKGS=""
  command -v git >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} git"
  command -v curl >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} curl"
  [ -f /etc/ssl/certs/ca-certificates.crt ] || BASE_PKGS="${BASE_PKGS} ca-certificates"
  command -v gpg >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} gnupg"
  if [ -n "${BASE_PKGS}" ]; then
    echo "    Installing base tools:${BASE_PKGS}"
    # shellcheck disable=SC2086
    apt_install ${BASE_PKGS}
    note_installed "${BASE_PKGS}"
  else
    echo "    Base tools already present (git, curl, ca-certificates, gnupg)."
  fi
else
  echo "    Non-apt platform detected — bootstrap will only CHECK tools and print install guidance."
fi

# --- Per-tool installers ---
install_terraform() {
  if command -v terraform >/dev/null 2>&1; then echo "    terraform: already present ($(terraform version | head -n 1))"; return 0; fi
  [ "${APT}" -eq 1 ] || return 1
  echo "    Installing Terraform from the official HashiCorp apt repository..."
  curl -fsSL https://apt.releases.hashicorp.com/gpg | $SUDO gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "${VERSION_CODENAME}") main" | $SUDO tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  $SUDO apt-get update -y
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y terraform
  note_installed "terraform"
}

# --- Locate or clone ---
echo "==> Step 2/6: locate repo"
if [ -f "$0" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
  SCRIPT_DIR="$PWD"
fi
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git remote -v 2>/dev/null | grep -q "$REPO"; then
  REPO_DIR="$(git rev-parse --show-toplevel)"; echo "Using current checkout: $REPO_DIR"
elif [ -d "${SCRIPT_DIR}/.git" ] && [ "$(basename "${SCRIPT_DIR}")" = "$REPO" ]; then
  REPO_DIR="${SCRIPT_DIR}"; echo "Using script location: $REPO_DIR"
elif [ -d "$HOME/repos/$REPO/.git" ]; then
  REPO_DIR="$HOME/repos/$REPO"; echo "Updating $REPO_DIR"; git -C "$REPO_DIR" pull --ff-only || echo "WARN: git pull failed, using existing checkout"
else
  if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git is not installed. Install it: https://git-scm.com/downloads"
    exit 1
  fi
  mkdir -p "$HOME/repos"; git clone "https://github.com/$OWNER/$REPO.git" "$HOME/repos/$REPO"; REPO_DIR="$HOME/repos/$REPO"
fi
cd "$REPO_DIR"; echo "Repo dir: $REPO_DIR"

echo "==> Step 3/6: Bootstrap prerequisites"
# Docs/configs repo at root (README.md, configs/, runbooks/, subnetting/) — terraform is only required if .tf files are present.
if find . -name '*.tf' -not -path './.git/*' | grep -q .; then
  MISSING_LIST=""
  install_terraform || MISSING_LIST="${MISSING_LIST} terraform(https://developer.hashicorp.com/terraform/install)"
  if [ -n "${MISSING_LIST}" ]; then
    echo "ERROR: could not auto-install on this platform. Missing:${MISSING_LIST}"
    echo "Install the tool(s) manually, then re-run this script."
    exit 1
  fi
else
  echo "    No .tf files found — Terraform not required for this docs/configs repo."
fi


echo "==> Step 4/6: inventory what is actually here"
find . -type f -not -path './.git/*' | sort
echo "==> Step 5/6: validate Terraform if any exists, otherwise confirm docs/configs-only"
if find . -name '*.tf' -not -path './.git/*' | grep -q .; then
  for d in $(find . -name '*.tf' -not -path './.git/*' -exec dirname {} \; | sort -u); do echo "-- $d"; (cd "$d" && terraform init -backend=false && terraform validate); done
else
  echo "No .tf files found — nothing to init/validate or apply. This is a configs / runbooks / subnetting reference repo."
fi
echo "==> Step 6/6: sanity-check YAML/JSON configs if python3 is available"
if command -v python3 >/dev/null 2>&1; then python3 -c "import glob,json; [json.load(open(f)) for f in glob.glob('configs/**/*.json', recursive=True)]; print('JSON configs parse OK (if any)')"; else echo "python3 not found — skipping config parse check"; fi

cat <<EOF

=================== BOOTSTRAP SUMMARY ===================
Installed during this run:${INSTALLED:- (nothing — all tools were already present)}
Working copy: ${REPO_DIR}
Next time, set up from scratch on any fresh Ubuntu VM with one line:
  ${RUN_ONELINE}
=========================================================
EOF

echo ""
echo "=== Next commands ==="
echo "Run/use:  cat README.md; ls configs/ runbooks/ subnetting/  # follow the relevant runbook for the network change"
echo "Stop:     n/a — no services run from this repo; revert any network change using its runbook"
echo "Logs:     n/a — check the target cloud console / terraform plan output for the change you applied manually"

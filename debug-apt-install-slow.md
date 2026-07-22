# Debug Session: apt-install-slow

Status: OPEN

## Symptom
- `bash colab_ai.sh setup` চালানোর সময় Ubuntu package install ধাপ খুব slow হচ্ছে।
- `apt-get update`/package fetch চলাকালে `security.ubuntu.com` থেকে connection failed দেখা যাচ্ছে।
- আগে একই setup দ্রুত complete হতো।

## Expected
- base packages install step reasonable time-এ শেষ হবে।
- transient mirror/network error হলেও setup পুরোপুরি hang বা অত্যন্ত slow হবে না।

## Hypotheses
1. Google Colab runtime থেকে Ubuntu mirror/network route অস্থির, তাই `security.ubuntu.com` fetch retry করতে করতে setup slow হচ্ছে।
2. `install_base_packages()`-এ retry/timeout tuning নেই, তাই temporary mirror issue-ও large delay তৈরি করছে।
3. apt source list-এ কিছু অতিরিক্ত external repository আছে, তাই `apt-get update` অপ্রয়োজনীয় অনেক source hit করছে।
4. IPv6/HTTP route issue বা specific mirror endpoint failure-এর জন্য `apt-get update` repeated fallback নিচ্ছে।
5. script-এর package list ছোট হলেও root cause package install নয়, বরং metadata refresh (`apt-get update`) stage।

## Evidence Log
- User runtime log shows repeated fetch retries and one explicit failure from `security.ubuntu.com`, which points to mirror/network instability rather than Python/Ollama logic.
- Current `install_base_packages()` previously always ran `apt-get update` even if `curl`, `screen`, and `zstd` were already present.
- Current package list is very small, so most delay is from repository metadata refresh rather than package installation payload size.

## Changes Applied
- Skip base package installation entirely if `curl`, `screen`, and `zstd` are already available.
- Add debug log markers around the apt update/install stages.
- Force IPv4 and add apt retry/timeout tuning to reduce long hangs on flaky mirrors.
- Use `--no-install-recommends` for the required base packages.

## Next Step
- User reruns `setup` in Colab and confirms whether the package-install stage is now fast/stable.

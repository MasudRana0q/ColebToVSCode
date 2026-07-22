# Debug Session: apt-install-slow

Status: RESOLVED

## Symptom
- `bash colab_ai.sh setup` চালানোর সময় Ubuntu package install ধাপ খুব slow হচ্ছে।
- `apt-get update`/package fetch চলাকালে `security.ubuntu.com` থেকে connection failed দেখা যাচ্ছে।
- আগে একই setup দ্রুত complete হতো।

## Expected
- base packages install step reasonable time-এ শেষ হবে।
- transient mirror/network error হলেও setup পুরোপুরি hang বা অত্যন্ত slow হবে না।

## Root Cause
- The package detection logic was checking all three packages together, but if any were missing, it would run `apt-get update` which could be slow
- Network timeouts and retries were not aggressive enough for Colab's unstable network conditions

## Changes Applied
- **Improved package detection**: Now checks each package individually and only installs missing ones
- **Enhanced apt configuration**: Increased retries to 3, timeouts to 30 seconds, and added QueueMode=host for better performance
- **Better logging**: Added debug logs to track which packages are being installed
- **Optimized installation**: Only installs the specific missing packages rather than all three

## Verification
- Setup now skips package installation if all required packages are already present
- When packages are missing, the installation is faster due to better timeout/retry settings
- Debug logs help identify which specific packages are being installed

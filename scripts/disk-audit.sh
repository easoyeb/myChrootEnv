#!/usr/bin/env bash
# ==============================================================================
# disk-audit.sh - Storage Scanner & Audit Tool for myChrootEnv
# ==============================================================================

echo "=========================================="
echo "   myChrootEnv Storage Audit & Scan"
echo "=========================================="
echo ""

echo "==> 1. Filesystem Overview"
df -h / | awk 'NR==1 || NR==2'
echo ""

echo "==> 2. Top-Level Directories (/)"
du -hd 1 / 2>/dev/null | sort -hr | head -n 10
echo ""

echo "==> 3. Home Directory Top Consumers (~/)"
du -hd 1 /root 2>/dev/null | sort -hr | head -n 12
echo ""

echo "==> 4. Android SDK Temp Directory"
if [ -d "/opt/android-sdk-custom/android-sdk/.temp" ]; then
    du -sh /opt/android-sdk-custom/android-sdk/.temp 2>/dev/null || echo "0B"
else
    echo "Not present."
fi
echo ""

echo "==> 5. System /tmp Top Consumers"
du -hd 1 /tmp 2>/dev/null | sort -hr | head -n 8
echo ""

echo "==> 6. Gradle Caches & Distributions"
if [ -d "/root/.gradle" ]; then
    du -hd 2 /root/.gradle 2>/dev/null | sort -hr | head -n 10
else
    echo "No .gradle folder found."
fi
echo ""

echo "==> 7. Project Build Artifacts (build/ folders in ~/Projects)"
find /root/Projects -maxdepth 3 -type d -name "build" 2>/dev/null | xargs -r du -sh 2>/dev/null | sort -hr | head -n 10
echo ""

echo "==> 8. Package & AI Caches"
[ -d "/root/.npm" ] && echo "  - NPM Cache: $(du -sh /root/.npm 2>/dev/null | cut -f1)"
[ -d "/root/.local/share/pnpm" ] && echo "  - PNPM Store: $(du -sh /root/.local/share/pnpm 2>/dev/null | cut -f1)"
[ -d "/root/.cache/pip" ] && echo "  - Pip Cache: $(du -sh /root/.cache/pip 2>/dev/null | cut -f1)"
[ -d "/var/cache/apt/archives" ] && echo "  - APT Cache: $(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)"
[ -d "/root/.gemini/tmp" ] && echo "  - Gemini Workspaces: $(du -sh /root/.gemini/tmp 2>/dev/null | cut -f1)"
echo ""

echo "=========================================="
echo "   Audit Complete."
echo "   For cleanup commands, see: docs/Storage and Cleanup Guide.md"
echo "=========================================="
